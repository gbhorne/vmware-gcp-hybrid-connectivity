NETWORK: cloud-vpc

╔═══════════════════════════════════════════════════════════════╗
║   VMware to GCP Hybrid Connectivity - Deployment Verification ║
║   Author: Gregory B. Horne                                    ║
║   Date: February 2026                                         ║
╚═══════════════════════════════════════════════════════════════╝

This script will verify all deployed GCP resources for the
VMware to GCP hybrid connectivity architecture.

Press Enter to continue...

============================================================
1. PROJECT INFORMATION
============================================================

Project ID: playground-s-11-103aa1c1
Region: us-central1
Zone: us-central1-a

------------------------------------------------------------
Project Details
------------------------------------------------------------
PROJECT_ID: playground-s-11-103aa1c1
NAME: playground-s-11-103aa1c1
PROJECT_NUMBER: 824375663456
CREATE_TIME: 2026-02-12T13:22:51.552229Z

------------------------------------------------------------
Enabled APIs (relevant to deployment)
------------------------------------------------------------
NAME: projects/824375663456/services/compute.googleapis.com
TITLE: 

============================================================
2. VPC NETWORKS
============================================================

------------------------------------------------------------
VPC Networks Created
------------------------------------------------------------
NAME: cloud-vpc
SUBNET_MODE: 
BGP_ROUTING: 
AUTO_CREATE_SUBNETWORKS: False

NAME: onprem-vpc
SUBNET_MODE: 
BGP_ROUTING: 
AUTO_CREATE_SUBNETWORKS: False

✓ 2 VPC networks verified (cloud-vpc, onprem-vpc)

============================================================
3. SUBNETS
============================================================

------------------------------------------------------------
Subnets in Region: us-central1
------------------------------------------------------------
NAME: cloud-subnet
NETWORK: cloud-vpc
REGION: us-central1
IP_RANGE: 10.1.0.0/24
PRIVATE_GOOGLE_ACCESS: False

NAME: onprem-subnet
NETWORK: onprem-vpc
REGION: us-central1
IP_RANGE: 10.2.0.0/24
PRIVATE_GOOGLE_ACCESS: False

------------------------------------------------------------
IP Address Space Verification
------------------------------------------------------------
  Cloud Subnet:   10.1.0.0/24 (Expected: 10.1.0.0/24)
  OnPrem Subnet:  10.2.0.0/24 (Expected: 10.2.0.0/24)
✓ IP address ranges match design specifications

============================================================
4. CLOUD ROUTERS
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

------------------------------------------------------------
BGP ASN Verification
------------------------------------------------------------
  Cloud Router ASN:   65001 (Expected: 65001)
  OnPrem Router ASN:  65002 (Expected: 65002)
✓ BGP ASN configuration correct

============================================================
5. HA VPN GATEWAYS
============================================================

------------------------------------------------------------
VPN Gateways
------------------------------------------------------------
NAME: cloud-vpn-gw
NETWORK: cloud-vpc
REGION: us-central1
INTERFACE_0_IP: 34.128.33.39
INTERFACE_1_IP: 34.157.228.242

NAME: onprem-vpn-gw
NETWORK: onprem-vpc
REGION: us-central1
INTERFACE_0_IP: 35.242.125.9
INTERFACE_1_IP: 34.157.224.81

✓ 2 HA VPN Gateways verified (cloud-vpn-gw, onprem-vpn-gw)

============================================================
6. VPN TUNNELS
============================================================

------------------------------------------------------------
VPN Tunnel Status
------------------------------------------------------------
NAME: tunnel-1
VPN_GATEWAY: cloud-vpn-gw
PEER_GATEWAY: onprem-vpn-gw
STATUS: ESTABLISHED
DETAILED_STATUS: Tunnel is up and running.

NAME: tunnel-2
VPN_GATEWAY: cloud-vpn-gw
PEER_GATEWAY: onprem-vpn-gw
STATUS: ESTABLISHED
DETAILED_STATUS: Tunnel is up and running.

NAME: tunnel-3
VPN_GATEWAY: onprem-vpn-gw
PEER_GATEWAY: cloud-vpn-gw
STATUS: ESTABLISHED
DETAILED_STATUS: Tunnel is up and running.

NAME: tunnel-4
VPN_GATEWAY: onprem-vpn-gw
PEER_GATEWAY: cloud-vpn-gw
STATUS: ESTABLISHED
DETAILED_STATUS: Tunnel is up and running.

------------------------------------------------------------
Tunnel Status Verification
------------------------------------------------------------
  Total Tunnels: 4
  Established Tunnels: 4
✓ All 4 VPN tunnels are ESTABLISHED

------------------------------------------------------------
Detailed Tunnel Configuration
------------------------------------------------------------
Tunnel: tunnel-1
detailedStatus: Tunnel is up and running.
ikeVersion: 2
name: tunnel-1
peerIp: 35.242.125.9
status: ESTABLISHED

