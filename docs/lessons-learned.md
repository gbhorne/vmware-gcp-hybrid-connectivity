\# Real-World Lessons Learned



\## Overview



This document captures sanitized real-world insights from enterprise VMware to GCP hybrid connectivity deployments. These lessons represent common pitfalls and architectural guidance developed through production implementations.



---



\## Lesson 1: MTU Mismatches Causing Packet Drops



\### The Problem



Production VMware environment used jumbo frames (9000 byte MTU) on storage networks for optimal iSCSI and NFS performance. After establishing VPN connectivity to GCP, storage replication experienced intermittent failures with severe performance degradation (60-70% throughput reduction).



Initial troubleshooting focused on bandwidth capacity and firewall rules, delaying root cause identification by several days. Engineering team spent significant effort investigating application-layer issues before discovering network-layer problem.



\### Root Cause



VPN tunnel MTU limitation of 1460 bytes caused fragmentation of 9000 byte storage frames. Path MTU Discovery (PMTUD) was blocked by corporate firewall ICMP filtering policies, resulting in silent packet drops. Applications expecting 9000 byte MTU experienced timeouts and TCP retransmissions.



Storage replication protocol interpreted packet loss as network instability, triggering exponential backoff algorithms that further reduced throughput.



\### Resolution Steps



1\. \*\*Immediate Fix\*\*: Configured TCP MSS clamping on VPN gateway to limit maximum segment size to 1420 bytes

2\. \*\*Firewall Update\*\*: Modified firewall rules to allow ICMP Type 3 Code 4 (Fragmentation Needed) for PMTUD

3\. \*\*Application Tuning\*\*: Adjusted storage replication buffer sizes to align with 1460 byte MTU

4\. \*\*Documentation\*\*: Added MTU verification to pre-migration testing checklist

5\. \*\*Monitoring\*\*: Implemented alerts for PMTUD failures and fragmentation events



\### Prevention Strategies



\- \*\*Discovery Phase\*\*: Identify all networks using jumbo frames during initial assessment

\- \*\*Design Phase\*\*: Document MTU through entire path (on-prem → VPN → GCP)

\- \*\*Testing Phase\*\*: Include MTU-specific tests using ping with "do not fragment" flag

\- \*\*Migration Runbooks\*\*: Explicit MTU configuration steps for each application

\- \*\*Validation\*\*: Post-migration verification that no fragmentation occurring



\### Command Reference

```bash

\# Test MTU with do-not-fragment flag

ping -M do -s 1432 <destination\_ip>  # 1432 + 8 (ICMP) + 20 (IP) = 1460



\# Verify no fragmentation in packet captures

tcpdump -i any -n 'ip\[6:2] \& 0x4000 != 0'  # Show DF (Don't Fragment) packets

```



\### Impact



\- \*\*Downtime\*\*: 3 days of degraded replication performance

\- \*\*Engineering Hours\*\*: 40+ hours troubleshooting before root cause identified

\- \*\*Business Impact\*\*: Delayed migration timeline by 1 week

\- \*\*Lesson Value\*\*: Saved future deployments from repeating same mistake



---



\## Lesson 2: VLAN Trunk Tagging Failures



\### The Problem



Hybrid connectivity established successfully with all VPN tunnels showing "Established" status and BGP sessions "Up". However, only management VLAN traffic (VLAN 10) successfully reached GCP. Production application VLANs (VLAN 100-199) failed to traverse the hybrid link despite correct BGP route advertisements and firewall rules.



Network captures showed traffic arriving at on-premises VPN device but not appearing in GCP VPC flow logs.



\### Root Cause



On-premises edge router interface was configured as access port instead of trunk port. VLAN tags were stripped before reaching VPN tunnel, causing GCP to receive all traffic as untagged default VLAN. BGP correctly advertised routes (control plane working), but data plane traffic failed due to Layer 2 misconfiguration.



The configuration error occurred during router maintenance 6 months prior when interface was temporarily converted to access mode for testing and never reverted to trunk mode.



\### Resolution Steps



1\. \*\*Interface Reconfiguration\*\*: Changed router interface from access to trunk mode

