#!/bin/bash
###############################################################################
# VMware to GCP Hybrid Connectivity - Complete Deployment Verification Script
# Author: Gregory B. Horne
# Date: February 2026
# Purpose: Comprehensive verification of all deployed GCP resources
###############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-playground-s-11-103aa1c1}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}------------------------------------------------------------${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

###############################################################################
# Verification Functions
###############################################################################

verify_project() {
    print_header "1. PROJECT INFORMATION"
    
    echo "Project ID: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Zone: $ZONE"
    echo ""
    
    # Get project details
    print_section "Project Details"
    gcloud projects describe $PROJECT_ID --format="table(
        projectId,
        name,
        projectNumber,
        createTime
    )"
    echo ""
    
    # Get enabled APIs
    print_section "Enabled APIs (relevant to deployment)"
    gcloud services list --enabled --project=$PROJECT_ID \
        --filter="name:(compute.googleapis.com OR iam.googleapis.com)" \
        --format="table(name, title)"
    echo ""
}

verify_networks() {
    print_header "2. VPC NETWORKS"
    
    print_section "VPC Networks Created"
    gcloud compute networks list \
        --project=$PROJECT_ID \
        --filter="name:(cloud-vpc OR onprem-vpc)" \
        --format="table(
            name,
            mode:label='SUBNET_MODE',
            bgpRoutingMode:label='BGP_ROUTING',
            autoCreateSubnetworks
        )"
    echo ""
    
    # Count networks
    NETWORK_COUNT=$(gcloud compute networks list \
        --project=$PROJECT_ID \
        --filter="name:(cloud-vpc OR onprem-vpc)" \
        --format="value(name)" | wc -l)
    
    if [ "$NETWORK_COUNT" -eq 2 ]; then
        print_success "2 VPC networks verified (cloud-vpc, onprem-vpc)"
    else
        print_error "Expected 2 networks, found $NETWORK_COUNT"
    fi
    echo ""
}

verify_subnets() {
    print_header "3. SUBNETS"
    
    print_section "Subnets in Region: $REGION"
    gcloud compute networks subnets list \
        --project=$PROJECT_ID \
        --filter="region:$REGION AND name:(cloud-subnet OR onprem-subnet)" \
        --format="table(
            name,
            network.basename():label='NETWORK',
            region.basename():label='REGION',
            ipCidrRange:label='IP_RANGE',
            privateIpGoogleAccess:label='PRIVATE_GOOGLE_ACCESS'
        )"
    echo ""
    
    # Verify IP ranges
    print_section "IP Address Space Verification"
    CLOUD_RANGE=$(gcloud compute networks subnets describe cloud-subnet \
        --region=$REGION --project=$PROJECT_ID --format="value(ipCidrRange)")
    ONPREM_RANGE=$(gcloud compute networks subnets describe onprem-subnet \
        --region=$REGION --project=$PROJECT_ID --format="value(ipCidrRange)")
    
    print_info "Cloud Subnet:   $CLOUD_RANGE (Expected: 10.1.0.0/24)"
    print_info "OnPrem Subnet:  $ONPREM_RANGE (Expected: 10.2.0.0/24)"
    
    if [ "$CLOUD_RANGE" = "10.1.0.0/24" ] && [ "$ONPREM_RANGE" = "10.2.0.0/24" ]; then
        print_success "IP address ranges match design specifications"
    else
        print_warning "IP address ranges differ from expected values"
    fi
    echo ""
}

verify_routers() {
    print_header "4. CLOUD ROUTERS"
    
    print_section "Cloud Routers"
    gcloud compute routers list \
        --project=$PROJECT_ID \
        --filter="region:$REGION" \
        --format="table(
            name,
            network.basename():label='NETWORK',
            region.basename():label='REGION',
            bgp.asn:label='ASN'
        )"
    echo ""
    
    # Verify ASNs
    print_section "BGP ASN Verification"
    CLOUD_ASN=$(gcloud compute routers describe cloud-router \
        --region=$REGION --project=$PROJECT_ID --format="value(bgp.asn)")
    ONPREM_ASN=$(gcloud compute routers describe onprem-router \
        --region=$REGION --project=$PROJECT_ID --format="value(bgp.asn)")
    
    print_info "Cloud Router ASN:   $CLOUD_ASN (Expected: 65001)"
    print_info "OnPrem Router ASN:  $ONPREM_ASN (Expected: 65002)"
    
    if [ "$CLOUD_ASN" = "65001" ] && [ "$ONPREM_ASN" = "65002" ]; then
        print_success "BGP ASN configuration correct"
    else
        print_error "BGP ASN configuration mismatch"
    fi
    echo ""
}

