# VMware to GCP Hybrid Connectivity Architecture

Enterprise-grade hybrid connectivity between on-premises VMware vSphere infrastructure and Google Cloud Platform using HA VPN with BGP dynamic routing. Deployed and validated in February 2026 with 4 tunnels established, 4 BGP sessions active, and verified end-to-end connectivity at 2.7ms average RTT.

---

## Architecture Overview

### Cloud Sandbox Simulation

Due to GCP Cloud Sandbox restrictions that prevent direct VMware Engine access, this deployment uses a VPC-to-VPC architecture to simulate real-world hybrid connectivity. The VPN tunnels, BGP configuration, routing behavior, and network performance characteristics are identical to production VMware-to-GCP hybrid deployments.

- **onprem-vpc (10.2.0.0/24)**: Simulates the on-premises VMware vSphere datacenter
- **vm-onprem (10.2.0.2)**: Represents workloads running on VMware ESXi hosts
- **cloud-vpc (10.1.0.0/24)**: Represents the GCP production environment
- **vm-cloud (10.1.0.2)**: Represents cloud-native workloads running in GCP

### Network Topology

```
Cloud VPC (10.1.0.0/24)              On-Prem VPC (10.2.0.0/24)
        |                                     |
   vm-cloud (10.1.0.2) <-------------------> vm-onprem (10.2.0.2)
        |                                     |
   cloud-router                          onprem-router
    (ASN 65001) <---------- BGP ----------> (ASN 65002)
        |                                     |
   cloud-vpn-gw                          onprem-vpn-gw
  (Interface 0,1) <====== VPN =======> (Interface 0,1)

  4 Tunnels (ESTABLISHED)
  4 BGP Sessions (UP)
```

---

## Components Deployed

**Network Infrastructure**: 2 VPC networks (custom subnet mode), 2 Cloud Routers with BGP (ASN 65001, 65002), 2 subnets (10.1.0.0/24, 10.2.0.0/24).

**VPN Infrastructure**: 2 HA VPN gateways (dual interface), 4 VPN tunnels (IKEv2, all established), 4 BGP peering sessions (all active).

**Security**: VPC firewall rules for internal traffic and SSH, IPsec encryption (AES-256), network segmentation.

**Test VMs**: vm-cloud (10.1.0.2) representing GCP workloads, vm-onprem (10.2.0.2) representing on-premises VMware workloads.

---

## Connectivity Test Results

### Cloud VM to On-Prem VM

```
PING 10.2.0.2 (10.2.0.2) 56(84) bytes of data.
64 bytes from 10.2.0.2: icmp_seq=1 ttl=62 time=5.48 ms
64 bytes from 10.2.0.2: icmp_seq=2 ttl=62 time=2.80 ms
64 bytes from 10.2.0.2: icmp_seq=3 ttl=62 time=2.72 ms
64 bytes from 10.2.0.2: icmp_seq=4 ttl=62 time=2.70 ms

4 packets transmitted, 4 received, 0% packet loss, time 3006ms
```

### On-Prem VM to Cloud VM

```
PING 10.1.0.2 (10.1.0.2) 56(84) bytes of data.
64 bytes from 10.1.0.2: icmp_seq=1 ttl=62 time=2.61 ms
64 bytes from 10.1.0.2: icmp_seq=2 ttl=62 time=2.78 ms
64 bytes from 10.1.0.2: icmp_seq=3 ttl=62 time=2.66 ms
64 bytes from 10.1.0.2: icmp_seq=4 ttl=62 time=2.59 ms

4 packets transmitted, 4 received, 0% packet loss, time 3006ms
```

---

## Quick Start Deployment

### Prerequisites

```bash
export PROJECT_ID="your-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export SHARED_SECRET="your-strong-secret"
```

### Step 1: Create VPCs

```bash
gcloud compute networks create cloud-vpc --project=$PROJECT_ID --subnet-mode=custom
gcloud compute networks subnets create cloud-subnet --project=$PROJECT_ID --network=cloud-vpc --region=$REGION --range=10.1.0.0/24

gcloud compute networks create onprem-vpc --project=$PROJECT_ID --subnet-mode=custom
gcloud compute networks subnets create onprem-subnet --project=$PROJECT_ID --network=onprem-vpc --region=$REGION --range=10.2.0.0/24
```

