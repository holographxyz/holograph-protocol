# Holograph Protocol Documentation

Technical documentation for the Holograph omnichain token protocol.

## Documentation Structure

| File | Purpose | Audience |
|------|---------|----------|
| **[../README.md](../README.md)** | Main protocol overview, deployment guide | Developers, integrators |
| **[CREATE_TOKEN.md](CREATE_TOKEN.md)** | TypeScript token creation utility | Developers |
| **[DVN_CONFIGURATION.md](DVN_CONFIGURATION.md)** | LayerZero V2 DVN setup | DevOps, deployers |
| **[OPERATIONS.md](OPERATIONS.md)** | System monitoring and management | Operations teams |
| **[UPGRADE_GUIDE.md](UPGRADE_GUIDE.md)** | Contract upgrade procedures | Protocol maintainers |

## Quick Start

1. **Deploy**: Follow [deployment guide](../README.md#development--deployment)
2. **Configure**: Set up LayerZero DVNs with [DVN_CONFIGURATION.md](DVN_CONFIGURATION.md)  
3. **Operate**: Monitor system using [OPERATIONS.md](OPERATIONS.md)
4. **Integrate**: Create tokens via [CREATE_TOKEN.md](CREATE_TOKEN.md)

## System Overview

**Core Function**: Deploy omnichain ERC20 tokens via Doppler Airlock integration, collect trading fees, bridge to Ethereum for HLG buy/burn/stake distribution.

**Primary Chains**: Base (token deployment) ↔ Ethereum (fee processing)  
**Cross-chain**: LayerZero V2 messaging  
**Fee Model**: 50% protocol (HLG burn/stake), 50% treasury

For detailed architecture and deployment instructions, see the [main README](../README.md).