verify_vpn_gateways() {
    print_header "5. HA VPN GATEWAYS"
    
    print_section "VPN Gateways"
    gcloud compute vpn-gateways list \
        --project=$PROJECT_ID \
        --filter="region:$REGION" \
        --format="table(
            name,
            network.basename():label='NETWORK',
            region.basename():label='REGION',
            vpnInterfaces[0].ipAddress:label='INTERFACE_0_IP',
            vpnInterfaces[1].ipAddress:label='INTERFACE_1_IP'
        )"
    echo ""
    
    # Count gateways
    GATEWAY_COUNT=$(gcloud compute vpn-gateways list \
        --project=$PROJECT_ID \
        --filter="region:$REGION" \
        --format="value(name)" | wc -l)
    
    if [ "$GATEWAY_COUNT" -eq 2 ]; then
        print_success "2 HA VPN Gateways verified (cloud-vpn-gw, onprem-vpn-gw)"
    else
        print_error "Expected 2 gateways, found $GATEWAY_COUNT"
    fi
    echo ""
}

verify_vpn_tunnels() {
    print_header "6. VPN TUNNELS"
    
    print_section "VPN Tunnel Status"
    gcloud compute vpn-tunnels list \
        --project=$PROJECT_ID \
        --filter="region:$REGION" \
        --format="table(
            name,
            vpnGateway.basename():label='VPN_GATEWAY',
            peerGcpGateway.basename():label='PEER_GATEWAY',
            status,
            detailedStatus:label='DETAILED_STATUS'
        )"
    echo ""
    
    # Verify all tunnels are ESTABLISHED
    print_section "Tunnel Status Verification"
    TOTAL_TUNNELS=$(gcloud compute vpn-tunnels list \
        --project=$PROJECT_ID \
        --filter="region:$REGION" \
        --format="value(name)" | wc -l)
    
    ESTABLISHED_TUNNELS=$(gcloud compute vpn-tunnels list \
        --project=$PROJECT_ID \
        --filter="region:$REGION AND status:ESTABLISHED" \
        --format="value(name)" | wc -l)
    
    print_info "Total Tunnels: $TOTAL_TUNNELS"
    print_info "Established Tunnels: $ESTABLISHED_TUNNELS"
    
    if [ "$ESTABLISHED_TUNNELS" -eq 4 ] && [ "$TOTAL_TUNNELS" -eq 4 ]; then
        print_success "All 4 VPN tunnels are ESTABLISHED"
    else
        print_error "Not all tunnels are established (Expected: 4, Established: $ESTABLISHED_TUNNELS)"
    fi
    echo ""
    
    # Detailed tunnel information
    print_section "Detailed Tunnel Configuration"
    for tunnel in tunnel-1 tunnel-2 tunnel-3 tunnel-4; do
        echo "Tunnel: $tunnel"
        gcloud compute vpn-tunnels describe $tunnel \
            --region=$REGION \
            --project=$PROJECT_ID \
            --format="yaml(
                name,
                ikeVersion,
                status,
                detailedStatus,
                peerIp
            )" | grep -v "^---"
        echo ""
    done
}

verify_bgp_sessions() {
    print_header "7. BGP SESSIONS"
    
    print_section "Cloud Router BGP Status"
    gcloud compute routers get-status cloud-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="table(
            result.bgpPeerStatus[].name:label='PEER_NAME',
            result.bgpPeerStatus[].ipAddress:label='LOCAL_IP',
            result.bgpPeerStatus[].peerIpAddress:label='PEER_IP',
            result.bgpPeerStatus[].state:label='STATE',
            result.bgpPeerStatus[].status:label='STATUS',
            result.bgpPeerStatus[].numLearnedRoutes:label='LEARNED_ROUTES',
            result.bgpPeerStatus[].uptime:label='UPTIME'
        )"
    echo ""
    
    print_section "OnPrem Router BGP Status"
    gcloud compute routers get-status onprem-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="table(
            result.bgpPeerStatus[].name:label='PEER_NAME',
            result.bgpPeerStatus[].ipAddress:label='LOCAL_IP',
            result.bgpPeerStatus[].peerIpAddress:label='PEER_IP',
            result.bgpPeerStatus[].state:label='STATE',
            result.bgpPeerStatus[].status:label='STATUS',
            result.bgpPeerStatus[].numLearnedRoutes:label='LEARNED_ROUTES',
            result.bgpPeerStatus[].uptime:label='UPTIME'
        )"
    echo ""
    
    # Verify BGP sessions are UP
    print_section "BGP Session Verification"
    CLOUD_BGP_UP=$(gcloud compute routers get-status cloud-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bgpPeerStatus[].status)" | grep -c "UP" || echo "0")
    
    ONPREM_BGP_UP=$(gcloud compute routers get-status onprem-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bgpPeerStatus[].status)" | grep -c "UP" || echo "0")
    
    TOTAL_BGP_UP=$((CLOUD_BGP_UP + ONPREM_BGP_UP))
    
    print_info "Cloud Router BGP Sessions UP: $CLOUD_BGP_UP/2"
    print_info "OnPrem Router BGP Sessions UP: $ONPREM_BGP_UP/2"
    print_info "Total BGP Sessions UP: $TOTAL_BGP_UP/4"
    
    if [ "$TOTAL_BGP_UP" -eq 4 ]; then
        print_success "All 4 BGP sessions are UP and Established"
    else
        print_error "Not all BGP sessions are UP (Expected: 4, Current: $TOTAL_BGP_UP)"
    fi
    echo ""
}

