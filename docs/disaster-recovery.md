\# Disaster Recovery and Multi-Region Strategies



\## Overview



This document outlines disaster recovery architecture, multi-region deployment strategies, and business continuity planning for VMware to GCP hybrid connectivity deployments.



---



\## 1. Recovery Objectives



\### Definitions



\*\*Recovery Time Objective (RTO)\*\*: Maximum acceptable time to restore service after a disruption

\*\*Recovery Point Objective (RPO)\*\*: Maximum acceptable data loss measured in time



\### Target Objectives by Tier



| Service Tier | RTO | RPO | Availability Target |

|--------------|-----|-----|-------------------|

| Tier 1 (Critical) | < 1 hour | < 15 minutes | 99.99% |

| Tier 2 (Important) | < 4 hours | < 1 hour | 99.9% |

| Tier 3 (Standard) | < 24 hours | < 4 hours | 99.5% |

| Tier 4 (Low Priority) | < 72 hours | < 24 hours | 99.0% |



\### Application Classification



\*\*Tier 1 Examples\*\*:

\- Customer-facing e-commerce platforms

\- Financial transaction systems

\- Real-time inventory management

\- Critical authentication services



\*\*Tier 2 Examples\*\*:

\- Internal business applications

\- Reporting and analytics platforms

\- Customer support systems

\- Email and collaboration tools



---



\## 2. Multi-Region HA VPN Architecture



\### Design Pattern: Active-Active Multi-Region

```

On-Premises Datacenter

&nbsp;        │

&nbsp;   ┌────┴────┐

&nbsp;   │         │

VPN Device A  VPN Device B

&nbsp;   │         │

&nbsp;   ├─────────┼──────── 4 Tunnels ────────┐

&nbsp;   │         │                            │

&nbsp;   │         └──────── 4 Tunnels ──────┐  │

&nbsp;   │                                   │  │

┌───▼────────────────┐        ┌────────▼──▼────────┐

│  us-central1       │        │   us-east1         │

│  (Primary Region)  │        │   (DR Region)      │

│                    │        │                    │

│  HA VPN Gateway    │        │   HA VPN Gateway   │

│  Cloud Router      │        │   Cloud Router     │

│  ASN: 65001        │        │   ASN: 65003       │

│                    │        │                    │

│  Production VPC    │◄──────►│   DR VPC           │

│  10.100.0.0/16     │ Peering │   10.200.0.0/16   │

│                    │        │                    │

│  Application Tier  │        │   Standby Tier     │

│  Database Primary  │◄──Rep──│   Database Replica │

└────────────────────┘        └────────────────────┘

```



\### Implementation Steps

```bash

\# Create DR region VPC

gcloud compute networks create dr-vpc \\

&nbsp; --subnet-mode=custom \\

&nbsp; --bgp-routing-mode=regional



\# Create DR subnet

gcloud compute networks subnets create dr-subnet \\

&nbsp; --network=dr-vpc \\

&nbsp; --region=us-east1 \\

&nbsp; --range=10.200.0.0/16



\# Create DR Cloud Router

gcloud compute routers create dr-router \\

&nbsp; --network=dr-vpc \\

&nbsp; --region=us-east1 \\

&nbsp; --asn=65003



\# Create DR VPN Gateway

gcloud compute vpn-gateways create dr-vpn-gw \\

&nbsp; --network=dr-vpc \\

&nbsp; --region=us-east1



\# Create VPN tunnels (repeat for all 4 tunnels)

gcloud compute vpn-tunnels create dr-tunnel-1 \\

&nbsp; --vpn-gateway=dr-vpn-gw \\

&nbsp; --peer-external-gateway=onprem-external-gw \\

&nbsp; --peer-external-gateway-interface=0 \\

&nbsp; --router=dr-router \\

&nbsp; --ike-version=2 \\

&nbsp; --shared-secret="$DR\_SHARED\_SECRET" \\

&nbsp; --interface=0 \\

&nbsp; --region=us-east1



\# Configure BGP with lower priority for DR region

gcloud compute routers add-interface dr-router \\

&nbsp; --interface-name=if-dr-tunnel-1 \\

&nbsp; --vpn-tunnel=dr-tunnel-1 \\

&nbsp; --ip-address=169.254.10.1 \\

&nbsp; --mask-length=30 \\

&nbsp; --region=us-east1



gcloud compute routers add-bgp-peer dr-router \\

&nbsp; --peer-name=bgp-peer-dr-tunnel-1 \\

&nbsp; --interface=if-dr-tunnel-1 \\

&nbsp; --peer-ip-address=169.254.10.2 \\

&nbsp; --peer-asn=65002 \\

&nbsp; --advertised-route-priority=200 \\

&nbsp; --region=us-east1

```