### Step 2: Create Cloud Routers

```bash
gcloud compute routers create cloud-router --project=$PROJECT_ID --region=$REGION --network=cloud-vpc --asn=65001
gcloud compute routers create onprem-router --project=$PROJECT_ID --region=$REGION --network=onprem-vpc --asn=65002
```

### Step 3: Create VPN Gateways

```bash
gcloud compute vpn-gateways create cloud-vpn-gw --project=$PROJECT_ID --region=$REGION --network=cloud-vpc
gcloud compute vpn-gateways create onprem-vpn-gw --project=$PROJECT_ID --region=$REGION --network=onprem-vpc
```

### Step 4: Create VPN Tunnels

```bash
gcloud compute vpn-tunnels create tunnel-1 --project=$PROJECT_ID --region=$REGION --vpn-gateway=cloud-vpn-gw --peer-gcp-gateway=onprem-vpn-gw --router=cloud-router --ike-version=2 --shared-secret="$SHARED_SECRET" --interface=0
gcloud compute vpn-tunnels create tunnel-2 --project=$PROJECT_ID --region=$REGION --vpn-gateway=cloud-vpn-gw --peer-gcp-gateway=onprem-vpn-gw --router=cloud-router --ike-version=2 --shared-secret="$SHARED_SECRET" --interface=1
gcloud compute vpn-tunnels create tunnel-3 --project=$PROJECT_ID --region=$REGION --vpn-gateway=onprem-vpn-gw --peer-gcp-gateway=cloud-vpn-gw --router=onprem-router --ike-version=2 --shared-secret="$SHARED_SECRET" --interface=0
gcloud compute vpn-tunnels create tunnel-4 --project=$PROJECT_ID --region=$REGION --vpn-gateway=onprem-vpn-gw --peer-gcp-gateway=cloud-vpn-gw --router=onprem-router --ike-version=2 --shared-secret="$SHARED_SECRET" --interface=1
```

### Step 5: Configure BGP

```bash
# Tunnel 1 BGP
gcloud compute routers add-interface cloud-router --project=$PROJECT_ID --region=$REGION --interface-name=if-tunnel-1 --vpn-tunnel=tunnel-1 --ip-address=169.254.1.1 --mask-length=30
gcloud compute routers add-bgp-peer cloud-router --project=$PROJECT_ID --region=$REGION --peer-name=bgp-peer-tunnel-1 --interface=if-tunnel-1 --peer-ip-address=169.254.1.2 --peer-asn=65002

# Tunnel 2 BGP
gcloud compute routers add-interface cloud-router --project=$PROJECT_ID --region=$REGION --interface-name=if-tunnel-2 --vpn-tunnel=tunnel-2 --ip-address=169.254.2.1 --mask-length=30
gcloud compute routers add-bgp-peer cloud-router --project=$PROJECT_ID --region=$REGION --peer-name=bgp-peer-tunnel-2 --interface=if-tunnel-2 --peer-ip-address=169.254.2.2 --peer-asn=65002

# Tunnel 3 BGP
gcloud compute routers add-interface onprem-router --project=$PROJECT_ID --region=$REGION --interface-name=if-tunnel-3 --vpn-tunnel=tunnel-3 --ip-address=169.254.1.2 --mask-length=30
gcloud compute routers add-bgp-peer onprem-router --project=$PROJECT_ID --region=$REGION --peer-name=bgp-peer-tunnel-3 --interface=if-tunnel-3 --peer-ip-address=169.254.1.1 --peer-asn=65001

# Tunnel 4 BGP
gcloud compute routers add-interface onprem-router --project=$PROJECT_ID --region=$REGION --interface-name=if-tunnel-4 --vpn-tunnel=tunnel-4 --ip-address=169.254.2.2 --mask-length=30
gcloud compute routers add-bgp-peer onprem-router --project=$PROJECT_ID --region=$REGION --peer-name=bgp-peer-tunnel-4 --interface=if-tunnel-4 --peer-ip-address=169.254.2.1 --peer-asn=65001
```

