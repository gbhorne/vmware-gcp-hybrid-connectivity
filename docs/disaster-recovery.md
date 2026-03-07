# Disaster Recovery and Multi-Region Strategies

## Overview

This document outlines disaster recovery architecture, multi-region deployment strategies, and business continuity planning for VMware to GCP hybrid connectivity deployments.

---

## 1. Recovery Objectives

**Recovery Time Objective (RTO)**: Maximum acceptable time to restore service after a disruption.
**Recovery Point Objective (RPO)**: Maximum acceptable data loss measured in time.

### Target Objectives by Tier

| Service Tier | RTO | RPO | Availability Target |
|--------------|-----|-----|-------------------|
| Tier 1 (Critical) | < 1 hour | < 15 minutes | 99.99% |
| Tier 2 (Important) | < 4 hours | < 1 hour | 99.9% |
| Tier 3 (Standard) | < 24 hours | < 4 hours | 99.5% |
| Tier 4 (Low Priority) | < 72 hours | < 24 hours | 99.0% |

**Tier 1 Examples**: Customer-facing e-commerce platforms, financial transaction systems, real-time inventory management, critical authentication services.

**Tier 2 Examples**: Internal business applications, reporting and analytics platforms, customer support systems, email and collaboration tools.

---

## 2. Multi-Region HA VPN Architecture

### Active-Active Multi-Region Design

```
On-Premises Datacenter
        |
   +----+----+
   |         |
VPN Device A  VPN Device B
   |         |
   +----+----+-------- 4 Tunnels --------+
   |         |                           |
   |         +-------- 4 Tunnels ------+ |
   |                                   | |
+--+--------------------+        +-----+-+--------------------+
|  us-central1          |        |   us-east1                 |
|  (Primary Region)     |        |   (DR Region)              |
|                       |        |                            |
|  HA VPN Gateway       |        |   HA VPN Gateway           |
|  Cloud Router         |        |   Cloud Router             |
|  ASN: 65001           |        |   ASN: 65003               |
|                       |        |                            |
|  Production VPC       |<------>|   DR VPC                   |
|  10.100.0.0/16        | Peer   |   10.200.0.0/16            |
|                       |        |                            |
|  Application Tier     |        |   Standby Tier             |
|  Database Primary     |<-Rep-->|   Database Replica         |
+-----------------------+        +----------------------------+
```

### Implementation Steps

```bash
# Create DR region VPC
gcloud compute networks create dr-vpc \
  --subnet-mode=custom \
  --bgp-routing-mode=regional

# Create DR subnet
gcloud compute networks subnets create dr-subnet \
  --network=dr-vpc \
  --region=us-east1 \
  --range=10.200.0.0/16

# Create DR Cloud Router
gcloud compute routers create dr-router \
  --network=dr-vpc \
  --region=us-east1 \
  --asn=65003

# Create DR VPN Gateway
gcloud compute vpn-gateways create dr-vpn-gw \
  --network=dr-vpc \
  --region=us-east1

# Create VPN tunnels (repeat for all 4 tunnels)
gcloud compute vpn-tunnels create dr-tunnel-1 \
  --vpn-gateway=dr-vpn-gw \
  --peer-external-gateway=onprem-external-gw \
  --peer-external-gateway-interface=0 \
  --router=dr-router \
  --ike-version=2 \
  --shared-secret="$DR_SHARED_SECRET" \
  --interface=0 \
  --region=us-east1

# Configure BGP with lower priority for DR region
gcloud compute routers add-interface dr-router \
  --interface-name=if-dr-tunnel-1 \
  --vpn-tunnel=dr-tunnel-1 \
  --ip-address=169.254.10.1 \
  --mask-length=30 \
  --region=us-east1

gcloud compute routers add-bgp-peer dr-router \
  --peer-name=bgp-peer-dr-tunnel-1 \
  --interface=if-dr-tunnel-1 \
  --peer-ip-address=169.254.10.2 \
  --peer-asn=65002 \
  --advertised-route-priority=200 \
  --region=us-east1
```

