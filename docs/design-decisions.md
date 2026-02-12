\# Design Decisions and Tradeoffs



\## Overview



This document explains the key architectural decisions made in the VMware to GCP hybrid connectivity design, including the rationale, alternatives considered, and tradeoffs accepted.



\## Decision 1: Layer 3 Routed Architecture vs Layer 2 Extension



\### Decision

\*\*Selected\*\*: Layer 3 routed architecture using BGP dynamic routing



\### Rationale

\- Aligns with GCP native capabilities and best practices

\- Provides superior scalability (supports thousands of routes)

\- Simplifies operations with standard IP routing tools

\- Enables traffic engineering through BGP attributes

\- Reduces failure domain scope with routing isolation



\### Alternatives Considered



\*\*Layer 2 Extension (VXLAN/OTV)\*\*:

\- Pros: Seamless VM migration without IP changes, supports legacy apps with IP dependencies

\- Cons: Broadcast storm risk, complex troubleshooting, no native GCP support, limited scalability

\- Rejected due to operational complexity and long-term technical debt



\### Tradeoffs Accepted

\- Applications require IP address changes during migration

\- Live migration (VMotion) not supported across hybrid boundary

\- DNS updates and load balancer reconfiguration required

\- More complex migration planning and sequencing



\### Mitigation Strategies

\- Invest in DNS automation for rapid updates

\- Use blue/green deployment patterns where possible

\- Document application dependencies thoroughly

\- Implement comprehensive testing procedures



---



\## Decision 2: HA VPN for Initial Deployment



\### Decision

\*\*Selected\*\*: HA VPN with 4-tunnel configuration, migration path to Dedicated Interconnect



\### Rationale

\- Rapid deployment timeline (1-2 weeks vs 4-12 weeks for Interconnect)

\- Lower barrier to entry for proof of concept

\- Built-in encryption meets security requirements

\- Cost-effective for initial bandwidth needs (< 2 Gbps)

\- Provides migration experience before Interconnect investment



\### Alternatives Considered



\*\*Immediate Dedicated Interconnect\*\*:

\- Pros: Better long-term economics, lower latency, higher throughput

\- Cons: Longer procurement and deployment cycle, higher upfront planning requirements

\- Deferred until bandwidth requirements validated in production



\*\*Classic VPN (Single Gateway)\*\*:

\- Pros: Simpler initial configuration

\- Cons: Only 99.9% SLA vs 99.99%, not production-ready

\- Rejected due to inadequate availability guarantees



\### Tradeoffs Accepted

\- Higher per-GB egress costs during initial phase

\- 3 Gbps per-tunnel throughput ceiling

\- Internet-dependent connectivity path

\- VPN encryption overhead (~5-10ms latency)



\### Migration Path

\- Monitor bandwidth utilization and egress costs monthly

\- Trigger Interconnect procurement at 500 Mbps sustained threshold

\- Maintain VPN as backup path after Interconnect deployment



---



\## Decision 3: Active-Active Tunnel Configuration



\### Decision

\*\*Selected\*\*: Four VPN tunnels in active-active configuration with equal BGP metrics



\### Rationale

\- Maximizes available bandwidth (up to 6 Gbps aggregate)

\- Provides automatic failover without manual intervention

\- Distributes traffic load across multiple tunnels

\- Maintains connectivity during single tunnel failure

\- Achieves 99.99% SLA requirements



\### Alternatives Considered



\*\*Active-Passive Configuration\*\*:

\- Pros: Guaranteed routing symmetry, simpler troubleshooting

\- Cons: Wastes 50% of available bandwidth, slower failover

\- Rejected due to bandwidth efficiency concerns



\*\*Two Tunnels Only\*\*:

\- Pros: Simpler configuration, lower cost ($73/month savings)

\- Cons: No interface-level redundancy, lower aggregate bandwidth

\- Rejected due to availability requirements



\### Tradeoffs Accepted

\- Potential for asymmetric routing with stateful firewalls

\- More complex BGP configuration and monitoring

\- Need for careful route priority management



\### Mitigation Strategies

\- Document routing behavior thoroughly

\- Implement policy-based routing if asymmetry issues arise

\- Monitor BGP session status and route advertisements

\- Test failover scenarios regularly



---



\## Decision 4: Non-Overlapping IP Address Space



\### Decision

\*\*Selected\*\*: Strict non-overlapping RFC 1918 addressing with IPAM governance



\### Rationale

\- Enables native IP routing without NAT complexity

\- Simplifies troubleshooting and log correlation

\- Avoids application compatibility issues with NAT

\- Supports future network expansion and peering

\- Best practice for enterprise hybrid deployments



\### Alternatives Considered



\*\*NAT at Hybrid Boundary\*\*:

\- Pros: Allows overlapping address space, addresses shadow IT networks

\- Cons: Breaks applications embedding IPs, complex troubleshooting, performance overhead

\- Rejected except as emergency remediation for discovered overlaps



\### Tradeoffs Accepted

\- Requires comprehensive network discovery upfront

\- May necessitate on-premises renumbering projects

\- Demands strong IPAM discipline and governance

\- Limits flexibility for undocumented networks



\### Implementation Approach

\- Conduct automated network discovery using multiple tools

\- Reserve GCP address blocks in corporate IPAM system

\- Implement approval workflow for all new allocations