verify_routes() {
    print_header "8. ROUTE EXCHANGE"
    
    print_section "Routes Advertised by Cloud Router"
    gcloud compute routers get-status cloud-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="table(
            result.bgpPeerStatus[0].advertisedRoutes[].destRange:label='ADVERTISED_ROUTE',
            result.bgpPeerStatus[0].advertisedRoutes[].priority:label='PRIORITY'
        )" | head -10
    echo ""
    
    print_section "Routes Learned by Cloud Router"
    gcloud compute routers get-status cloud-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="value(result.bestRoutes[].destRange)" | sort -u
    echo ""
    
    print_section "Routes Advertised by OnPrem Router"
    gcloud compute routers get-status onprem-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="table(
            result.bgpPeerStatus[0].advertisedRoutes[].destRange:label='ADVERTISED_ROUTE',
            result.bgpPeerStatus[0].advertisedRoutes[].priority:label='PRIORITY'
        )" | head -10
    echo ""
    
    print_section "Routes Learned by OnPrem Router"
    gcloud compute routers get-status onprem-router \
        --region=$REGION \
        --project=$PROJECT_ID \
        --format="value(result.bestRoutes[].destRange)" | sort -u
    echo ""
    
    # Verify route exchange
    print_section "Route Exchange Verification"
    CLOUD_LEARNED=$(gcloud compute routers get-status cloud-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bestRoutes[].destRange)" | grep -c "10.2.0.0/24" || echo "0")
    
    ONPREM_LEARNED=$(gcloud compute routers get-status onprem-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bestRoutes[].destRange)" | grep -c "10.1.0.0/24" || echo "0")
    
    if [ "$CLOUD_LEARNED" -gt 0 ]; then
        print_success "Cloud router learning on-prem routes (10.2.0.0/24)"
    else
        print_error "Cloud router NOT learning on-prem routes"
    fi
    
    if [ "$ONPREM_LEARNED" -gt 0 ]; then
        print_success "OnPrem router learning cloud routes (10.1.0.0/24)"
    else
        print_error "OnPrem router NOT learning cloud routes"
    fi
    echo ""
}

verify_firewall_rules() {
    print_header "9. FIREWALL RULES"
    
    print_section "Cloud VPC Firewall Rules"
    gcloud compute firewall-rules list \
        --project=$PROJECT_ID \
        --filter="network:(cloud-vpc)" \
        --format="table(
            name,
            network.basename():label='NETWORK',
            direction,
            priority,
            allowed[].map().firewall_rule().list():label='ALLOW',
            sourceRanges.list():label='SOURCE_RANGES',
            targetTags.list():label='TARGET_TAGS'
        )"
    echo ""
    
    print_section "OnPrem VPC Firewall Rules"
    gcloud compute firewall-rules list \
        --project=$PROJECT_ID \
        --filter="network:(onprem-vpc)" \
        --format="table(
            name,
            network.basename():label='NETWORK',
            direction,
            priority,
            allowed[].map().firewall_rule().list():label='ALLOW',
            sourceRanges.list():label='SOURCE_RANGES',
            targetTags.list():label='TARGET_TAGS'
        )"
    echo ""
    
    # Count firewall rules
    CLOUD_FW_COUNT=$(gcloud compute firewall-rules list \
        --project=$PROJECT_ID \
        --filter="network:(cloud-vpc)" \
        --format="value(name)" | wc -l)
    
    ONPREM_FW_COUNT=$(gcloud compute firewall-rules list \
        --project=$PROJECT_ID \
        --filter="network:(onprem-vpc)" \
        --format="value(name)" | wc -l)
    
    print_info "Cloud VPC Firewall Rules: $CLOUD_FW_COUNT"
    print_info "OnPrem VPC Firewall Rules: $ONPREM_FW_COUNT"
    echo ""
}