### BGP Route Priority Configuration

Primary region (us-central1): advertised route priority 100 (default), local preference 150 on on-premises side.

DR region (us-east1): advertised route priority 200 (lower), local preference 100 on on-premises side.

This ensures traffic prefers the primary region during normal operations and automatically fails over to the DR region during outages.

---

## 3. Failover Scenarios and Procedures

### Scenario 1: Primary VPN Tunnel Failure

**Detection**: VPN tunnel status changes to "DOWN", BGP session transitions to "IDLE", automated monitoring alerts fire.

**Automatic Response**: BGP withdraws routes via the failed tunnel. Traffic automatically shifts to the remaining 3 tunnels. No manual intervention required.

**Recovery Time**: 30-60 seconds (BGP convergence).

```bash
# Verify tunnel status
gcloud compute vpn-tunnels list --filter="region:us-central1"

# Check BGP sessions
gcloud compute routers get-status cloud-router --region=us-central1

# Test connectivity
ping -c 4 <onprem-test-server>
```

### Scenario 2: Primary Region Failure

**Detection**: All VPN tunnels in primary region DOWN, regional GCP service disruption, application health checks failing.

**Automatic Response**: BGP withdraws all routes from primary region. On-premises router selects DR region routes. Traffic automatically shifts to us-east1.

**Manual Response Required**:
1. Verify DR region connectivity
2. Promote DR database replicas to primary
3. Update DNS to point to DR region
4. Validate application functionality

**Recovery Time**: Network failover 60-90 seconds (automatic). Application failover 5-15 minutes (manual procedures).

**Failover Runbook**:

```bash
#!/bin/bash

# 1. Verify DR region connectivity
echo "Testing DR region connectivity..."
gcloud compute vpn-tunnels list --filter="region:us-east1"

# 2. Promote database replicas
echo "Promoting database replicas..."
gcloud sql instances promote-replica dr-database-replica

# 3. Update Cloud DNS
echo "Updating DNS records..."
gcloud dns record-sets transaction start --zone=production-zone
gcloud dns record-sets transaction remove \
  --name=app.example.com. --type=A --ttl=300 \
  --zone=production-zone "35.1.1.1"
gcloud dns record-sets transaction add \
  --name=app.example.com. --type=A --ttl=60 \
  --zone=production-zone "34.2.2.2"
gcloud dns record-sets transaction execute --zone=production-zone

# 4. Start DR region workloads
echo "Starting DR workloads..."
gcloud compute instances start dr-app-server-1 --zone=us-east1-b
gcloud compute instances start dr-app-server-2 --zone=us-east1-c

# 5. Validate application
echo "Validating application health..."
curl -f https://app.example.com/health || echo "ERROR: Health check failed"

echo "DR failover complete. Notify operations team."
```

### Scenario 3: Complete On-Premises Datacenter Failure

All VPN tunnels go DOWN from both regions. GCP-hosted applications continue running if cloud-native. Applications dependent on on-premises resources fail. Activate business continuity procedures.

**Mitigation Strategy**: Replicate critical on-premises data to GCP, deploy backup authentication services in GCP, and establish cloud-only operational mode for critical applications.

---

## 4. Data Replication Strategies

### Database Replication

```bash
# Create read replica in DR region
gcloud sql instances create dr-database-replica \
  --master-instance-name=primary-database \
  --region=us-east1 \
  --replica-type=READ

# Promote to standalone (during failover)
gcloud sql instances promote-replica dr-database-replica
```

### File Storage Replication

```bash
# Enable dual-region bucket
gsutil mb -c STANDARD -l us gs://production-data-dual-region

# Set up cross-region replication
gsutil rsync -r -d gs://primary-bucket gs://dr-bucket
```

### Persistent Disk Snapshots

