# Evrry Self-Hosting, Infrastructure & Hardware Sizing Guide
**evrry Super App Ecosystem**  
*Elifsi Technologies Private Limited*

---

## 1. Executive Summary & Self-Hosting Overview

The **evrry** Super App platform is engineered to be **100% cloud-agnostic and self-hostable**. You can run the entire platform on your own bare-metal servers, a dedicated server (e.g. Hetzner, OVH, Leaseweb), or private cloud VPS instances (DigitalOcean, AWS EC2, Linode, or local Nepali datacenters).

---

## 2. Complete List of Services to Self-Host

The self-hosted architecture consists of 5 modular container stacks managed via Docker Compose or Kubernetes:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             PUBLIC INTERNET                                 │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ HTTPS (Port 443) / WSS
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. REVERSE PROXY & SSL TERMINATION (Nginx / Caddy / Cloudflare)             │
└──────┬───────────────────────┬───────────────────────┬──────────────────────┘
       │                       │                       │
       ▼                       ▼                       ▼
┌──────────────┐       ┌──────────────┐       ┌───────────────────────────────┐
│ 2. KONG API  │       │ 3. NEXT.JS   │       │ 4. PYTHON AI VOICE GATEWAY    │
│    GATEWAY   │       │    WEB APPS  │       │    (FastAPI / WebRTC)         │
│  (Supabase)  │       │ • Admin      │       │ • LiveKit Audio Server        │
└──────┬───────┘       │ • Partner    │       │ • Faster-Whisper ASR          │
       │               │ • Consumer   │       │ • IndicConformer (Nepali)     │
       │               └──────────────┘       │ • Piper-TTS Engine            │
       │                                      └───────────────────────────────┘
       ├─────────────────┬─────────────────┬─────────────────┐
       ▼                 ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  POSTGREST   │  │ GOTRUE AUTH  │  │   REALTIME   │  │ STORAGE API  │
│  (REST API)  │  │ (OTP / JWT)  │  │ (WebSockets) │  │  (S3 Engine) │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │
       └─────────────────┴────────┬────────┴─────────────────┘
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ 5. DATABASE & SPATIAL ENGINE                                                │
│ • PostgreSQL 15+ with PostGIS 3.3+ (Spatial indexes & coordinates)          │
│ • pg_cron (Midnight ConnectIPS settlement & automated maintenance)          │
│ • pgvector & pgcrypto (E2EE Chat & AI Embeddings)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                  │
       ┌──────────────────────────┴──────────────────────────┐
       ▼                                                     ▼