2\. \*\*VLAN Allowlist\*\*: Configured explicit VLAN allowlist (10, 100-199) on trunk

3\. \*\*Verification\*\*: Tested connectivity for each production VLAN individually

4\. \*\*Configuration Backup\*\*: Saved validated configuration to prevent future regression

5\. \*\*Automation\*\*: Implemented Ansible playbook to verify trunk configuration



\### Configuration Example

```

! Cisco IOS Configuration

interface GigabitEthernet0/0

&nbsp;description VPN-to-GCP

&nbsp;switchport mode trunk

&nbsp;switchport trunk allowed vlan 10,100-199

&nbsp;switchport trunk native vlan 999

&nbsp;no shutdown

```



\### Prevention Strategies



\- \*\*Configuration Management\*\*: Use infrastructure-as-code for router configurations

\- \*\*Automated Validation\*\*: Post-change verification scripts checking trunk status

\- \*\*Testing Procedures\*\*: Per-VLAN connectivity tests in deployment checklist

\- \*\*Change Control\*\*: Require peer review for interface mode changes

\- \*\*Documentation\*\*: Network diagrams showing trunk requirements clearly



\### Impact



\- \*\*Downtime\*\*: 6 hours troubleshooting across multiple teams

\- \*\*Engineering Hours\*\*: 24 hours total (network, cloud, application teams)

\- \*\*Business Impact\*\*: Delayed production cutover by 1 day

\- \*\*Lesson Value\*\*: Added trunk verification to standard deployment procedures



---



\## Lesson 3: Asymmetric Firewall Routing Issues



\### The Problem



Traffic from GCP to on-premises worked correctly, but return traffic failed intermittently (approximately 30% packet loss). Stateful firewall logs showed dropped sessions with "no connection state" errors. Issue occurred only for certain workloads and varied by time of day.



Application teams reported unpredictable connection timeouts and failures that defied consistent reproduction.



\### Root Cause



Active-active VPN tunnel configuration with unequal BGP metrics caused traffic to prefer Tunnel 1 outbound but return via Tunnel 2. Organization had two data centers with firewalls in different geographic locations:



\- \*\*Outbound Path\*\*: GCP → Tunnel 1 → Datacenter A Firewall → On-Premises Server

\- \*\*Return Path\*\*: On-Premises Server → Datacenter B Firewall → Tunnel 2 → GCP



Firewall A established connection state for outbound traffic, but return traffic arrived at Firewall B where no session state existed. Stateful inspection dropped return packets as "invalid connection".



Time-of-day variation occurred because BGP path selection occasionally changed based on link utilization, causing intermittent symmetry.



\### Resolution Steps



1\. \*\*Immediate Fix\*\*: Implemented policy-based routing to force symmetric paths

2\. \*\*BGP Tuning\*\*: Configured BGP local preference to strongly prefer primary tunnel (150 vs 100)

3\. \*\*Firewall Sync\*\*: Attempted session state synchronization (limited success across sites)

4\. \*\*Traffic Engineering\*\*: Separated application traffic by tunnel using source-based routing

5\. \*\*Monitoring\*\*: Added asymmetric routing detection to network monitoring



\### Policy-Based Routing Example

```

! Route traffic entering Tunnel 1 back through Tunnel 1

route-map FORCE-TUNNEL-1 permit 10

&nbsp;match ip address TUNNEL-1-TRAFFIC

&nbsp;set ip next-hop 169.254.1.1



ip access-list extended TUNNEL-1-TRAFFIC

&nbsp;permit ip 10.2.0.0 0.0.0.255 10.1.0.0 0.0.0.255

```



\### Prevention Strategies



\- \*\*Design Phase\*\*: Plan for routing symmetry in multi-site deployments

\- \*\*BGP Configuration\*\*: Use consistent metrics and clear primary/backup designation

\- \*\*Firewall Placement\*\*: Position firewalls symmetrically relative to VPN tunnels

\- \*\*Testing\*\*: Include asymmetric routing tests in failover scenarios

\- \*\*Documentation\*\*: Network flow diagrams showing expected paths for each traffic type