\### BGP Route Priority Configuration



\*\*Primary Region (us-central1)\*\*:

\- Advertised Route Priority: 100 (default)

\- Local Preference: 150 (on on-premises side)



\*\*DR Region (us-east1)\*\*:

\- Advertised Route Priority: 200 (lower priority)

\- Local Preference: 100 (on on-premises side)



This configuration ensures traffic prefers primary region during normal operations and automatically fails over to DR region during outages.



---



\## 3. Failover Scenarios and Procedures



\### Scenario 1: Primary VPN Tunnel Failure



\*\*Detection\*\*:

\- VPN tunnel status changes to "DOWN"

\- BGP session transitions to "IDLE"

\- Automated monitoring alerts



\*\*Automatic Response\*\*:

\- BGP withdraws routes via failed tunnel

\- Traffic automatically shifts to remaining 3 tunnels

\- No manual intervention required



\*\*Recovery Time\*\*: 30-60 seconds (BGP convergence)



\*\*Validation\*\*:

```bash

\# Verify tunnel status

gcloud compute vpn-tunnels list --filter="region:us-central1"



\# Check BGP sessions

gcloud compute routers get-status cloud-router --region=us-central1



\# Test connectivity

ping -c 4 <onprem-test-server>

```



\### Scenario 2: Primary Region Failure



\*\*Detection\*\*:

\- All VPN tunnels in primary region DOWN

\- Regional GCP service disruption

\- Application health checks failing



\*\*Automatic Response\*\*:

\- BGP withdraws all routes from primary region

\- On-premises router selects DR region routes (lower local preference)

\- Traffic automatically shifts to us-east1



\*\*Manual Response Required\*\*:

1\. Verify DR region connectivity

2\. Promote DR database replicas to primary

3\. Update DNS to point to DR region

4\. Validate application functionality



\*\*Recovery Time\*\*: 

\- Network failover: 60-90 seconds (automatic)

\- Application failover: 5-15 minutes (manual procedures)



\*\*Failover Runbook\*\*:

```bash

\#!/bin/bash

\# DR Failover Procedure



\# 1. Verify DR region connectivity

echo "Testing DR region connectivity..."

gcloud compute vpn-tunnels list --filter="region:us-east1"



\# 2. Promote database replicas

echo "Promoting database replicas..."

gcloud sql instances promote-replica dr-database-replica



\# 3. Update Cloud DNS

echo "Updating DNS records..."

gcloud dns record-sets transaction start --zone=production-zone

gcloud dns record-sets transaction remove \\

&nbsp; --name=app.example.com. \\

&nbsp; --type=A \\

&nbsp; --ttl=300 \\

&nbsp; --zone=production-zone \\

&nbsp; "35.1.1.1"

gcloud dns record-sets transaction add \\

&nbsp; --name=app.example.com. \\

&nbsp; --type=A \\

&nbsp; --ttl=60 \\

&nbsp; --zone=production-zone \\

&nbsp; "34.2.2.2"

gcloud dns record-sets transaction execute --zone=production-zone



\# 4. Start DR region workloads

echo "Starting DR workloads..."

gcloud compute instances start dr-app-server-1 --zone=us-east1-b

gcloud compute instances start dr-app-server-2 --zone=us-east1-c



\# 5. Validate application

echo "Validating application health..."

curl -f https://app.example.com/health || echo "ERROR: Health check failed"



\# 6. Notify stakeholders

echo "DR failover complete. Notify operations team."

```



\### Scenario 3: Complete On-Premises Datacenter Failure



\*\*Detection\*\*:

\- All VPN tunnels DOWN from both regions

\- On-premises monitoring unreachable

\- Emergency notification from facilities



\*\*Response\*\*:

\- GCP-hosted applications continue running (if cloud-native)

\- Applications dependent on on-premises resources fail

\- Activate business continuity procedures



\*\*Mitigation Strategy\*\*:

\- Replicate critical on-premises data to GCP

\- Deploy backup authentication services in GCP

\- Establish cloud-only operational mode for critical apps



---



\## 4. Data Replication Strategies



\### Database Replication



\*\*MySQL/PostgreSQL\*\*:

```bash

\# Create read replica in DR region

gcloud sql instances create dr-database-replica \\

&nbsp; --master-instance-name=primary-database \\

&nbsp; --region=us-east1 \\

&nbsp; --replica-type=READ



\# Verify replication lag

gcloud sql operations list \\

&nbsp; --instance=dr-database-replica \\

&nbsp; --filter="operationType=UPDATE"



\# Promote to standalone (during failover)

gcloud sql instances promote-replica dr-database-replica

```



\*\*Replication Lag Monitoring\*\*:

```sql

-- Check replication status

SELECT 

&nbsp; TIMESTAMPDIFF(SECOND, ts, NOW()) AS replication\_lag\_seconds

FROM mysql.heartbeat

ORDER BY ts DESC

LIMIT 1;

```



\### File Storage Replication



\*\*Cloud Storage Replication\*\*:

```bash

\# Enable dual-region bucket

gsutil mb -c STANDARD -l us gs://production-data-dual-region



\# Set up cross-region replication

gsutil rsync -r -d gs://primary-bucket gs://dr-bucket



\# Automated sync with cron

0 \* \* \* \* gsutil -m rsync -r -d gs://primary-bucket gs://dr-bucket

```



\*\*Persistent Disk Snapshots\*\*:

```bash

\# Create snapshot schedule

gcloud compute resource-policies create snapshot-schedule daily-snapshots \\

&nbsp; --region=us-central1 \\

&nbsp; --max-retention-days=7 \\

&nbsp; --on-source-disk-delete=keep-auto-snapshots \\

&nbsp; --daily-schedule \\

&nbsp; --start-time=02:00



\# Attach to disk

gcloud compute disks add-resource-policies production-disk \\

&nbsp; --resource-policies=daily-snapshots \\

&nbsp; --zone=us-central1-a



\# Restore in DR region (during disaster)

gcloud compute disks create dr-restored-disk \\

&nbsp; --source-snapshot=snapshot-name \\

&nbsp; --zone=us-east1-b

```



\### Application State Replication



\*\*Redis/Memcached\*\*:

```bash

\# Deploy Memorystore with cross-region replica

gcloud redis instances create primary-cache \\

&nbsp; --size=5 \\

&nbsp; --region=us-central1 \\

&nbsp; --tier=standard \\

&nbsp; --replica-count=1 \\

&nbsp; --read-replicas-mode=READ\_REPLICAS\_ENABLED



\# Configure read replica in DR region

gcloud redis instances create dr-cache-replica \\

&nbsp; --size=5 \\

&nbsp; --region=us-east1 \\

&nbsp; --tier=standard

```



---



\## 5. Backup and Recovery



\### Backup Strategy



\*\*3-2-1 Rule\*\*:

\- \*\*3\*\* copies of data

\- \*\*2\*\* different storage types

\- \*\*1\*\* off-site copy



\*\*Implementation\*\*:

```bash

\# Primary data: Production database

\# Copy 1: Daily snapshots in same region

\# Copy 2: Cross-region Cloud Storage backup

\# Copy 3: On-premises backup (off-site)



\# Automated backup script

\#!/bin/bash

DATE=$(date +%Y%m%d)



\# Database backup

gcloud sql backups create \\

&nbsp; --instance=production-database \\

&nbsp; --description="Daily backup $DATE"



\# Export to Cloud Storage

gcloud sql export sql production-database \\

&nbsp; gs://backup-bucket/db-backup-$DATE.sql \\

&nbsp; --database=production\_db



\# Copy to DR region

gsutil cp gs://backup-bucket/db-backup-$DATE.sql \\

&nbsp; gs://dr-backup-bucket/db-backup-$DATE.sql



\# Verify backup integrity

gsutil hash gs://backup-bucket/db-backup-$DATE.sql

```



\### Backup Testing



\*\*Monthly Restore Drill\*\*:

```bash

\#!/bin/bash

\# Monthly DR restore test



\# 1. Create test instance

gcloud sql instances create dr-test-restore \\

&nbsp; --region=us-east1 \\

&nbsp; --tier=db-n1-standard-1



\# 2. Restore from backup

LATEST\_BACKUP=$(gcloud sql backups list \\

&nbsp; --instance=production-database \\

&nbsp; --limit=1 \\

&nbsp; --format="value(id)")



gcloud sql backups restore $LATEST\_BACKUP \\

&nbsp; --backup-instance=production-database \\

&nbsp; --backup-id=$LATEST\_BACKUP \\

&nbsp; --restore-instance=dr-test-restore



\# 3. Validate data integrity

\# (Run application-specific validation queries)



\# 4. Document results and cleanup

gcloud sql instances delete dr-test-restore --quiet



echo "DR restore test completed: $(date)" >> /var/log/dr-tests.log

```



