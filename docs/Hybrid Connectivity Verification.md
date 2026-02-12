\# VMware to GCP Hybrid Connectivity – Deployment Verification



```text

NETWORK: cloud-vpc



╔═══════════════════════════════════════════════════════════════╗

║   VMware to GCP Hybrid Connectivity - Deployment Verification ║

║   Author: Gregory B. Horne                                    ║

║   Date: February 2026                                         ║

╚═══════════════════════════════════════════════════════════════╝



This script will verify all deployed GCP resources for the

VMware to GCP hybrid connectivity architecture.



============================================================

1\. PROJECT INFORMATION

============================================================



Project ID: playground-s-11-103aa1c1

Region: us-central1

Zone: us-central1-a



------------------------------------------------------------

Project Details

------------------------------------------------------------

PROJECT\_ID: playground-s-11-103aa1c1

NAME: playground-s-11-103aa1c1

PROJECT\_NUMBER: 824375663456

CREATE\_TIME: 2026-02-12T13:22:51.552229Z



------------------------------------------------------------

Enabled APIs (relevant to deployment)

------------------------------------------------------------

NAME: projects/824375663456/services/compute.googleapis.com



============================================================

2\. VPC NETWORKS

============================================================



------------------------------------------------------------

VPC Networks Created

------------------------------------------------------------

NAME: cloud-vpc

AUTO\_CREATE\_SUBNETWORKS: False



NAME: onprem-vpc

AUTO\_CREATE\_SUBNETWORKS: False



✓ 2 VPC networks verified (cloud-vpc, onprem-vpc)



============================================================

3\. SUBNETS

============================================================



------------------------------------------------------------

Subnets in Region: us-central1

------------------------------------------------------------

NAME: cloud-subnet

NETWORK: cloud-vpc

REGION: us-central1

IP\_RANGE: 10.1.0.0/24



NAME: onprem-subnet

NETWORK: onprem-vpc

REGION: us-central1

IP\_RANGE: 10.2.0.0/24



------------------------------------------------------------

IP Address Space Verification

------------------------------------------------------------

&nbsp; Cloud Subnet:   10.1.0.0/24 (Expected: 10.1.0.0/24)

&nbsp; OnPrem Subnet:  10.2.0.0/24 (Expected: 10.2.0.0/24)

✓ IP address ranges match design specifications



============================================================

4\. CLOUD ROUTERS

============================================================



------------------------------------------------------------

Cloud Routers

------------------------------------------------------------

NAME: cloud-router

NETWORK: cloud-vpc

REGION: us-central1

ASN: 65001



NAME: onprem-router

NETWORK: onprem-vpc

REGION: us-central1

ASN: 65002



✓ BGP ASN configuration correct



============================================================

5\. HA VPN GATEWAYS

============================================================



NAME: cloud-vpn-gw

NETWORK: cloud-vpc

REGION: us-central1



NAME: onprem-vpn-gw

NETWORK: onprem-vpc

REGION: us-central1



✓ 2 HA VPN Gateways verified



============================================================

6\. VPN TUNNELS

============================================================



NAME: tunnel-1 — ESTABLISHED

NAME: tunnel-2 — ESTABLISHED

NAME: tunnel-3 — ESTABLISHED

NAME: tunnel-4 — ESTABLISHED



✓ All 4 VPN tunnels are ESTABLISHED



============================================================

7\. BGP SESSIONS

============================================================



Cloud Router:

STATUS: \['UP', 'UP']

STATE:  \['Established', 'Established']



OnPrem Router:

STATUS: \['UP', 'UP']

STATE:  \['Established', 'Established']



✓ All 4 BGP sessions are UP



============================================================

8\. ROUTE EXCHANGE

============================================================



✓ Cloud router learning on-prem routes (10.2.0.0/24)

✓ OnPrem router learning cloud routes (10.1.0.0/24)



============================================================

9\. FIREWALL RULES

============================================================



cloud-allow-internal

cloud-allow-ssh

onprem-allow-internal

onprem-allow-ssh



✓ Firewall rules correctly configured



============================================================

FINAL STATUS

============================================================



✓ HYBRID CONNECTIVITY VALIDATED — ENTERPRISE HA READY

```