\- Quarterly IPAM audits to identify drift



---



\## Decision 5: BGP ASN Selection



\### Decision

\*\*Selected\*\*: Private ASNs (65001 for cloud, 65002 for on-premises)



\### Rationale

\- No public ASN required for private connectivity

\- Avoids registration and administrative overhead

\- Standard practice for enterprise hybrid deployments

\- Provides clear organizational separation



\### Alternatives Considered



\*\*Public ASNs\*\*:

\- Pros: Required if multi-provider BGP needed

\- Cons: Registration complexity, unnecessary for private peering

\- Not needed for this use case



\*\*4-Byte ASNs\*\*:

\- Pros: Larger address space

\- Cons: Unnecessary complexity for simple two-site deployment

\- Deferred until multi-site expansion



\### Tradeoffs Accepted

\- Limited to private peering scenarios

\- Cannot participate in public BGP routing

\- Must change ASNs if requirements evolve to multi-provider



---



\## Decision 6: Firewall Placement Strategy



\### Decision

\*\*Selected\*\*: Firewalls at both on-premises edge and GCP VPC boundaries



\### Rationale

\- Defense-in-depth security architecture

\- Independent security policy enforcement at each site

\- Maintains existing on-premises security controls

\- Leverages GCP native VPC firewall capabilities



\### Alternatives Considered



\*\*Centralized On-Premises Firewall Only\*\*:

\- Pros: Single policy management point

\- Cons: Asymmetric routing risk, GCP traffic hairpinning

\- Rejected due to architectural complexity



\*\*GCP-Only Firewalling\*\*:

\- Pros: Simplified management, cloud-native approach

\- Cons: Requires migration of all security policies, organizational resistance

\- Deferred until cloud-first maturity increases



\### Tradeoffs Accepted

\- Dual firewall policy management overhead

\- Potential for policy conflicts or gaps

\- More complex troubleshooting during incidents



\### Governance Approach

\- Maintain policy consistency documentation

\- Regular policy audits across both environments

\- Automated policy compliance checking where possible



---



\## Decision 7: MTU Configuration



\### Decision

\*\*Selected\*\*: 1460 byte MTU on VPN tunnels with TCP MSS clamping



\### Rationale

\- Prevents fragmentation within IPsec/GRE overhead

\- Ensures reliable Path MTU Discovery operation

\- Avoids mysterious application failures

\- Standard best practice for VPN deployments



\### Alternatives Considered



\*\*Maintain 1500 Byte MTU\*\*:

\- Pros: Matches on-premises standards

\- Cons: Causes fragmentation and packet loss in tunnels

\- Rejected due to application reliability concerns



\*\*Jumbo Frames (9000 Bytes)\*\*:

\- Pros: Optimal for storage traffic

\- Cons: Not supported over VPN tunnels

\- Reserved for future Dedicated Interconnect with separate paths



\### Tradeoffs Accepted

\- Reduced effective throughput vs theoretical maximum

\- Need for MSS clamping configuration on edge devices

\- Documentation and training requirements



\### Implementation Details

\- Configure MSS clamping: TCP MSS = MTU - 40 (IP) - 20 (TCP) = 1400

\- Allow ICMP Type 3 Code 4 in firewall rules

\- Document MTU in application deployment guides



---



\## Decision 8: Monitoring and Observability



\### Decision

\*\*Selected\*\*: Multi-layered monitoring with VPN metrics, BGP status, and application performance



\### Rationale

\- Early detection of connectivity issues

\- Visibility into BGP routing behavior

\- Application-level performance validation

\- Capacity planning data collection



\### Tools and Metrics



\*\*GCP Native Monitoring\*\*:

\- VPN tunnel status and throughput

\- BGP session state

\- Route advertisement counts

\- Packet loss and latency metrics



\*\*On-Premises Monitoring\*\*:

\- VPN device health and utilization

\- BGP neighbor status

\- Interface statistics

\- Firewall connection counts



\*\*Application Monitoring\*\*:

\- End-to-end latency measurements

\- Transaction success rates

\- Bandwidth utilization patterns



\### Tradeoffs Accepted

\- Additional monitoring infrastructure costs

\- Alert fatigue if thresholds not tuned properly

\- Learning curve for cloud-native monitoring tools



---



\## Summary of Key Principles



1\. \*\*Start Simple, Scale Gradually\*\*: Begin with HA VPN, evolve to Interconnect based on actual needs

2\. \*\*Prioritize Reliability\*\*: Accept cost premiums for redundancy and high availability

3\. \*\*Plan for Growth\*\*: Design with 50-100% headroom for bandwidth expansion

4\. \*\*Maintain Security\*\*: Defense-in-depth with firewalls at multiple layers

5\. \*\*Automate Operations\*\*: Invest in monitoring, alerting, and automation from day one

6\. \*\*Document Everything\*\*: Comprehensive documentation enables troubleshooting and knowledge transfer

7\. \*\*Test Thoroughly\*\*: Validate failover scenarios before production cutover

8\. \*\*Embrace Standards\*\*: Use proven best practices rather than custom solutions



---



\*\*Document Version\*\*: 1.0  

\*\*Last Updated\*\*: February 2026  

\*\*Author\*\*: Gregory B. Horne  

\*\*Review Cycle\*\*: Quarterly