\### Retention Policies



| Data Type | Retention Period | Storage Location |

|-----------|-----------------|------------------|

| Database Backups | 30 days | Primary + DR regions |

| Snapshots | 7 days | Primary region |

| Application Logs | 90 days | Cloud Storage dual-region |

| Audit Logs | 7 years | Cold Storage (Archive) |

| Configuration Backups | 1 year | Version control + Cloud Storage |



---



\## 6. Testing and Validation



\### Quarterly DR Drill Schedule



\*\*Q1: VPN Tunnel Failover Test\*\*

\- Objective: Validate automatic failover between tunnels

\- Procedure: Disable primary tunnel, monitor BGP convergence

\- Success Criteria: < 60 second failover, zero packet loss after convergence



\*\*Q2: Regional Failover Test\*\*

\- Objective: Validate multi-region failover procedures

\- Procedure: Simulate primary region failure, execute failover runbook

\- Success Criteria: < 15 minute RTO, < 15 minute RPO



\*\*Q3: Database Restore Test\*\*

\- Objective: Validate backup and restore procedures

\- Procedure: Restore production backup to test environment

\- Success Criteria: Complete restore, data integrity verified



\*\*Q4: Full DR Exercise\*\*

\- Objective: Test complete disaster recovery procedures

\- Procedure: Simulate datacenter failure, full failover to DR

\- Success Criteria: All Tier 1 applications operational within RTO



\### Test Documentation Template

```markdown

\## DR Test Report



\*\*Test Date\*\*: YYYY-MM-DD

\*\*Test Type\*\*: \[Tunnel Failover | Regional Failover | Full DR]

\*\*Conducted By\*\*: \[Name]



\### Test Objectives

\- \[Objective 1]

\- \[Objective 2]



\### Test Procedure

1\. \[Step 1]

2\. \[Step 2]



\### Results

\- \*\*RTO Achieved\*\*: \[Time]

\- \*\*RPO Achieved\*\*: \[Time]

\- \*\*Issues Identified\*\*: \[List]



\### Action Items

\- \[ ] \[Action 1 - Owner - Due Date]

\- \[ ] \[Action 2 - Owner - Due Date]



\### Lessons Learned

\- \[Lesson 1]

\- \[Lesson 2]



\### Next Test Date

\- \*\*Scheduled\*\*: YYYY-MM-DD

```



---



\## 7. Monitoring and Alerting



\### Critical Metrics



\*\*VPN Health\*\*:

\- Tunnel status (UP/DOWN)

\- BGP session state

\- Packet loss percentage

\- Latency (milliseconds)

\- Throughput utilization



\*\*Replication Health\*\*:

\- Database replication lag

\- Snapshot age

\- Backup success rate

\- Storage replication sync time



\*\*Application Health\*\*:

\- Service availability

\- Response time

\- Error rate

\- Active user count



\### Alerting Configuration

```bash

\# Create uptime check for application

gcloud monitoring uptime create app-health-check \\

&nbsp; --display-name="Application Health Check" \\

&nbsp; --resource-type=uptime-url \\

&nbsp; --http-check-path=/health \\

&nbsp; --monitored-resource=app.example.com \\

&nbsp; --check-interval=60s



\# Create alert policy for VPN tunnel down

gcloud alpha monitoring policies create \\

&nbsp; --notification-channels=CHANNEL\_ID \\

&nbsp; --display-name="VPN Tunnel Down" \\

&nbsp; --condition-display-name="Tunnel Status" \\

&nbsp; --condition-threshold-value=1 \\

&nbsp; --condition-threshold-duration=60s \\

&nbsp; --aggregation-period=60s \\

&nbsp; --metric-type=compute.googleapis.com/vpn/tunnel\_established

```



\### Escalation Procedures



| Severity | Response Time | Escalation |

|----------|--------------|------------|

| P1 (Critical) | 15 minutes | On-call engineer → Manager → Director |

| P2 (High) | 1 hour | On-call engineer → Manager |

| P3 (Medium) | 4 hours | Ticket assigned to team |

| P4 (Low) | Next business day | Queue for review |



---



\## 8. Business Continuity Planning



\### Communication Plan



\*\*Stakeholder Notification Matrix\*\*:



| Incident Severity | Notify Within | Recipients |

|-------------------|---------------|-----------|

| P1 | 15 minutes | CTO, VP Engineering, Operations, Customer Support |