```bash
# Create snapshot schedule
gcloud compute resource-policies create snapshot-schedule daily-snapshots \
  --region=us-central1 \
  --max-retention-days=7 \
  --on-source-disk-delete=keep-auto-snapshots \
  --daily-schedule \
  --start-time=02:00

# Attach to disk
gcloud compute disks add-resource-policies production-disk \
  --resource-policies=daily-snapshots \
  --zone=us-central1-a

# Restore in DR region (during disaster)
gcloud compute disks create dr-restored-disk \
  --source-snapshot=snapshot-name \
  --zone=us-east1-b
```

---

## 5. Backup and Recovery

### Backup Strategy (3-2-1 Rule)

- **3** copies of data
- **2** different storage types
- **1** off-site copy

Implementation: primary database (production), daily snapshots in same region (copy 1), cross-region Cloud Storage backup (copy 2), on-premises backup (copy 3/off-site).

### Retention Policies

| Data Type | Retention Period | Storage Location |
|-----------|-----------------|------------------|
| Database Backups | 30 days | Primary + DR regions |
| Snapshots | 7 days | Primary region |
| Application Logs | 90 days | Cloud Storage dual-region |
| Audit Logs | 7 years | Cold Storage (Archive) |
| Configuration Backups | 1 year | Version control + Cloud Storage |

---

## 6. Testing and Validation

### Quarterly DR Drill Schedule

**Q1 - VPN Tunnel Failover Test**: Disable primary tunnel, monitor BGP convergence. Success criteria: < 60 second failover, zero packet loss after convergence.

**Q2 - Regional Failover Test**: Simulate primary region failure, execute failover runbook. Success criteria: < 15 minute RTO, < 15 minute RPO.

**Q3 - Database Restore Test**: Restore production backup to test environment. Success criteria: complete restore with data integrity verified.

**Q4 - Full DR Exercise**: Simulate datacenter failure, full failover to DR. Success criteria: all Tier 1 applications operational within RTO.

---

## 7. Monitoring and Alerting

### Critical Metrics

**VPN Health**: Tunnel status (UP/DOWN), BGP session state, packet loss percentage, latency (ms), throughput utilization.

**Replication Health**: Database replication lag, snapshot age, backup success rate, storage replication sync time.

**Application Health**: Service availability, response time, error rate, active user count.

### Escalation Procedures

| Severity | Response Time | Escalation |
|----------|--------------|------------|
| P1 (Critical) | 15 minutes | On-call engineer -> Manager -> Director |
| P2 (High) | 1 hour | On-call engineer -> Manager |
| P3 (Medium) | 4 hours | Ticket assigned to team |
| P4 (Low) | Next business day | Queue for review |

---

## 8. Business Continuity Planning

### Stakeholder Notification Matrix

| Incident Severity | Notify Within | Recipients |
|-------------------|---------------|-----------|
| P1 | 15 minutes | CTO, VP Engineering, Operations, Customer Support |
| P2 | 1 hour | VP Engineering, Operations Manager |
| P3 | 4 hours | Operations Team |

### Disaster Declaration Criteria

Declare disaster when: primary region is unavailable for > 30 minutes, data loss exceeds RPO threshold, multiple critical systems are affected, or estimated recovery time exceeds RTO.

---

## 9. DR Cost Estimation

### Monthly DR Costs (2 Gbps scenario, standby state)

| Component | Cost |
|-----------|------|
| DR VPN Gateway | $36.50 |
| 4 DR VPN Tunnels | $146.00 |
| DR Cloud Router | $0.00 |
| Stopped Instances | $0.00 |
| Snapshot Storage (7 days) | ~$50.00 |
| Cross-Region Backup Storage | ~$200.00 |
| **Total DR Monthly (standby)** | **$432.50** |

**Active DR Cost** (full region failover): Add ~$2,000/month compute, ~$500/month database, ~$1,000/month increased egress = approximately **$3,932.50/month**.

---

**Document Version**: 1.0
**Last Updated**: February 2026
**Author**: Gregory B. Horne
**Review Cycle**: Quarterly and after incidents
