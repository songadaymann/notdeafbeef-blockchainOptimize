# NotDeafBeef Blockchain Deployment Instructions
# ==============================================

## Overview
You have 15 hex-encoded chunks ready for blockchain deployment.
Each chunk contains UTF-8 source code that will be stored in Ethereum transaction input data.

## Step 1: Deploy Contract
Deploy the NotDeafbeef721.sol contract first.

## Step 2: Send Transactions  
For each chunk_XX_*.hex file (in order):

```bash
# Example using ethers.js or web3:
# Send 0 ETH transaction with data from hex file

chunk_data=$(cat chunk_00_bundle_0_core.hex)
eth_sendTransaction --to YOUR_ADDRESS --value 0 --data "$chunk_data"
# Record the transaction hash
```

## Step 3: Register Code Locations
After all transactions confirm:

```solidity
// Set total chunk count
contract.setNumCodeLocations(0, 15)

// Register each transaction hash in order
contract.setCodeLocation(0, 0, 0xTX_HASH_CHUNK_00)
contract.setCodeLocation(0, 1, 0xTX_HASH_CHUNK_01)
// ... continue for all 15 chunks
```

## Step 4: Open Minting
```solidity
contract.setPaused(0, false)
contract.setPublicMintEnabled(0, true)
// Now users can call mintPublic(0) for free mints!
```

## Step 5: Lock Forever (Optional)
```solidity
contract.lockCodeForever(0)  // Makes code immutable forever
```

## User Reconstruction Process
1. Call getTokenParams(tokenId) to get seed + series info
2. Get all code chunks from transaction hashes
3. Paste seed into seed.s file  
4. Compile: make generate_frames USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM FM_VOICE_ASM"
5. Generate: ./generate_nft.sh [SEED] ./output

Perfect deafbeef-style on-chain generative art! 🎵✨
