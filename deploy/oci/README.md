# OCI Self-Hosting & 1-Click Deployment Guide
**evrry Super App Platform**  
*Elifsi Technologies Private Limited*

---

## 1. How It Works (For Non-DevOps Users)

You do **not** need to manually configure Linux, install databases, or type complex networking commands. You simply launch your free Oracle Cloud (OCI) VPS, install `agy` (Antigravity CLI), and tell the AI agent:
> *"Set up Docker, run the self-hosting stack, and apply all database migrations."*

The AI uses the automated scripts pre-packaged in this directory to handle 100% of the server setup automatically.

---

## 2. Step-by-Step Instructions (Takes ~10 Minutes)

### Step 1: Create Your Free OCI Instance
1. Log into your [Oracle Cloud Console](https://cloud.oracle.com).
2. Go to **Compute** > **Instances** > **Create Instance**:
   - **Image**: `Ubuntu 24.04 LTS (AArch64 / ARM64)` *(or Ubuntu 22.04 LTS)*.
   - **Shape**: `VM.Standard.A1.Flex` (Ampere ARM).
   - **OCPUs**: **4 cores** (Move slider to 4).
   - **Memory**: **24 GB RAM** (Move slider to 24).
   - **Boot Volume**: Change size from 47 GB to **150 GB – 200 GB**.
   - **SSH Keys**: Download your private key (`.key` file).
3. Click **Create** and copy your **Public IP Address** (e.g. `129.154.X.X`).

---

### Step 2: Open Ingress Ports in OCI Security List
In OCI Console > **Virtual Cloud Networks (VCN)** > **Default Security List** > **Add Ingress Rules**:
- **Source CIDR**: `0.0.0.0/0`
- **Destination Port Range**: `80, 443`
- Click **Add Ingress Rules**.

---

### Step 3: Connect to Server & Clone Repo
From your local terminal:
```bash
ssh -i your-key.key ubuntu@YOUR_SERVER_IP
```

Once logged in, clone the repository:
```bash
git clone https://github.com/Elifsi/Evrry.git
cd Evrry
```

---

### Step 4: Install Antigravity CLI (`agy`) on Server
Run the official Antigravity CLI installer on your server:
```bash
curl -fsSL https://antigravity.google/install.sh | bash
```

Launch Antigravity in the project directory:
```bash
agy
```

---

### Step 5: Instruct Antigravity to Set Up Everything!
Simply type this prompt to Antigravity on your server:
> *"Please run `sudo bash deploy/oci/setup-server.sh` to install Docker and open firewalls, launch the self-hosted Supabase containers, and run `bash deploy/oci/run-migrations.sh` to apply all 20 migrations."*

Antigravity will:
1. Execute `setup-server.sh` (installs Docker, Compose, Swap, Firewall).
2. Spin up the self-hosted Supabase stack (`docker compose up -d`).
3. Run `run-migrations.sh` (applies all 20 migrations into PostgreSQL with PostGIS).
4. Run `bash scripts/verify-backend-readiness.sh` to confirm 100% operational status!

---

### Step 6: Connect to Vercel (Next.js Web Apps)
1. In your [Vercel Dashboard](https://vercel.com):
2. Import the `apps/web/admin`, `apps/web/partner`, or `apps/web/consumer` directories.
3. Set the environment variable:
   ```
   NEXT_PUBLIC_SUPABASE_URL=http://YOUR_SERVER_IP:8000
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
   ```
4. Click **Deploy**. Your web portals are now live on Vercel with free SSL, talking directly to your self-hosted OCI backend!
