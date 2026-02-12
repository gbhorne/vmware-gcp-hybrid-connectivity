# VMware to GCP Hybrid Connectivity – Deployment Verification

**Author:** Gregory B. Horne  
**Date:** February 2026  
**Network:** `cloud-vpc`

---

## 1. Executive Summary
This document provides the final verification of the deployed Google Cloud Platform (GCP) resources for the VMware-to-GCP hybrid connectivity architecture. All systems have been validated against the design specifications for Enterprise High Availability (HA).



---

## 2. Project Information

| Property | Value |
| :--- | :--- |
| **Project ID** | `playground-s-11-103aa1c1` |
| **Project Number** | `824375663456` |
| **Region** | `us-central1` |
| **Zone** | `us-central1-a` |
| **Create Time** | 2026-02-12T13:22:51.552229Z |

**Enabled APIs:**
* `compute.googleapis.com`

---

## 3. Network Infrastructure

### VPC Networks
* **cloud-vpc**: Custom mode (Auto-create-subnetworks: **False**)
* **onprem-vpc**: Custom mode (Auto-create-subnetworks: **False**)

> **Status:** ✓ 2 VPC networks verified.

### Subnet Configuration
| Subnet Name | Parent Network | Region | IP Range | Status |
| :--- | :--- | :--- | :--- | :--- |
| `cloud-subnet` | `cloud-vpc` | `us-central1` | `10.1.0.0/24` | Verified |
| `onprem-subnet` | `onprem-vpc` | `us-central1` | `10.2.0.0/24` | Verified |

**IP Space Verification:**
* Cloud Subnet: `10.1.0.0/24` (Expected: `10.1.0.0/24`)
* OnPrem Subnet: `10.2.0.0/24` (Expected: `10.2.0.0/24`)

---

## 4. Cloud Routers & BGP Configuration

| Router Name | Network | Region | ASN |
| :--- | :--- | :--- | :--- |
| `cloud-router` | `cloud-vpc` | `us-central1` | `65001` |
| `onprem-router` | `onprem-vpc` | `us-central1` | `65002` |

**BGP Session Status:**
* **Cloud Router:** 2/2 Sessions **UP** (State: Established)
* **OnPrem Router:** 2/2 Sessions **UP** (State: Established)

---

## 5. High Availability (HA) VPN & Tunnels

### Gateways
* `cloud-vpn-gw` (Network: `cloud-vpc`)
* `onprem-vpn-gw` (Network: `onprem-vpc`)

### Tunnel Status
| Tunnel Name | Status |
| :--- | :--- |
| `tunnel-1` | **ESTABLISHED** |
| `tunnel-2` | **ESTABLISHED** |
| `tunnel-3` | **ESTABLISHED** |
| `tunnel-4` | **ESTABLISHED** |

---

## 6. Route Exchange & Security

### Verified Routes
* **Ingress:** Cloud router is learning on-prem routes (`10.2.0.0/24`).
* **Egress:** OnPrem router is learning cloud routes (`10.1.0.0/24`).

### Firewall Rules
The following rules have been verified for internal traffic and management access:
* `cloud-allow-internal`
* `cloud-allow-ssh`
* `onprem-allow-internal`
* `onprem-allow-ssh`

---

## Final Status
> ### **✓ HYBRID CONNECTIVITY VALIDATED — ENTERPRISE HA READY**