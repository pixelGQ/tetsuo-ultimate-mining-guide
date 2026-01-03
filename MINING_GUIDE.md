# TETSUO Solo Mining Guide

Complete guide for setting up solo mining on TETSUO blockchain with ASIC hardware.

## Table of Contents

1. [Introduction](#1-introduction)
2. [Requirements](#2-requirements)
3. [Installing TETSUO Node](#3-installing-tetsuo-node)
4. [Installing ckpool](#4-installing-ckpool)
5. [Network Configuration](#5-network-configuration)
6. [Connecting ASIC Miners](#6-connecting-asic-miners)
7. [GPU Mining](#7-gpu-mining)
8. [MiningRigRentals Integration](#8-miningrigrentals-integration)
9. [Difficulty Configuration](#9-difficulty-configuration)
10. [Monitoring](#10-monitoring)
11. [Security](#11-security)
12. [Backup & Recovery](#12-backup--recovery)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Introduction

### What is TETSUO?

TETSUO is a SHA-256 based blockchain forked from Bitcoin, optimized for fast block times and merge-mining capabilities.

| Parameter | Value |
|-----------|-------|
| Algorithm | SHA-256 |
| Block Time | 60 seconds |
| Block Reward | 10,000 TETSUO |
| Halving | None (infinite supply) |
| Difficulty Adjustment | Every 1440 blocks (~24h) |
| P2P Port | 8338 |
| RPC Port | 8337 |
| Stratum Port | 3333 |
| Address Prefix | T |

### Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ ASIC Miner  │────▶│   ckpool    │────▶│ TETSUO Node │
│ (SHA-256)   │     │ (stratum)   │     │  (tetsuod)  │
└─────────────┘     └─────────────┘     └─────────────┘
    :3333              :3333               :8337 (RPC)
                                           :8338 (P2P)
```

- **ASIC Miner**: Your mining hardware (Antminer S19, S21, etc.)
- **ckpool**: Stratum server that translates pool protocol to RPC calls
- **TETSUO Node**: Full blockchain node that validates and submits blocks

### What You'll Need to Download

| Component | Repository | Purpose |
|-----------|------------|---------|
| **TETSUO Node** | [github.com/Pavelevich/tetsuonode](https://github.com/Pavelevich/tetsuonode) | Node with install scripts |
| **TETSUO Core** (fallback) | [github.com/Pavelevich/fullchain](https://github.com/Pavelevich/fullchain) | Source code if scripts fail |
| **ckpool** | [bitbucket.org/ckolivas/ckpool](https://bitbucket.org/ckolivas/ckpool) | Stratum mining server |
| **GPU Miner** (optional) | [github.com/7etsuo/tetsuo-gpu-miner](https://github.com/7etsuo/tetsuo-gpu-miner) | CUDA miner for NVIDIA GPUs |

**After installation, you'll have:**

| Binary | Location | Purpose |
|--------|----------|---------|
| `tetsuod` | `~/tetsuo-fullchain/tetsuo-core/build/bin/` | Node daemon |
| `tetsuo-cli` | `~/tetsuo-fullchain/tetsuo-core/build/bin/` | Wallet & RPC commands |
| `ckpool` | `~/ckpool/src/` | Stratum server |

**Configuration files:**

| File | Purpose |
|------|---------|
| `~/.tetsuo/tetsuo.conf` | Node settings (RPC, ports) |
| `~/ckpool/tetsuo.conf` | Pool settings (wallet, difficulty) |

---

## 2. Requirements

### Hardware

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 vCPU | 4+ vCPU |
| RAM | 4 GB | 8+ GB |
| Storage | 50 GB SSD | 100+ GB SSD |
| Network | 10 Mbps | 100+ Mbps |

### Operating System

- Ubuntu 22.04 LTS (recommended)
- Ubuntu 24.04 LTS
- Debian 12

### Network

You need ONE of the following:
- **Public IP** (white IP) with port forwarding capability
- **VPS** for SSH tunnel (if behind NAT/gray IP)
- **WSL** on Windows with port forwarding (for development)

---

## 3. Installing TETSUO Node

Choose one of two methods:

### Method 1: Automatic Installation (Recommended)

Use the official install script from [tetsuonode](https://github.com/Pavelevich/tetsuonode):

```bash
# One-command install
curl -fsSL https://raw.githubusercontent.com/Pavelevich/tetsuonode/main/scripts/install-linux.sh | bash
```

The script will:
- Install all dependencies
- Clone and build TETSUO Core
- Set up the data directory

**After completion, verify:**
```bash
ls ~/tetsuo-fullchain/tetsuo-core/build/bin/
# Should show: tetsuod, tetsuo-cli
```

> **Known Issue:** Some users report that `tetsuo-core` directory is missing after running the script. If you don't see the binaries above, use Method 2.

---

### Method 2: Manual Installation (Fallback)

If the automatic script didn't work, install manually:

**Step 1: Install dependencies**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y build-essential cmake pkgconf python3 \
    libssl-dev libboost-all-dev libevent-dev libsqlite3-dev \
    git automake libtool
```

**Step 2: Clone and build**
```bash
cd ~
git clone https://github.com/Pavelevich/fullchain.git
cd fullchain/tetsuo-core

# Build (use -j2 if low on RAM)
cmake -B build -DENABLE_IPC=OFF -DWITH_ZMQ=OFF
cmake --build build -j$(nproc)
```

**Step 3: Verify binaries**
```bash
ls -la ~/fullchain/tetsuo-core/build/bin/
# Should show: tetsuod, tetsuo-cli, tetsuo-qt (optional)
```

> **Note:** If using Method 2, your binaries are in `~/fullchain/tetsuo-core/build/bin/` instead of `~/tetsuo-fullchain/tetsuo-core/build/bin/`. Adjust paths in subsequent commands accordingly.

### 3.3 Configure Node

```bash
# Create data directory
mkdir -p ~/.tetsuo

# Create configuration
cat > ~/.tetsuo/tetsuo.conf << 'EOF'
# Network
server=1
daemon=1
listen=1
txindex=1

# RPC (for ckpool)
rpcuser=ckpool
rpcpassword=YOUR_STRONG_PASSWORD_HERE
rpcport=8337
rpcallowip=127.0.0.1
rpcbind=127.0.0.1

# P2P
port=8338

# Logging
debug=0
printtoconsole=0
EOF
```

**Important**: Replace `YOUR_STRONG_PASSWORD_HERE` with a strong password. Generate one with:
```bash
openssl rand -base64 32
```

### 3.4 Start Node

```bash
# Start daemon
cd ~/fullchain/tetsuo-core
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# Check status (wait for sync)
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getblockchaininfo
```

The node will sync with the network. This may take several hours depending on your connection.

### 3.5 Create Wallet

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Create wallet
$CLI createwallet "mining_wallet"

# Generate address for mining rewards
$CLI -rpcwallet=mining_wallet getnewaddress

# Save this address! Example: TApuot7dtebq7stqSrE3mo84ymKbgcC17s
```

---

## 4. Installing ckpool

ckpool is a high-performance stratum mining pool server.

### 4.1 Clone and Build

```bash
cd ~
git clone https://bitbucket.org/ckolivas/ckpool.git
cd ckpool

# Build
./autogen.sh
./configure
make -j$(nproc)

# Verify
ls -la src/ckpool
```

### 4.2 Configure ckpool

Create configuration file:

```bash
cat > ~/ckpool/tetsuo.conf << 'EOF'
{
"btcd" : [
    {
        "url" : "127.0.0.1:8337",
        "auth" : "ckpool",
        "pass" : "YOUR_STRONG_PASSWORD_HERE",
        "notify" : true
    }
],
"btcaddress" : "YOUR_TETSUO_ADDRESS_HERE",
"btcsig" : "/TETSUO Solo Miner/",
"serverurl" : [
    "0.0.0.0:3333"
],
"mindiff" : 50000,
"startdiff" : 100000,
"maxdiff" : 5000000,
"logdir" : "/home/YOUR_USERNAME/ckpool/logs"
}
EOF
```

**Replace:**
- `YOUR_STRONG_PASSWORD_HERE` - same password as in tetsuo.conf
- `YOUR_TETSUO_ADDRESS_HERE` - your mining wallet address
- `YOUR_USERNAME` - your Linux username

### 4.3 Create Log Directory

```bash
mkdir -p ~/ckpool/logs
```

### 4.4 Start ckpool

```bash
cd ~/ckpool
./src/ckpool -c tetsuo.conf
```

For background operation, use tmux:
```bash
tmux new -s ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf
# Press Ctrl+B, then D to detach
# Use: tmux attach -t ckpool to reconnect
```

---

## 5. Network Configuration

Choose your scenario:

### 5.1 Public IP (White IP)

If you have a public IP address:

**Step 1: Configure Router**
- Forward external port 3333 to your server's internal IP:3333
- Protocol: TCP

**Step 2: Verify**
```bash
# From another machine or use online port checker
nc -zv YOUR_PUBLIC_IP 3333
```

**Step 3: Configure Miners**
```
Pool URL: stratum+tcp://YOUR_PUBLIC_IP:3333
Worker: YOUR_TETSUO_ADDRESS
Password: x
```

### 5.2 SSH Tunnel (Gray IP / Behind NAT)

If you don't have a public IP, use a VPS as proxy.

**Step 1: Rent a VPS**
- Any cheap VPS with public IP (DigitalOcean, Vultr, Hetzner)
- Ubuntu 22.04, 1 vCPU, 1GB RAM is enough

**Step 2: Configure VPS**

SSH to your VPS and enable GatewayPorts:
```bash
sudo nano /etc/ssh/sshd_config
# Add or modify:
GatewayPorts yes

sudo systemctl restart sshd
```

**Step 3: Create Tunnel (from your mining server)**

```bash
# Install sshpass (optional, for password auth)
sudo apt install sshpass

# Create tunnel
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 \
    -fN -R 0.0.0.0:3333:localhost:3333 user@VPS_IP
```

**Step 4: Automate with autossh**

```bash
sudo apt install autossh

# Create systemd service
sudo cat > /etc/systemd/system/tetsuo-tunnel.service << 'EOF'
[Unit]
Description=TETSUO Stratum Tunnel
After=network.target

[Service]
User=YOUR_USERNAME
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" -o "StrictHostKeyChecking=no" -N -R 0.0.0.0:3333:localhost:3333 user@VPS_IP
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable tetsuo-tunnel
sudo systemctl start tetsuo-tunnel
```

**Step 5: Configure Miners**
```
Pool URL: stratum+tcp://VPS_IP:3333
Worker: YOUR_TETSUO_ADDRESS
Password: x
```

### 5.3 WSL (Windows Subsystem for Linux)

If running on Windows with WSL:

**Step 1: Get WSL IP**
```bash
# In WSL terminal
hostname -I
# Example: 172.26.50.209
```

**Step 2: Configure Windows Port Forwarding**

Open PowerShell as Administrator:
```powershell
# Add port forwarding rule
netsh interface portproxy add v4tov4 listenport=3333 listenaddress=0.0.0.0 connectport=3333 connectaddress=WSL_IP

# Add firewall rule
netsh advfirewall firewall add rule name="TETSUO Stratum" dir=in action=allow protocol=tcp localport=3333

# Verify
netsh interface portproxy show all
```

**Step 3: Configure Router**
- Forward external port 3333 to Windows PC IP:3333

**Note**: WSL IP may change after reboot. You'll need to update the portproxy rule.

---

## 6. Connecting ASIC Miners

### Connection Format

| Field | Value |
|-------|-------|
| Pool URL | `stratum+tcp://YOUR_IP:3333` |
| Worker | Your TETSUO address (e.g., `TApuot7...`) or any name |
| Password | `x` (anything works) |

### Tested Hardware

| Miner | Algorithm | Works |
|-------|-----------|-------|
| Antminer S19 | SHA-256 | Yes |
| Antminer S19 Pro | SHA-256 | Yes |
| Antminer S21 | SHA-256 | Yes |
| Whatsminer M30S | SHA-256 | Yes |
| Any SHA-256 ASIC | SHA-256 | Yes |

### Connection Example (Antminer)

1. Access miner web interface (usually `http://MINER_IP`)
2. Go to Miner Configuration
3. Add pool:
   - URL: `stratum+tcp://YOUR_PUBLIC_IP:3333`
   - Worker: `TApuot7dtebq7stqSrE3mo84ymKbgcC17s`
   - Password: `x`

---

## 7. GPU Mining

TETSUO supports GPU mining with NVIDIA cards using the official CUDA miner.

### 7.1 Requirements

- **NVIDIA GPU**: Ampere (RTX 30xx), Ada (RTX 40xx), Hopper (H100), Blackwell (B100/B200)
- **CUDA Toolkit**: 12.0 or later
- **OS**: Linux (Ubuntu 22.04+ recommended)

### 7.2 Expected Hashrates

| GPU | Hashrate |
|-----|----------|
| RTX 4090 | ~8 GH/s |
| RTX 4080 | ~6 GH/s |
| RTX 3090 | ~5 GH/s |
| RTX 3080 | ~4 GH/s |

**Note**: GPU mining is significantly slower than ASIC mining. A single Antminer S19 (~100 TH/s) equals ~12,500 RTX 4090 cards.

### 7.3 Installation

```bash
# Install CUDA Toolkit (if not installed)
# See: https://developer.nvidia.com/cuda-downloads

# Clone repository
cd ~
git clone https://github.com/7etsuo/tetsuo-gpu-miner.git
cd tetsuo-gpu-miner

# Build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j$(nproc)

# Verify
ls -la build/tetsuo-miner
```

### 7.4 Configuration

GPU miner connects directly to the TETSUO node (not ckpool).

Ensure your `~/.tetsuo/tetsuo.conf` has:
```ini
server=1
rpcuser=miner
rpcpassword=YOUR_PASSWORD
rpcallowip=127.0.0.1
```

### 7.5 Running the Miner

```bash
./build/tetsuo-miner \
    -a YOUR_TETSUO_ADDRESS \
    -o http://127.0.0.1:8337 \
    -u miner \
    -p YOUR_PASSWORD
```

**Command-line options:**

| Option | Description |
|--------|-------------|
| `-a, --address` | TETSUO address for rewards |
| `-o, --url` | Node RPC URL (default: http://127.0.0.1:8337) |
| `-u, --user` | RPC username |
| `-p, --pass` | RPC password |
| `-d, --device` | GPU device ID (default: all GPUs) |
| `-b, --block-size` | CUDA block size (default: 256) |
| `-v, --verbose` | Verbose output |

### 7.6 Running Multiple GPUs

```bash
# Use all GPUs (default)
./build/tetsuo-miner -a ADDRESS -o URL -u USER -p PASS

# Use specific GPU
./build/tetsuo-miner -a ADDRESS -o URL -u USER -p PASS -d 0

# Run separate instances for each GPU (for monitoring)
./build/tetsuo-miner -a ADDRESS -o URL -u USER -p PASS -d 0 &
./build/tetsuo-miner -a ADDRESS -o URL -u USER -p PASS -d 1 &
```

### 7.7 GPU Mining vs ckpool

| Feature | GPU Miner | ckpool (ASIC) |
|---------|-----------|---------------|
| Connection | Direct to node | Via stratum |
| Protocol | JSON-RPC | Stratum |
| Hardware | NVIDIA GPUs | SHA-256 ASICs |
| Hashrate | GH/s range | TH/s range |

---

## 8. MiningRigRentals Integration

[MiningRigRentals](https://www.miningrigrentals.com) allows you to rent SHA-256 hashpower.

### 8.1 Create Account

1. Register at miningrigrentals.com
2. Deposit funds (BTC, LTC, or other)

### 8.2 Add Your Pool

1. Go to **My Pools** → **Add Pool**
2. Configure:
   - **Name**: TETSUO Solo
   - **Type**: SHA256
   - **Host**: `YOUR_PUBLIC_IP` or `VPS_IP`
   - **Port**: `3333`
   - **Username**: Your TETSUO address
   - **Password**: `x`

3. Test pool connectivity

### 8.3 Rent a Rig

1. Go to **Rigs** → **SHA256**
2. Filter by hashrate and price
3. Check the rig's **Optimal Difficulty** range

**CRITICAL: Difficulty Compatibility**

Each rig has an "Optimal Difficulty" range (e.g., "43k - 258k").

Your ckpool must be configured to support this range:
- `mindiff` should be ≤ rig's minimum optimal
- `startdiff` should be within rig's optimal range

| Rig Hashrate | Optimal Diff | Recommended startdiff |
|--------------|--------------|----------------------|
| 1-15 TH/s | 43k-258k | 50,000 - 100,000 |
| 15-50 TH/s | 100k-500k | 100,000 - 200,000 |
| 50-200 TH/s | 250k-1M | 200,000 - 500,000 |
| 200+ TH/s | 500k-7M | 500,000+ |

### 8.4 Important Notes

- **Network difficulty matters**: If TETSUO network difficulty is lower than rig's minimum optimal difficulty, the rig cannot produce valid shares
- Always check network difficulty before renting high-hashrate rigs:
  ```bash
  ./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getmininginfo
  # Look for "difficulty" field
  ```

---

## 9. Difficulty Configuration

### How Vardiff Works

ckpool uses variable difficulty (vardiff) to adjust share difficulty for each miner:

- **mindiff**: Minimum difficulty (floor)
- **startdiff**: Initial difficulty for new connections
- **maxdiff**: Maximum difficulty (ceiling)

### Configuration Examples

**For small miners (1-50 TH/s):**
```json
"mindiff" : 50000,
"startdiff" : 100000,
"maxdiff" : 1000000
```

**For medium miners (50-200 TH/s):**
```json
"mindiff" : 100000,
"startdiff" : 300000,
"maxdiff" : 3000000
```

**For large miners (200+ TH/s):**
```json
"mindiff" : 500000,
"startdiff" : 500000,
"maxdiff" : 7000000
```

### Calculating Optimal Difficulty

Formula: `difficulty ≈ hashrate × target_share_time / 2^32`

For 1 share per second at 100 TH/s:
```
100 × 10^12 × 1 / 2^32 ≈ 23,283
```

MiningRigRentals recommends ~10-60 seconds per share, so multiply by 10-60.

### Common Issue: "0 Hashrate" on High-Power Rigs

If a high-hashrate rig connects but shows 0 hashrate:

1. Check rig's optimal difficulty range on MRR
2. Check current network difficulty:
   ```bash
   ./build/bin/tetsuo-cli getmininginfo | grep difficulty
   ```
3. If network difficulty < rig's minimum optimal → rig cannot work
4. Solution: Use lower-hashrate rigs or wait for network difficulty to increase

---

## 10. Monitoring

### 10.1 ckpool Logs

```bash
# Live log
tail -f ~/ckpool/logs/ckpool.log

# Search for blocks found
grep "Solved and confirmed block" ~/ckpool/logs/ckpool.log

# Check connected workers
grep "hashrate1m" ~/ckpool/logs/ckpool.log | tail -5
```

### 10.2 Node Status

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Blockchain info
$CLI getblockchaininfo

# Mining info
$CLI getmininginfo

# Network info
$CLI getnetworkinfo

# Wallet balance
$CLI -rpcwallet=mining_wallet getbalance
```

### 10.3 Mining Dashboard

A monitoring dashboard script is included in `scripts/tetsuo-stats.sh`.

**Installation:**
```bash
chmod +x ~/fullchain/scripts/tetsuo-stats.sh
```

**Usage:**
```bash
~/fullchain/scripts/tetsuo-stats.sh [refresh_seconds]
# Default refresh: 5 seconds

# Run with 10 second refresh
~/fullchain/scripts/tetsuo-stats.sh 10
```

**Dashboard shows:**
- Network: height, difficulty, hashrate, peers
- Your mining: hashrate (1m/5m/1hr), network share
- Blocks: found, rejected, acceptance rate
- Estimated time to next block

---

## 11. Security

### 11.1 RPC Security

- **Never expose RPC port (8337) to the internet**
- Use strong, unique password
- Bind RPC only to localhost:
  ```ini
  rpcallowip=127.0.0.1
  rpcbind=127.0.0.1
  ```

### 11.2 Firewall (ufw)

```bash
# Install ufw
sudo apt install ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow ssh

# Allow P2P (for node)
sudo ufw allow 8338/tcp

# Allow Stratum (for miners)
sudo ufw allow 3333/tcp

# DO NOT allow RPC from outside
# sudo ufw allow 8337/tcp  # NEVER DO THIS

# Enable firewall
sudo ufw enable
sudo ufw status
```

### 11.3 SSH Security

```bash
# Generate SSH key (on your local machine)
ssh-keygen -t ed25519 -C "mining-server"

# Copy to server
ssh-copy-id user@server

# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set:
# PasswordAuthentication no
# PermitRootLogin no

sudo systemctl restart sshd
```

### 11.4 VPS Tunnel Security

Only forward the stratum port:
```bash
# Good - only port 3333
ssh -R 0.0.0.0:3333:localhost:3333 user@vps

# Bad - forwarding RPC
# ssh -R 0.0.0.0:8337:localhost:8337 user@vps  # NEVER DO THIS
```

---

## 12. Backup & Recovery

### 12.1 What to Backup

| Item | Path | Priority |
|------|------|----------|
| Wallet | `~/.tetsuo/wallets/` | Critical |
| Node config | `~/.tetsuo/tetsuo.conf` | High |
| Pool config | `~/ckpool/tetsuo.conf` | High |

### 12.2 Wallet Backup

```bash
CLI="./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo"

# Backup to file
$CLI -rpcwallet=mining_wallet backupwallet ~/wallet-backup.dat

# Copy to safe location
scp ~/wallet-backup.dat user@backup-server:~/
```

### 12.3 Encrypt Wallet

```bash
# Encrypt with password
$CLI -rpcwallet=mining_wallet encryptwallet "YOUR_WALLET_PASSWORD"

# After encryption, wallet locks automatically
# Unlock for sending:
$CLI -rpcwallet=mining_wallet walletpassphrase "YOUR_WALLET_PASSWORD" 300
# 300 = seconds to stay unlocked
```

### 12.4 Restore from Backup

```bash
# Stop node
$CLI stop

# Copy backup to wallets directory
cp ~/wallet-backup.dat ~/.tetsuo/wallets/mining_wallet/wallet.dat

# Start node
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# Load wallet
$CLI loadwallet mining_wallet
```

---

## 13. Troubleshooting

### Tunnel Keeps Dropping

**Symptoms**: Miners disconnect, VPS port not listening

**Solution 1**: Use autossh (see Section 5.2)

**Solution 2**: Check for stale processes on VPS
```bash
# On VPS
pkill -f "sshd:.*3333"
ss -tlnp | grep 3333
```

**Solution 3**: Use direct port forwarding if you have public IP (Section 5.1)

### Miners Not Connecting

**Check 1**: Is ckpool running?
```bash
pgrep -a ckpool
```

**Check 2**: Is port open?
```bash
# Local
ss -tlnp | grep 3333

# Remote (from another machine)
nc -zv YOUR_IP 3333
```

**Check 3**: Firewall?
```bash
sudo ufw status
sudo iptables -L -n | grep 3333
```

### 0 Hashrate in Pool

**Symptoms**: Workers connect but show 0 hashrate

**Cause 1**: Wrong difficulty
- Check rig's optimal difficulty on MRR
- Adjust `mindiff` and `startdiff` in ckpool config

**Cause 2**: Network difficulty too low
```bash
./build/bin/tetsuo-cli getmininginfo | grep difficulty
# If < rig's minimum optimal, rig cannot work
```

**Cause 3**: Check ckpool logs
```bash
tail -100 ~/ckpool/logs/ckpool.log | grep -i error
```

### Block Rejected

**Symptoms**: "REJECTED" in ckpool logs

**Cause 1**: Orphan block (another miner found block first)
- This is normal in mining, especially at low hashrate

**Cause 2**: Node not synced
```bash
./build/bin/tetsuo-cli getblockchaininfo
# Check "blocks" vs "headers"
# If blocks < headers, node is still syncing
```

**Cause 3**: Network issues
- Check peer count: `./build/bin/tetsuo-cli getconnectioncount`
- Should have 8+ peers

### Node Won't Start

**Check logs:**
```bash
tail -100 ~/.tetsuo/debug.log
```

**Common issues:**
- Port already in use: change port in config or kill existing process
- Corrupted database: try `-reindex`
- Disk full: free up space

### ckpool Crashes

**Check:**
```bash
# Memory issues
free -h

# Logs
tail -50 ~/ckpool/logs/ckpool.log
```

**Solution**: Restart ckpool
```bash
pkill ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf
```

### High-Power Rig (500+ TH) Shows 0 Hashrate

**Real example**: Rented a 500 TH rig on MiningRigRentals, workers connect but hashrate = 0.

**Cause**: Rig's optimal difficulty (1,164k - 6,985k) is higher than current TETSUO network difficulty (~700k).

**How it works**: The rig physically cannot generate shares with high enough difficulty because the network is still young and difficulty is low.

**Solutions**:
- Rent rigs with lower optimal difficulty (43k-258k works at ~700k network diff)
- Or wait for network difficulty to rise above 1M

**How to check compatibility**:
```bash
# Current network difficulty
./build/bin/tetsuo-cli getmininginfo | grep difficulty

# Compare with rig's "Optimal Difficulty" on MRR
# Network difficulty must be >= rig's minimum optimal
```

### Wrong RPC Port in Config

**Symptoms**: ckpool cannot connect to node

**Common mistake**: Using port 8332 (Bitcoin) instead of 8337 (TETSUO)

**Check configs**:
```bash
# In ~/.tetsuo/tetsuo.conf should be:
rpcport=8337

# In ~/ckpool/tetsuo.conf should be:
"url" : "127.0.0.1:8337"
```

### WSL: IP Changes After Reboot

**Symptoms**: After Windows reboot, miners cannot connect

**Cause**: WSL gets a new IP on every startup

**Solution**: Update portproxy rule in PowerShell (as Administrator):
```powershell
# Delete old rule
netsh interface portproxy delete v4tov4 listenport=3333 listenaddress=0.0.0.0

# Get new WSL IP
wsl hostname -I

# Add new rule with new IP
netsh interface portproxy add v4tov4 listenport=3333 listenaddress=0.0.0.0 connectport=3333 connectaddress=NEW_WSL_IP
```

### Tunnel "Hangs" on VPS

**Symptoms**: Port 3333 on VPS is listening but new connections don't work

**Cause**: Old SSH process hung on VPS

**Solution**:
```bash
# On VPS - kill hung processes
pkill -f "sshd:.*3333"
ss -tlnp | grep 3333 | grep -oP 'pid=\K[0-9]+' | xargs -r kill

# On local machine - recreate tunnel
pkill -f "ssh.*3333"
ssh -fN -R 0.0.0.0:3333:localhost:3333 user@VPS_IP
```

---

## Quick Reference

### Start Everything

```bash
# 1. Start node
cd ~/fullchain/tetsuo-core
./build/bin/tetsuod -datadir=$HOME/.tetsuo

# 2. Start ckpool
cd ~/ckpool && ./src/ckpool -c tetsuo.conf

# 3. (If using tunnel) Start tunnel
ssh -fN -R 0.0.0.0:3333:localhost:3333 user@VPS_IP
```

### Check Status

```bash
# Node
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo getblockchaininfo

# Pool
pgrep -a ckpool
tail -5 ~/ckpool/logs/ckpool.log

# Balance
./build/bin/tetsuo-cli -datadir=$HOME/.tetsuo -rpcwallet=mining_wallet getbalance
```

### Useful Commands

```bash
# View live hashrate
tail -f ~/ckpool/logs/ckpool.log | grep hashrate

# Count found blocks
grep -c "Solved and confirmed block" ~/ckpool/logs/ckpool.log

# Dashboard
~/fullchain/scripts/tetsuo-stats.sh
```

---

## Support

- **GitHub**: https://github.com/Pavelevich/fullchain
- **Explorer**: https://tetsuoarena.com

---

*Happy Mining!*
