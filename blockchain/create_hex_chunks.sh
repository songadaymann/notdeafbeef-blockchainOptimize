#!/bin/bash
# NotDeafBeef Hex Chunk Creator
# =============================
# Converts UTF-8 bundle files to hex-encoded chunks ready for blockchain deployment

set -e

echo "🔧 Creating hex-encoded chunks for blockchain deployment..."
echo ""

# Clean up any existing hex files
rm -f *.hex
rm -f deployment_chunks/

mkdir -p deployment_chunks

# Get all chunk files in logical order
CHUNKS=(
    "bundle_0_core.txt"
    "bundle_1_generator_chunk01.txt"
    "bundle_1_generator_chunk02.txt" 
    "bundle_2_fm_voice.txt"
    "bundle_3_visual_core_chunk01.txt"
    "bundle_3_visual_core_chunk02.txt"
    "bundle_3_visual_core_chunk03.txt"
    "bundle_4_terrain_chunk01.txt"
    "bundle_4_terrain_chunk02.txt"
    "bundle_5_bass_hits_chunk01.txt"
    "bundle_5_bass_hits_chunk02.txt"
    "bundle_5_bass_hits_chunk03.txt"
    "bundle_6_c_bridge_chunk01.txt"
    "bundle_6_c_bridge_chunk02.txt" 
    "bundle_6_c_bridge_chunk03.txt"
)

echo "📦 Processing chunks in deployment order:"
echo ""

TOTAL_SIZE=0
CHUNK_INDEX=0

for chunk_file in "${CHUNKS[@]}"; do
    if [[ -f "blockchain/$chunk_file" ]]; then
        # Get file size
        size=$(wc -c < "blockchain/$chunk_file" | tr -d ' ')
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        
        # Create hex version
        hex_file="deployment_chunks/chunk_$(printf "%02d" $CHUNK_INDEX)_${chunk_file%.txt}.hex"
        
        # Convert to hex with 0x prefix
        echo -n "0x" > "$hex_file"
        xxd -p -c 0 "blockchain/$chunk_file" >> "$hex_file"
        
        # Get hex size 
        hex_size=$(wc -c < "$hex_file" | tr -d ' ')
        
        printf "%2d. %-35s %6s bytes → %6s hex\n" $CHUNK_INDEX "$chunk_file" "$(printf "%'d" $size)" "$(printf "%'d" $hex_size)"
        
        CHUNK_INDEX=$((CHUNK_INDEX + 1))
    else
        echo "⚠️  Missing: $chunk_file"
    fi
done

echo ""
echo "📊 Summary:"
echo "   Total chunks: $CHUNK_INDEX"
echo "   Total source: $(printf "%'d" $TOTAL_SIZE) bytes"
echo "   Ready for deployment: deployment_chunks/"
echo ""

# Create deployment script
cat > deployment_chunks/DEPLOY_INSTRUCTIONS.md << 'EOF'
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
EOF

echo "📖 Created deployment_chunks/DEPLOY_INSTRUCTIONS.md"
echo ""
echo "🚀 Ready for blockchain deployment!"
echo "   1. Deploy NotDeafbeef721 contract"  
echo "   2. Send $CHUNK_INDEX transactions with chunk data"
echo "   3. Register transaction hashes in contract"
echo "   4. Open public minting (512 free mints)"