\### Impact



\- \*\*Downtime\*\*: 2 days of intermittent connectivity affecting 30% of transactions

\- \*\*Engineering Hours\*\*: 60+ hours across multiple troubleshooting sessions

\- \*\*Business Impact\*\*: Customer complaints about application reliability

\- \*\*Lesson Value\*\*: Architectural pattern now standard in all hybrid designs



---



\## Lesson 4: BGP Route Flapping During Maintenance



\### The Problem



Planned on-premises router maintenance caused complete GCP connectivity loss despite redundant VPN tunnel design. BGP sessions flapped repeatedly during 30-minute maintenance window, impacting production applications. Connectivity restored only after maintenance completion, not during failover to secondary router as designed.



\### Root Cause



BGP graceful restart was not configured on Cloud Router. When on-premises primary router went offline for maintenance, BGP sessions terminated immediately. Cloud Router withdrew all learned routes before secondary tunnels could converge (60-90 seconds).



Application servers lost connectivity during BGP convergence period. Health checks failed, triggering automated failover procedures that compounded the problem.



\### Resolution Steps



1\. \*\*BGP Graceful Restart\*\*: Configured 120-second restart time on Cloud Router

2\. \*\*Route Dampening\*\*: Implemented BGP dampening to prevent rapid flapping

3\. \*\*Keepalive Tuning\*\*: Adjusted timers to 20-second keepalive, 60-second hold timer

4\. \*\*Pre-Announcement\*\*: Required advance notification for BGP-affecting maintenance

5\. \*\*Change Control\*\*: Updated procedures to test BGP behavior before production changes



\### BGP Configuration

```bash

\# Configure BGP graceful restart on Cloud Router

gcloud compute routers update cloud-router \\

&nbsp; --region=us-central1 \\

&nbsp; --bgp-graceful-restart \\

&nbsp; --bgp-graceful-restart-time=120



\# Adjust keepalive and hold timers

gcloud compute routers update-bgp-peer cloud-router \\

&nbsp; --peer-name=bgp-peer-tunnel-1 \\

&nbsp; --region=us-central1 \\

&nbsp; --keepalive-interval=20 \\

&nbsp; --hold-time=60

```



\### Prevention Strategies



\- \*\*Always Enable Graceful Restart\*\*: Standard configuration for production BGP

\- \*\*Test Failover Scenarios\*\*: Validate BGP behavior during planned maintenance

\- \*\*Maintenance Windows\*\*: Schedule during low-traffic periods with extended durations

\- \*\*Monitoring Alerts\*\*: BGP flap detection with immediate escalation

\- \*\*Runbook Updates\*\*: Document expected failover timings and validation steps



\### Impact



\- \*\*Downtime\*\*: 90 seconds total across 30-minute maintenance window

\- \*\*Engineering Hours\*\*: 8 hours post-incident analysis and remediation

\- \*\*Business Impact\*\*: Brief service disruption during business hours

\- \*\*Lesson Value\*\*: BGP graceful restart now mandatory configuration item



---



\## Lesson 5: IP Address Overlap Discovered Mid-Migration



\### The Problem



Three months into cloud migration program, critical IP overlap discovered between GCP subnet 10.50.0.0/16 and on-premises shadow IT network using same range. Overlap prevented connectivity to mission-critical financial reporting applications not documented in corporate IPAM system.



Discovery occurred only when migration team attempted to connect finance applications to cloud data warehouse, triggering routing conflicts and application failures.



\### Root Cause



Shadow IT department deployed financial applications using IP space not registered in corporate IPAM. Incomplete network discovery during migration planning phase failed to identify undocumented networks. GCP VPC provisioned from supposedly available address space actually in use by production workloads.



Shadow IT network existed for 2+ years, hosted on standalone infrastructure outside standard change control.



\### Resolution Steps



1\. \*\*Emergency Assessment\*\*: Comprehensive scan of entire corporate network using multiple discovery tools

2\. \*\*GCP Renumbering\*\*: Migrated GCP VPC from 10.50.0.0/16 to 10.200.0.0/16 after confirming availability

