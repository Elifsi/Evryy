#!/usr/bin/env bash
# =============================================================================
# setup-server.sh — 1-Click OCI Server Provisioner for evrry Super App
# Company: Elifsi Technologies Private Limited
#
# Target OS: Ubuntu 24.04 LTS / 22.04 LTS (AArch64 / ARM64 or x86_64)
# What this script automates:
# 1. System updates & essential build tools
# 2. Docker Engine & Docker Compose Plugin installation
# 3. 4 GB Swap space setup (memory safety buffer)
# 4. OS-level firewall (iptables & UFW) opening ports 22, 80, 443
# 5. Docker log rotation policy (prevents disk space exhaustion)
# =============================================================================

set -e

echo "================================================================="
echo "🚀 INITIALIZING OCI UBUNTU SERVER FOR EVRRY SUPER APP"
echo "================================================================="

# 1. Check Root Privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run with sudo: sudo bash deploy/oci/setup-server.sh"
  exit 1
fi

# 2. Update System Packages
echo "📦 Updating apt package lists..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  git \
  ufw \
  iptables-persistent \
  netfilter-persistent \
  htop \
  jq

# 3. Configure 4 GB Swap Memory (Recommended on Cloud VPS)
if [ ! -f /swapfile ]; then
  echo "💾 Allocating 4 GB Swap space..."
  fallocate -l 4G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=4096
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "  ✅ 4 GB Swap enabled."
else
  echo "  ℹ️ Swap already configured."
fi

# 4. Install Docker Engine & Compose Plugin
if ! command -v docker &> /dev/null; then
  echo "🐳 Installing Docker Engine & Docker Compose..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable docker
  systemctl start docker
  echo "  ✅ Docker installed successfully."
else
  echo "  ℹ️ Docker already installed."
fi

# Add Current Sudo User to Docker Group
REAL_USER=${SUDO_USER:-$USER}
if [ -n "$REAL_USER" ] && [ "$REAL_USER" != "root" ]; then
  usermod -aG docker "$REAL_USER"
  echo "  ✅ User '$REAL_USER' added to docker group."
fi

# 5. Configure Docker Log Rotation (Limit container logs to 10MB to protect disk)
echo "📝 Configuring Docker container log rotation policy..."
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
systemctl restart docker

# 6. Configure OCI Firewall & iptables (Ports 22, 80, 443)
echo "🛡️ Configuring Firewall & Opening Ingress Ports..."
# Unblock OCI default restrictive rules
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j ACCEPT
netfilter-persistent save

echo "================================================================="
echo "✨ SERVER PROVISIONING COMPLETE!"
echo "Docker Version: $(docker --version)"
echo "Compose Version: $(docker compose version)"
echo "Memory Available: $(free -h | grep Mem | awk '{print $2}') RAM + $(free -h | grep Swap | awk '{print $2}') Swap"
echo "================================================================="
echo "👉 Next Step: Run 'bash deploy/oci/run-migrations.sh' once containers are launched!"