Tunnel: tunnel-2
detailedStatus: Tunnel is up and running.
ikeVersion: 2
name: tunnel-2
peerIp: 34.157.224.81
status: ESTABLISHED

Tunnel: tunnel-3
detailedStatus: Tunnel is up and running.
ikeVersion: 2
name: tunnel-3
peerIp: 34.128.33.39
status: ESTABLISHED

Tunnel: tunnel-4
detailedStatus: Tunnel is up and running.
ikeVersion: 2
name: tunnel-4
peerIp: 34.157.228.242
status: ESTABLISHED

============================================================
7. BGP SESSIONS
============================================================

------------------------------------------------------------
Cloud Router BGP Status
------------------------------------------------------------
PEER_NAME: ['bgp-peer-tunnel-1', 'bgp-peer-tunnel-2']
LOCAL_IP: ['169.254.1.1', '169.254.2.1']
PEER_IP: ['169.254.1.2', '169.254.2.2']
STATE: ['Established', 'Established']
STATUS: ['UP', 'UP']
LEARNED_ROUTES: [1, 1]
UPTIME: ['3 minutes, 44 seconds', '2 hours, 32 minutes, 1 seconds']

------------------------------------------------------------
OnPrem Router BGP Status
------------------------------------------------------------
PEER_NAME: ['bgp-peer-tunnel-3', 'bgp-peer-tunnel-4']
LOCAL_IP: ['169.254.1.2', '169.254.2.2']
PEER_IP: ['169.254.1.1', '169.254.2.1']
STATE: ['Established', 'Established']
STATUS: ['UP', 'UP']
LEARNED_ROUTES: [1, 1]
UPTIME: ['3 minutes, 46 seconds', '2 hours, 32 minutes, 4 seconds']

------------------------------------------------------------
BGP Session Verification
------------------------------------------------------------
  Cloud Router BGP Sessions UP: 2/2
  OnPrem Router BGP Sessions UP: 2/2
  Total BGP Sessions UP: 4/4
  All BGP sessions are UP (Expected: 4, Current: 4)

============================================================
8. ROUTE EXCHANGE
============================================================

------------------------------------------------------------
Routes Advertised by Cloud Router
------------------------------------------------------------
ADVERTISED_ROUTE: ['10.1.0.0/24']
PRIORITY: [100]

------------------------------------------------------------
Routes Learned by Cloud Router
------------------------------------------------------------
10.2.0.0/24;10.2.0.0/24

------------------------------------------------------------
Routes Advertised by OnPrem Router
------------------------------------------------------------
ADVERTISED_ROUTE: ['10.2.0.0/24']
PRIORITY: [100]

------------------------------------------------------------
Routes Learned by OnPrem Router
------------------------------------------------------------
10.1.0.0/24;10.1.0.0/24

------------------------------------------------------------
Route Exchange Verification
------------------------------------------------------------
✓ Cloud router learning on-prem routes (10.2.0.0/24)
✓ OnPrem router learning cloud routes (10.1.0.0/24)

============================================================
9. FIREWALL RULES
============================================================

------------------------------------------------------------
Cloud VPC Firewall Rules
------------------------------------------------------------
NAME: cloud-allow-internal
NETWORK: cloud-vpc
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp,udp,icmp
SOURCE_RANGES: 10.1.0.0/24,10.2.0.0/24
TARGET_TAGS: 

NAME: cloud-allow-ssh
NETWORK: cloud-vpc
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp:22
SOURCE_RANGES: 0.0.0.0/0
TARGET_TAGS: 

------------------------------------------------------------
OnPrem VPC Firewall Rules
------------------------------------------------------------
NAME: onprem-allow-internal
NETWORK: onprem-vpc
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp,udp,icmp
SOURCE_RANGES: 10.1.0.0/24,10.2.0.0/24
TARGET_TAGS: 

NAME: onprem-allow-ssh
NETWORK: onprem-vpc
DIRECTION: INGRESS
PRIORITY: 1000
ALLOW: tcp:22
SOURCE_RANGES: 0.0.0.0/0
TARGET_TAGS: 

  Cloud VPC Firewall Rules: 2
  OnPrem VPC Firewall Rules: 2

============================================================
10. COMPUTE INSTANCES
============================================================

------------------------------------------------------------
VM Instances
------------------------------------------------------------
NAME: vm-cloud
ZONE: us-central1-a
MACHINE_TYPE: e2-micro
INTERNAL_IP: 10.1.0.2
NETWORK: cloud-vpc
STATUS: RUNNING

NAME: vm-onprem
ZONE: us-central1-a
MACHINE_TYPE: e2-micro
INTERNAL_IP: 10.2.0.2
NETWORK: onprem-vpc
cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ #!/bin/bash