3\. \*\*Application Updates\*\*: Updated all migrated application configurations with new IP addressing

4\. \*\*IPAM Registration\*\*: Documented shadow IT network in corporate IPAM system

5\. \*\*Governance Enforcement\*\*: Implemented mandatory IPAM registration for all networks

6\. \*\*Prevention Controls\*\*: Reserved all GCP address blocks in IPAM to prevent future on-premises usage



\### Discovery Tools Used

```bash

\# Network discovery using nmap

nmap -sn 10.0.0.0/8 --exclude 10.1.0.0/24 -oA network-discovery



\# Additional verification with ping sweeps

for i in {1..254}; do ping -c 1 -W 1 10.50.0.$i | grep "64 bytes" \& done



\# ARP table inspection

arp -a | grep "10.50"

```



\### Prevention Strategies



\- \*\*Comprehensive Discovery\*\*: Use multiple automated tools (nmap, SolarWinds, Infoblox)

\- \*\*Business Unit Sign-off\*\*: Require confirmation from all departments, not just IT

\- \*\*IPAM Governance\*\*: Mandatory registration with approval workflow

\- \*\*Penalty for Shadow IT\*\*: Escalation path for undocumented infrastructure

\- \*\*Quarterly Audits\*\*: Proactive discovery scans to identify unauthorized networks

\- \*\*Early Reservation\*\*: Reserve cloud address space immediately after architecture approval



\### Impact



\- \*\*Downtime\*\*: 2 weeks delayed migration for affected applications

\- \*\*Engineering Hours\*\*: 200+ hours for discovery, remediation, and renumbering

\- \*\*Business Impact\*\*: Finance reporting delayed, executive visibility affected

\- \*\*Cost Impact\*\*: $50K+ emergency consulting for rapid remediation

\- \*\*Lesson Value\*\*: IPAM governance now enforced across entire organization



---



\## Common Themes and Patterns



\### Theme 1: Testing is Never Comprehensive Enough



\*\*Pattern\*\*: Issues discovered in production that testing should have caught

\*\*Solution\*\*: Expand test scenarios beyond happy path to include edge cases and failure modes



\### Theme 2: Documentation Prevents Repeated Mistakes



\*\*Pattern\*\*: Same issues occurring across multiple teams or deployments

\*\*Solution\*\*: Maintain centralized lessons learned repository with search capability



\### Theme 3: Automation Reduces Human Error



\*\*Pattern\*\*: Manual configuration errors during repetitive tasks

\*\*Solution\*\*: Infrastructure-as-code for all network configurations



\### Theme 4: Monitoring Enables Faster Resolution



\*\*Pattern\*\*: Extended troubleshooting due to lack of visibility

\*\*Solution\*\*: Comprehensive monitoring from day one, not after problems occur



\### Theme 5: Change Control Coordination is Critical



\*\*Pattern\*\*: Multi-team changes causing unexpected interactions

\*\*Solution\*\*: Single change coordinator role with cross-team communication authority



---



\## Recommendations for Future Deployments



1\. \*\*Invest in Discovery\*\*: Spend 2-3 weeks on thorough network discovery before design

2\. \*\*Build Test Lab\*\*: Replicate production configuration for pre-deployment validation

3\. \*\*Enable All Monitoring\*\*: Don't wait for problems to add observability

4\. \*\*Document Everything\*\*: Architecture, configurations, decisions, and runbooks

5\. \*\*Test Failure Scenarios\*\*: Validate failover behavior before production

6\. \*\*Maintain Runbooks\*\*: Step-by-step procedures for common tasks and incidents

7\. \*\*Conduct Rehearsals\*\*: Practice deployments and rollbacks before production windows

8\. \*\*Plan for Rollback\*\*: Always have documented rollback procedures ready

9\. \*\*Learn from Others\*\*: Review lessons learned from similar deployments

10\. \*\*Share Knowledge\*\*: Document your own lessons for future teams



---



\*\*Document Version\*\*: 1.0  

\*\*Last Updated\*\*: February 2026  

\*\*Author\*\*: Gregory B. Horne  

\*\*Based On\*\*: Sanitized production deployment experiences

