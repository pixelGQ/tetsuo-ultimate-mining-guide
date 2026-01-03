# TETSUO Ultimate Mining Guide

Complete guide for setting up solo mining on TETSUO blockchain.

## Languages

- **[English](MINING_GUIDE.md)** - Full guide in English
- **[Русский](MINING_GUIDE_RU.md)** - Полный гайд на русском

## What's Inside

- Installing TETSUO Node from source
- Setting up ckpool stratum server
- Network configuration (white IP, SSH tunnel, WSL)
- Connecting ASIC miners (SHA-256)
- GPU mining with CUDA
- MiningRigRentals integration
- Difficulty tuning (vardiff)
- Monitoring with dashboard script
- Security best practices
- Backup & recovery
- Troubleshooting real-world issues

## Quick Info

| Parameter | Value |
|-----------|-------|
| Algorithm | SHA-256 |
| Block Time | 60 seconds |
| Block Reward | 10,000 TETSUO |
| P2P Port | 8338 |
| RPC Port | 8337 |
| Stratum Port | 3333 |

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ ASIC/GPU    │────▶│   ckpool    │────▶│ TETSUO Node │
│  Miner      │     │ (stratum)   │     │  (tetsuod)  │
└─────────────┘     └─────────────┘     └─────────────┘
    :3333              :3333               :8337 (RPC)
                                           :8338 (P2P)
```

## Related Projects

- [TETSUO Core](https://github.com/Pavelevich/fullchain) - Node source code
- [GPU Miner](https://github.com/7etsuo/tetsuo-gpu-miner) - CUDA miner
- [Block Explorer](https://tetsuoarena.com) - Live explorer

## License

MIT