┌──────────────────────────────┐              ┌───────────────────────────────┐
│ 6. REDIS MEMORY STORE        │              │ 7. OSRM ROUTING ENGINE        │
│ • Driver GPS GEOADD Caching  │              │ • Nepal Road Network (.osrm)  │
│ • InDrive Bidding Locks      │              │ • Zero Google Maps API Fees   │
└──────────────────────────────┘              └───────────────────────────────┘
```

### Granular Container Breakdown:

| Service / Container | Technology | Purpose in Evrry |
|---|---|---|
| **PostgreSQL 15+** | PostgreSQL + PostGIS + pg_cron + pgvector | The primary database spine: 20 migrations, double-entry ledger, multi-vertical catalog, PostGIS 4326 geography. |
| **PostgREST** | Haskell / REST Engine | Auto-generates type-safe REST endpoints from PostgreSQL schema protected by Row Level Security (RLS). |
| **GoTrue (Auth)** | Go / Supabase Auth | Manages phone OTP (WhatsApp / SMS), email verification, and cryptographically signed JWT sessions. |
| **Supabase Realtime** | Elixir / Phoenix | WebSockets cluster for real-time driver GPS tracking, instant InDrive negotiation biddings, and chat message delivery. |
| **Supabase Storage API** | Go + MinIO / Local Volume | S3-compatible object storage service handling file uploads, pre-signed URLs, and image resizing. |
| **Deno Edge Functions** | Deno Runtime | Executes the 11 serverless functions (`payment-verify`, `send-otp`, `ai-gateway`, `payout-execute`, etc.). |
| **Kong API Gateway** | OpenResty / Nginx | Central ingress reverse proxy routing traffic to `/rest/v1`, `/auth/v1`, `/storage/v1`, `/functions/v1`. |
| **Supabase Studio** | Next.js / TypeScript | Web admin dashboard for Elifsi engineers to inspect tables, view logs, and monitor database health. |
| **Python Voice Gateway** | FastAPI + LiveKit WebRTC | Low-latency voice broker for the 4 AI personas (Eli, Rony, Jenny, Suka) with Whisper and Piper-TTS. |
| **OSRM Engine** | C++ (Open Source Routing Machine) | Calculates turn-by-turn routes, travel time, and distances across all roads in Nepal with zero per-query fees. |
| **Redis** | Redis 7 | In-memory key-value cache for driver geospatial coordinates (`GEOADD`), rate limiters, and session states. |
| **Next.js Web Suite** | Node.js / Next.js 16 | The 3 web portals: Superadmin (`apps/web/admin`), Partner KDS (`apps/web/partner`), and Consumer Web (`apps/web/consumer`). |

---

## 3. Media & Image Storage Specification (Supabase Storage)

All catalog images, KYC identity scans, user avatars, and vehicle photos are managed by **Supabase Storage**.

### A. Storage Buckets (Pre-configured in Migration 0010)

| Bucket Name | Privacy | Max File Size | Allowed MIME Types | Projected File Count (Launch) |
|---|:---:|:---:|---|---|
| **`catalog`** | **Public** | `5 MB` | `image/jpeg`, `image/png`, `image/webp` | 50,000 photos (menu items, grocery SKUs) |
| **`kyc`** | **Private** | `10 MB` | `image/jpeg`, `image/png`, `image/webp`, `application/pdf` | 20,000 documents (citizenship, driver license, bluebook, PAN) |
| **`avatars`** | **Public** | `2 MB` | `image/jpeg`, `image/png`, `image/webp` | 100,000 consumer & rider avatars |
| **`snaps`** | **Private** | `10 MB` | `image/jpeg`, `image/png`, `image/webp`, `video/mp4` | Ephemeral media (auto-purged every 24h) |
| **`stories`** | **Private** | `20 MB` | `image/jpeg`, `image/png`, `image/webp`, `video/mp4` | Partner/user stories (auto-purged hourly after 24h) |
| **`chat-media`** | **Private** | `20 MB` | Any image, audio note, document | P2P encrypted chat attachments |

### B. Where are Files Stored on the Server?
In a self-hosted deployment, Supabase Storage can save files in two ways:
1. **Local Persistent Docker Volume** (simplest, zero extra cost):
   Files are mounted to the host filesystem at `/var/lib/docker/volumes/supabase_storage_data/_data/`.
2. **S3-Compatible Object Store** (recommended for scale):
   You can either run a local **MinIO** container on the same server, or point Supabase Storage to an external S3-compatible bucket (such as **Cloudflare R2**, which has **$0 egress fees**, or AWS S3 / DigitalOcean Spaces).

### C. Image Optimization & CDN Caching
- **Automatic WebP Conversion**: When merchants upload raw 10 MB smartphone photos of food menus, the client app or storage transformer automatically compresses and converts them to high-efficiency WebP format (~150 KB to 300 KB).
- **Edge Caching**: Placing a free Cloudflare proxy in front of the `catalog` and `avatars` endpoints caches public images globally. Once a user downloads a momo photo, subsequent users load it from the CDN cache without consuming server RAM or bandwidth!

---

## 4. Hardware Sizing & Resource Consumption (RAM, CPU, Disk)

### A. Component-by-Component RAM & CPU Allocation

| Component | Minimum RAM (Idle) | Recommended RAM (Under Load) | vCPU Allocation | Disk I/O Profile |
|---|:---:|:---:|:---:|---|
| **PostgreSQL 15 + PostGIS** | `2.0 GB` | `6.0 GB – 8.0 GB` | 2 – 4 vCPU | Heavy read/write, NVMe SSD required |
| **PostgREST** | `256 MB` | `1.0 GB` | 1 vCPU | High concurrency, CPU-bound JSON serialization |
| **GoTrue (Auth)** | `128 MB` | `512 MB` | 0.5 vCPU | Low footprint, bcrypt hashing |
| **Supabase Realtime** | `256 MB` | `1.5 GB – 2.0 GB` | 1 – 2 vCPU | Memory scales with concurrent WebSocket clients |
| **Supabase Storage API** | `256 MB` | `1.0 GB` | 0.5 – 1 vCPU | Network I/O bound |
| **Kong API Gateway** | `256 MB` | `512 MB – 1.0 GB` | 1 vCPU | Low latency reverse proxy |
| **Deno Edge Functions** | `512 MB` | `1.5 GB – 2.0 GB` | 1 – 2 vCPU | V8 isolates runtime |
| **Supabase Studio** | `256 MB` | `512 MB` | 0.5 vCPU | Internal admin portal |
| **OSRM Engine (Nepal Map)** | `1.2 GB` | `2.0 GB` | 1 vCPU | Map graph loaded into RAM; near-zero CPU |
| **Redis 7** | `128 MB` | `1.0 GB` | 0.5 vCPU | In-memory geospatial indexing |
| **Python Voice Gateway** | `1.0 GB` | `3.0 GB – 4.0 GB` | 2 – 4 vCPU | Speech-to-Text & neural audio streaming |
| **Next.js Web Suite (3 Apps)** | `512 MB` | `1.5 GB` | 1 vCPU | Node.js SSR & static serving |
| **Nginx / OS Overhead** | `512 MB` | `1.0 GB` | 0.5 vCPU | Linux kernel, buffer cache |
| **TOTALS** | **~7.3 GB** | **~21.5 GB – 26.0 GB** | **8 – 16 vCPU** | |

---

### B. Hardware Recommendations by Stage

#### Stage 1: Beta Testing & Initial Launch (0 to 10,000 Users)
A **single high-performance VPS or Dedicated Server** easily runs the entire stack with headroom:

- **CPU**: **8 vCPUs** (AMD EPYC or Intel Xeon)
- **RAM**: **16 GB to 32 GB RAM** *(32 GB is sweet spot for smooth caching)*
- **Storage**: **160 GB – 250 GB NVMe SSD**
- **Bandwidth**: 1 Gbps port (unmetered or 5 TB/month)
- **Estimated Hosting Cost**:
  - **Hetzner Cloud (CPX41)**: 8 vCPU / 16 GB RAM / 240 GB NVMe ≈ **€26 / month (~$28 USD)**
  - **Hetzner Cloud (CPX51)**: 16 vCPU / 32 GB RAM / 360 GB NVMe ≈ **€52 / month (~$56 USD)**
  - **DigitalOcean**: 8 vCPU / 16 GB RAM ≈ **$96 / month**
  - **Local Nepal Datacenter / Cloud** (e.g. DataHub, Genese, AccessWorld): Similar specs.

#### Stage 2: Scale Production (10,000 to 100,000+ Active Users)
Split into 3 specialized servers for maximum fault tolerance:

```
┌────────────────────────────────┐    ┌────────────────────────────────┐
│      SERVER 1: DATABASE        │    │    SERVER 2: APP SERVICES      │
│  • PostgreSQL 15 + PostGIS     │    │  • PostgREST + GoTrue Auth     │
│  • pg_cron + pgvector          │    │  • Supabase Realtime           │
│  • Specs: 8 vCPU / 32 GB RAM   │    │  • Edge Functions + Web Apps   │
│  • Storage: 500 GB NVMe RAID-1 │    │  • Specs: 8 vCPU / 16 GB RAM   │
└────────────────────────────────┘    └────────────────────────────────┘
                 │                                     │
                 └──────────────────┬──────────────────┘
                                    │
                                    ▼
                      ┌────────────────────────────────┐
                      │    SERVER 3: AI & ROUTING      │
                      │  • Python Voice Microservice   │
                      │  • LiveKit Audio Streaming     │
                      │  • OSRM Nepal Road Engine      │
                      │  • Specs: 8 vCPU / 16 GB RAM   │
                      └────────────────────────────────┘