╔═══════════════════════════════════════════════════════════════╗
║   VMware to GCP Hybrid Connectivity - Verification (Fixed)    ║
╚═══════════════════════════════════════════════════════════════╝

============================================================
1. CONTEXT
============================================================

  Project: playground-s-11-103aa1c1
  Region:  us-central1
  Zone:    us-central1-a

------------------------------------------------------------
Active gcloud context
------------------------------------------------------------

account: cloud_user_p_0593b17d@linuxacademygclabs.com
project: playground-s-11-103aa1c1

============================================================
2. VPC NETWORKS
============================================================

------------------------------------------------------------
Networks
------------------------------------------------------------
NAME: cloud-vpc
SUBNET_MODE: 
BGP_ROUTING: 
AUTO_CREATE_SUBNETWORKS: False

NAME: onprem-vpc
SUBNET_MODE: 
BGP_ROUTING: 
AUTO_CREATE_SUBNETWORKS: False

✓ VPC count OK (2/2)

============================================================
3. SUBNETS
============================================================

------------------------------------------------------------
Subnets in region us-central1
------------------------------------------------------------
NAME: cloud-subnet
NETWORK: cloud-vpc
REGION: us-central1
IP_RANGE: 10.1.0.0/24

NAME: onprem-subnet
NETWORK: onprem-vpc
REGION: us-central1
IP_RANGE: 10.2.0.0/24

✓ Subnet count OK (2/2)
------------------------------------------------------------
CIDR verification
------------------------------------------------------------
  Cloud subnet CIDR:  10.1.0.0/24 (expected 10.1.0.0/24)
  OnPrem subnet CIDR: 10.2.0.0/24 (expected 10.2.0.0/24)

============================================================
4. CLOUD ROUTERS
============================================================

------------------------------------------------------------
Routers in region us-central1
------------------------------------------------------------
NAME: cloud-router
NETWORK: cloud-vpc
REGION: us-central1
ASN: 65001

NAME: onprem-router
NETWORK: onprem-vpc
REGION: us-central1
ASN: 65002

✓ Router count OK (2/2)
------------------------------------------------------------
ASN verification
------------------------------------------------------------
  Cloud ASN:  65001 (expected 65001)
  OnPrem ASN: 65002 (expected 65002)

============================================================
5. HA VPN GATEWAYS
============================================================

------------------------------------------------------------
VPN gateways in region us-central1
------------------------------------------------------------
NAME: cloud-vpn-gw
NETWORK: cloud-vpc
REGION: us-central1
IF0_IP: 34.128.33.39
IF1_IP: 34.157.228.242

NAME: onprem-vpn-gw
NETWORK: onprem-vpc
REGION: us-central1
IF0_IP: 35.242.125.9
IF1_IP: 34.157.224.81

✓ VPN gateway count OK (2/2)

============================================================
6. VPN TUNNELS
============================================================

------------------------------------------------------------
Tunnel list (region filtered)
------------------------------------------------------------
NAME: tunnel-1
REGION: us-central1
GATEWAY: cloud-vpn-gw
PEER_GW: onprem-vpn-gw
STATUS: ESTABLISHED

NAME: tunnel-2
REGION: us-central1
GATEWAY: cloud-vpn-gw
PEER_GW: onprem-vpn-gw
STATUS: ESTABLISHED

NAME: tunnel-3
REGION: us-central1
GATEWAY: onprem-vpn-gw
PEER_GW: cloud-vpn-gw
STATUS: ESTABLISHED

NAME: tunnel-4
REGION: us-central1
GATEWAY: onprem-vpn-gw
PEER_GW: cloud-vpn-gw
STATUS: ESTABLISHED

  Total tunnels:       4 (expected 4)
  Established tunnels: 4 (expected 4)
✓ All present tunnels are ESTABLISHED (4/4)

============================================================
7. BGP SESSIONS
============================================================

------------------------------------------------------------
Cloud router peer status
------------------------------------------------------------
PEER: ['bgp-peer-tunnel-1', 'bgp-peer-tunnel-2']
STATUS: ['UP', 'UP']
STATE: ['Established', 'Established']
PEER_IP: ['169.254.1.2', '169.254.2.2']
UPTIME: ['16 minutes, 13 seconds', '2 hours, 44 minutes, 31 seconds']

------------------------------------------------------------
OnPrem router peer status
------------------------------------------------------------
PEER: ['bgp-peer-tunnel-3', 'bgp-peer-tunnel-4']
STATUS: ['UP', 'UP']
STATE: ['Established', 'Established']
PEER_IP: ['169.254.1.1', '169.254.2.1']
UPTIME: ['16 minutes, 16 seconds', '2 hours, 44 minutes, 34 seconds']

cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ #!/bin/bash
###############################################################################
# VMware to GCP Hybrid Connectivity - Production Verification Script
# Author: Gregory B. Horne
# Purpose: Validate full HA VPN + BGP hybrid architecture
###############################################################################

set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; }

# Defaults (override with export if needed)
PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"

CLOUD_ROUTER="cloud-router"
ONPREM_ROUTER="onprem-router"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   VMware to GCP Hybrid Connectivity - Verification            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

###############################################################################
# 1. CONTEXT
###############################################################################

echo "Project: $PROJECT_ID"
echo "Region : $REGION"
echo "Zone   : $ZONE"
echo ""

###############################################################################
# 2. VPN TUNNELS
###############################################################################

echo "============================================================"
echo "VPN TUNNEL STATUS"
echo "============================================================"

TUNNELS=$(gcloud compute vpn-tunnels list \
  --project="$PROJECT_ID" \
  --filter="region:$REGION" \
  --format="value(name,status)" 2>/dev/null)
cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ #!/bin/bash
###############################################################################

╔═══════════════════════════════════════════════════════════════╗
║   VMware to GCP Hybrid Connectivity - Enterprise Validation   ║
╚═══════════════════════════════════════════════════════════════╝

============================================================
PROJECT CONTEXT
============================================================
Project: playground-s-11-103aa1c1
Region : us-central1
Zone   : us-central1-a

============================================================
REQUIRED APIs
============================================================
cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ #!/bin/bash
###############################################################################
# VMware to GCP Hybrid Connectivity - Clean Enterprise Verification
###############################################################################

set -u

PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"

CLOUD_ROUTER="cloud-router"
ONPREM_ROUTER="onprem-router"

EXPECTED_CLOUD_ROUTE="10.1.0.0/24"
EXPECTED_ONPREM_ROUTE="10.2.0.0/24"

echo ""
echo "============================================================"
echo "HYBRID CONNECTIVITY VALIDATION"
echo "============================================================"
echo "Project: $PROJECT_ID"
echo "Region : $REGION"
echo "Zone   : $ZONE"
echo ""

###############################################################################
# 1. VPN TUNNEL VALIDATION
###############################################################################

TUNNEL_OUTPUT=$(gcloud compute vpn-tunnels list \
  --project="$PROJECT_ID" \
  --filter="region:$REGION" \
  --format="value(status)" 2>/dev/null)

TOTAL_TUNNELS=$(echo "$TUNNEL_OUTPUT" | wc -l | tr -d ' ')
ESTABLISHED_TUNNELS=$(echo "$TUNNEL_OUTPUT" | grep -c "^ESTABLISHED$" || echo "0")

echo "VPN Tunnels        : $ESTABLISHED_TUNNELS/$TOTAL_TUNNELS"

###############################################################################
# 2. BGP SESSION VALIDATION
###############################################################################

count_bgp_up() {
  gcloud compute routers get-status "$1" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="value(result.bgpPeerStatus[].status)" 2>/dev/null \
    | tr ';' '\n' \
    | tr -d "[]'," \
    | grep -c "^UP$" || echo "0"
}

CLOUD_BGP_UP=$(count_bgp_up "$CLOUD_ROUTER")
ONPREM_BGP_UP=$(count_bgp_up "$ONPREM_ROUTER")
TOTAL_BGP_UP=$((CLOUD_BGP_UP + ONPREM_BGP_UP))

TOTAL_BGP_EXPECTED=4

echo "BGP Sessions UP    : $TOTAL_BGP_UP/$TOTAL_BGP_EXPECTED"

###############################################################################
# 3. ROUTE LEARNING VALIDATION
###############################################################################

count_route() {
  gcloud compute routers get-status "$1" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="value(result.bestRoutes[].destRange)" 2>/dev/null \
    | tr ';' '\n' \
    | tr -d "[]'," \
    | grep -c "$2" || echo "0"
}

CLOUD_LEARN=$(count_route "$CLOUD_ROUTER" "$EXPECTED_ONPREM_ROUTE")
ONPREM_LEARN=$(count_route "$ONPREM_ROUTER" "$EXPECTED_CLOUD_ROUTE")

echo """✗ Hybrid connectivity NOT fully compliant"SE HA READY"===="############

============================================================
HYBRID CONNECTIVITY VALIDATION
============================================================
Project: playground-s-11-103aa1c1
Region : us-central1
Zone   : us-central1-a

VPN Tunnels        : 4/4

BGP Sessions UP    : 4/4
Cloud Route Learned: ✓
OnPrem Route Learned: ✓

============================================================
FINAL STATUS
============================================================
✓ HYBRID CONNECTIVITY VALIDATED — ENTERPRISE HA READY

cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ 
cloud_user_p_0593b17d@cloudshell:~ (playground-s-11-103aa1c1)$ 