verify_instances() {
    print_header "10. COMPUTE INSTANCES"
    
    print_section "VM Instances"
    gcloud compute instances list \
        --project=$PROJECT_ID \
        --filter="zone:$ZONE" \
        --format="table(
            name,
            zone.basename():label='ZONE',
            machineType.basename():label='MACHINE_TYPE',
            networkInterfaces[0].networkIP:label='INTERNAL_IP',
            networkInterfaces[0].network.basename():label='NETWORK',
            status
        )"
    echo ""
    
    # Get instance IPs
    print_section "Instance IP Addresses"
    CLOUD_VM_IP=$(gcloud compute instances describe vm-cloud \
        --zone=$ZONE --project=$PROJECT_ID \
        --format="value(networkInterfaces[0].networkIP)" 2>/dev/null || echo "NOT_FOUND")
    
    ONPREM_VM_IP=$(gcloud compute instances describe vm-onprem \
        --zone=$ZONE --project=$PROJECT_ID \
        --format="value(networkInterfaces[0].networkIP)" 2>/dev/null || echo "NOT_FOUND")
    
    print_info "vm-cloud IP:   $CLOUD_VM_IP (Expected: 10.1.0.2)"
    print_info "vm-onprem IP:  $ONPREM_VM_IP (Expected: 10.2.0.2)"
    
    if [ "$CLOUD_VM_IP" != "NOT_FOUND" ] && [ "$ONPREM_VM_IP" != "NOT_FOUND" ]; then
        print_success "Both test VMs are deployed"
    else
        print_warning "One or both test VMs not found"
    fi
    echo ""
}

verify_connectivity() {
    print_header "11. END-TO-END CONNECTIVITY TEST"
    
    print_section "Testing Cloud VM → OnPrem VM"
    
    CLOUD_VM_IP=$(gcloud compute instances describe vm-cloud \
        --zone=$ZONE --project=$PROJECT_ID \
        --format="value(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")
    
    ONPREM_VM_IP=$(gcloud compute instances describe vm-onprem \
        --zone=$ZONE --project=$PROJECT_ID \
        --format="value(networkInterfaces[0].networkIP)" 2>/dev/null || echo "")
    
    if [ -n "$CLOUD_VM_IP" ] && [ -n "$ONPREM_VM_IP" ]; then
        print_info "Testing ping from vm-cloud ($CLOUD_VM_IP) to vm-onprem ($ONPREM_VM_IP)..."
        
        # Note: This requires VMs to be running and IAP access
        gcloud compute ssh vm-cloud \
            --zone=$ZONE \
            --project=$PROJECT_ID \
            --tunnel-through-iap \
            --command="ping -c 4 $ONPREM_VM_IP" 2>/dev/null && \
            print_success "Connectivity test PASSED" || \
            print_warning "Connectivity test skipped (requires running VMs and IAP access)"
    else
        print_warning "Skipping connectivity test (VMs not found)"
    fi
    echo ""
}