```

---

## 5. Storage Space Growth & Backup Strategy

### A. How Much Storage Will It Consume?
- **Year 1 Projections**:
  - **Database SQL Data**: ~5 GB to 10 GB (millions of orders, ledger rows, coordinates).
  - **Catalog Images** (Food, groceries, hotel rooms): 50,000 images × 250 KB WebP ≈ **12.5 GB**.
  - **Partner KYC Documents** (Protected citizenship, licenses, bluebooks): 10,000 partners × 3 MB ≈ **30 GB**.
  - **User & Driver Avatars**: 100,000 users × 150 KB ≈ **15 GB**.
  - **Chat Media & Logs**: ~20 GB.
  - **Total Year 1 Storage Needed**: **~80 GB to 100 GB NVMe**. A 250 GB drive provides ample headroom for 2+ years of operation.

### B. Automated Backup & Disaster Recovery
A daily automated cron job runs at 02:00 AM:
1. **Database Dump**: `pg_dump -Fc` creates an encrypted, compressed PostgreSQL snapshot (~500 MB).
2. **Storage Volume Sync**: `rclone` incrementally syncs the `/var/lib/storage` folder.
3. **Offsite Upload**: Uploads snapshots to an offsite secure bucket (e.g. Cloudflare R2 / AWS S3 backup) with 30-day retention.
4. **Recovery Time**: In case of server hardware failure, a complete restore from backup takes **under 15 minutes**.