### Step 6: Create Firewall Rules

```bash
gcloud compute firewall-rules create cloud-allow-internal --project=$PROJECT_ID --network=cloud-vpc --allow=tcp,udp,icmp --source-ranges=10.1.0.0/24,10.2.0.0/24
gcloud compute firewall-rules create cloud-allow-ssh --project=$PROJECT_ID --network=cloud-vpc --allow=tcp:22 --source-ranges=0.0.0.0/0
gcloud compute firewall-rules create onprem-allow-internal --project=$PROJECT_ID --network=onprem-vpc --allow=tcp,udp,icmp --source-ranges=10.1.0.0/24,10.2.0.0/24
gcloud compute firewall-rules create onprem-allow-ssh --project=$PROJECT_ID --network=onprem-vpc --allow=tcp:22 --source-ranges=0.0.0.0/0
```

### Step 7: Create Test VMs

```bash
gcloud compute instances create vm-cloud --project=$PROJECT_ID --zone=$ZONE --machine-type=e2-micro --network-interface=subnet=cloud-subnet,no-address --image-family=debian-12 --image-project=debian-cloud
gcloud compute instances create vm-onprem --project=$PROJECT_ID --zone=$ZONE --machine-type=e2-micro --network-interface=subnet=onprem-subnet,no-address --image-family=debian-12 --image-project=debian-cloud
```

---

## Cost Analysis

### HA VPN (us-central1)

| Component | Monthly Cost |
|-----------|-------------|
| VPN Gateway | $36.50 |
| 4 VPN Tunnels | $146.00 |
| Egress (648 TB @ $0.08/GB) | $51,840.00 |
| **Total (2 Gbps sustained)** | **$52,022.50** |

### Dedicated Interconnect Comparison

| Component | Monthly Cost |
|-----------|-------------|
| 10 Gbps Port | $1,650.00 |
| 2 VLAN Attachments | $200.00 |
| Egress (648 TB @ $0.02/GB) | $12,960.00 |
| **Total (2 Gbps sustained)** | **$14,810.00** |

Dedicated Interconnect becomes cost-effective at approximately 500 Mbps sustained throughput, saving $37,212.50/month at 2 Gbps.

---

## Technical Highlights

**BGP Configuration**: Dynamic route exchange with automatic failover across 4 tunnels, link-local addressing (169.254.x.x), and equal-cost multipath routing.

**High Availability**: Redundant VPN gateways with multiple tunnel pairs, no single point of failure, 99.99% SLA.

**Security**: IPsec encryption (IKEv2), VPC firewall rules, network segmentation, private IP addressing throughout.

---

## Documentation

| Document | Purpose |
|----------|---------|
| [Executive Summary](docs/executive-summary.md) | High-level overview, cost summary, risk analysis |
| [Cost Analysis](docs/cost-analysis.md) | Cost comparison across bandwidth scenarios, TCO analysis |
| [Design Decisions](docs/design-decisions.md) | Architectural rationale and alternatives considered |
| [Lessons Learned](docs/lessons-learned.md) | Common pitfalls and prevention strategies |
| [Security Best Practices](docs/security-best-practices.md) | Encryption, IAM, monitoring, and compliance |
| [Disaster Recovery](docs/disaster-recovery.md) | Failover procedures, backup strategies, DR testing |

---

## Repository Structure

```
vmware-gcp-hybrid-connectivity/
    README.md
    docs/
        executive-summary.md
        cost-analysis.md
        design-decisions.md
        lessons-learned.md
        security-best-practices.md
        disaster-recovery.md
    assets/
        screenshots/
```

---

## Author

**Gregory B. Horne**
Cloud Solutions Architect

[GitHub: gbhorne](https://github.com/gbhorne) | [LinkedIn](https://linkedin.com/in/gbhorne)

---

## License

Available for educational and portfolio purposes.