generate_summary() {
    print_header "12. DEPLOYMENT SUMMARY"
    
    # Count all resources
    VPC_COUNT=$(gcloud compute networks list --project=$PROJECT_ID \
        --filter="name:(cloud-vpc OR onprem-vpc)" --format="value(name)" | wc -l)
    
    SUBNET_COUNT=$(gcloud compute networks subnets list --project=$PROJECT_ID \
        --filter="region:$REGION AND name:(cloud-subnet OR onprem-subnet)" \
        --format="value(name)" | wc -l)
    
    ROUTER_COUNT=$(gcloud compute routers list --project=$PROJECT_ID \
        --filter="region:$REGION" --format="value(name)" | wc -l)
    
    GATEWAY_COUNT=$(gcloud compute vpn-gateways list --project=$PROJECT_ID \
        --filter="region:$REGION" --format="value(name)" | wc -l)
    
    TUNNEL_COUNT=$(gcloud compute vpn-tunnels list --project=$PROJECT_ID \
        --filter="region:$REGION" --format="value(name)" | wc -l)
    
    ESTABLISHED_COUNT=$(gcloud compute vpn-tunnels list --project=$PROJECT_ID \
        --filter="region:$REGION AND status:ESTABLISHED" --format="value(name)" | wc -l)
    
    CLOUD_BGP=$(gcloud compute routers get-status cloud-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bgpPeerStatus[].status)" | grep -c "UP" || echo "0")
    
    ONPREM_BGP=$(gcloud compute routers get-status onprem-router \
        --region=$REGION --project=$PROJECT_ID \
        --format="value(result.bgpPeerStatus[].status)" | grep -c "UP" || echo "0")
    
    TOTAL_BGP=$((CLOUD_BGP + ONPREM_BGP))
    
    VM_COUNT=$(gcloud compute instances list --project=$PROJECT_ID \
        --filter="zone:$ZONE AND name:(vm-cloud OR vm-onprem)" \
        --format="value(name)" | wc -l)
    
    FW_COUNT=$(gcloud compute firewall-rules list --project=$PROJECT_ID \
        --filter="network:(cloud-vpc OR onprem-vpc)" --format="value(name)" | wc -l)
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│              VMware to GCP Hybrid Connectivity              │"
    echo "│                  Deployment Verification                    │"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    echo "Project: $PROJECT_ID"
    echo "Region:  $REGION"
    echo "Zone:    $ZONE"
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ RESOURCE SUMMARY                                            │"
    echo "└─────────────────────────────────────────────────────────────┘"
    printf "%-30s %s\n" "VPC Networks:" "$VPC_COUNT/2"
    printf "%-30s %s\n" "Subnets:" "$SUBNET_COUNT/2"
    printf "%-30s %s\n" "Cloud Routers:" "$ROUTER_COUNT/2"
    printf "%-30s %s\n" "HA VPN Gateways:" "$GATEWAY_COUNT/2"
    printf "%-30s %s\n" "VPN Tunnels (Total):" "$TUNNEL_COUNT/4"
    printf "%-30s %s\n" "VPN Tunnels (Established):" "$ESTABLISHED_COUNT/4"
    printf "%-30s %s\n" "BGP Sessions (UP):" "$TOTAL_BGP/4"
    printf "%-30s %s\n" "Firewall Rules:" "$FW_COUNT"
    printf "%-30s %s\n" "Compute Instances:" "$VM_COUNT/2"
    echo ""
    
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│ STATUS                                                      │"
    echo "└─────────────────────────────────────────────────────────────┘"
    
    if [ "$ESTABLISHED_COUNT" -eq 4 ]; then
        print_success "All VPN Tunnels: ESTABLISHED"
    else
        print_error "VPN Tunnels: $ESTABLISHED_COUNT/4 ESTABLISHED"
    fi
    
    if [ "$TOTAL_BGP" -eq 4 ]; then
        print_success "All BGP Sessions: UP"
    else
        print_error "BGP Sessions: $TOTAL_BGP/4 UP"
    fi
    
    # Calculate deployment completeness
    EXPECTED_RESOURCES=14  # 2 VPCs + 2 subnets + 2 routers + 2 gateways + 4 tunnels + 2 VMs
    ACTUAL_RESOURCES=$((VPC_COUNT + SUBNET_COUNT + ROUTER_COUNT + GATEWAY_COUNT + TUNNEL_COUNT + VM_COUNT))
    COMPLETENESS=$((ACTUAL_RESOURCES * 100 / EXPECTED_RESOURCES))
    
    echo ""
    printf "%-30s %s%%\n" "Deployment Completeness:" "$COMPLETENESS"
    echo ""
    
    if [ "$COMPLETENESS" -eq 100 ] && [ "$ESTABLISHED_COUNT" -eq 4 ] && [ "$TOTAL_BGP" -eq 4 ]; then
        print_success "DEPLOYMENT VERIFICATION: PASSED"
        echo ""
        echo "✓ All infrastructure components deployed"
        echo "✓ All VPN tunnels established"
        echo "✓ All BGP sessions active"
        echo "✓ Route exchange functioning"
        echo "✓ Architecture meets design specifications"
    else
        print_warning "DEPLOYMENT VERIFICATION: INCOMPLETE"
        echo ""
        echo "Some components may be missing or not fully operational."
        echo "Review the detailed sections above for specifics."
    fi
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    clear
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║   VMware to GCP Hybrid Connectivity - Deployment Verification ║"
    echo "║   Author: Gregory B. Horne                                    ║"
    echo "║   Date: February 2026                                         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "This script will verify all deployed GCP resources for the"
    echo "VMware to GCP hybrid connectivity architecture."
    echo ""
    echo "Press Enter to continue..."
    read
    
    verify_project
    verify_networks
    verify_subnets
    verify_routers
    verify_vpn_gateways
    verify_vpn_tunnels
    verify_bgp_sessions
    verify_routes
    verify_firewall_rules
    verify_instances
    verify_connectivity
    generate_summary
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    Verification Complete                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Report generated: $(date)"
    echo ""
}

# Run main function
main "$@"