| P2 | 1 hour | VP Engineering, Operations Manager |

| P3 | 4 hours | Operations Team |



\*\*Communication Templates\*\*:

```

SUBJECT: \[P1] Production Incident - Primary Region Failure



SUMMARY: Primary region (us-central1) experiencing connectivity issues.

STATUS: Failover to DR region (us-east1) in progress.

IMPACT: \[Describe customer impact]

ETA: \[Estimated time to resolution]

NEXT UPDATE: \[Time]



ACTIONS TAKEN:

\- \[Action 1]

\- \[Action 2]



INCIDENT COMMANDER: \[Name]

INCIDENT BRIDGE: \[Conference line]

```



\### Disaster Declaration Criteria



\*\*Declare Disaster When\*\*:

\- Primary region unavailable > 30 minutes

\- Data loss > RPO threshold

\- Multiple critical systems affected

\- Estimated recovery time > RTO



\*\*Authority to Declare\*\*:

\- On-call Engineer (during off-hours)

\- VP Engineering (business hours)

\- CTO (escalation)



---



\## 9. Recovery Procedures



\### Post-Disaster Recovery (Return to Primary)



\*\*Prerequisites\*\*:

\- Primary region fully operational

\- Root cause identified and remediated

\- Stakeholder approval for fallback



\*\*Procedure\*\*:

```bash

\#!/bin/bash

\# Fallback to primary region



\# 1. Sync data from DR to primary

echo "Syncing data to primary region..."

gcloud sql instances create primary-database-new \\

&nbsp; --region=us-central1



\# Replicate from DR (now primary) to restored primary region

gcloud sql instances patch primary-database-new \\

&nbsp; --replication=ASYNCHRONOUS \\

&nbsp; --master-instance-name=dr-database-replica



\# 2. Verify replication caught up

\# (Monitor replication lag until < 1 second)



\# 3. Stop DR region writes (maintenance mode)

\# (Application-specific procedure)



\# 4. Promote new primary region instance

gcloud sql instances promote-replica primary-database-new



\# 5. Update DNS back to primary

gcloud dns record-sets transaction start --zone=production-zone

\# (Update A records back to primary region IPs)

gcloud dns record-sets transaction execute --zone=production-zone



\# 6. Resume normal operations

echo "Fallback complete. Primary region active."

```



---



\## 10. Cost Optimization for DR



\### Right-Sizing DR Resources



\*\*Active-Passive Model\*\*:

\- Keep DR instances in "stopped" state

\- Start during disaster or testing

\- Save ~60% on compute costs



\*\*Committed Use Discounts\*\*:

\- Apply to primary region resources

\- Use on-demand pricing for DR resources



\*\*Storage Optimization\*\*:

```bash

\# Use Nearline storage for DR backups

gsutil mb -c NEARLINE -l us-east1 gs://dr-backup-nearline



\# Lifecycle policy for old backups

cat > lifecycle.json <<EOF

{

&nbsp; "lifecycle": {

&nbsp;   "rule": \[

&nbsp;     {

&nbsp;       "action": {"type": "SetStorageClass", "storageClass": "ARCHIVE"},

&nbsp;       "condition": {"age": 90}

&nbsp;     },

&nbsp;     {

&nbsp;       "action": {"type": "Delete"},

&nbsp;       "condition": {"age": 365}

&nbsp;     }

&nbsp;   ]

&nbsp; }

}

EOF



gsutil lifecycle set lifecycle.json gs://dr-backup-nearline

```



\### DR Cost Estimation



\*\*Monthly DR Costs\*\* (2 Gbps scenario):



| Component | Cost |

|-----------|------|

| DR VPN Gateway | $36.50 |

| 4 DR VPN Tunnels | $146.00 |

| DR Cloud Router | $0 |

| Stopped Instances | $0 (stopped) |

| Snapshot Storage (7 days) | ~$50 |

| Cross-Region Backup Storage | ~$200 |

| \*\*Total DR Monthly Cost\*\* | \*\*$432.50\*\* |



\*\*Cost During Active DR\*\* (full region failover):

\- Compute instances running: +$2,000/month

\- Database replica promoted: +$500/month

\- Increased egress: +$1,000/month

\- \*\*Total Active DR Cost\*\*: ~$3,932.50/month



---



\*\*Document Version\*\*: 1.0  

\*\*Last Updated\*\*: February 2026  

\*\*Author\*\*: Gregory B. Horne  

\*\*Review Cycle\*\*: Quarterly and after incidents

