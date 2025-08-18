/**
 * NotDeafbeef Blockchain Deployment Script
 * ========================================
 * Deploys all 15 code chunks to Ethereum as transaction input data.
 * Run this script to upload your complete assembly pipeline to the blockchain.
 */

const { ethers } = require('ethers');
const fs = require('fs');
const path = require('path');

// Configuration - UPDATE THESE
const PRIVATE_KEY = 'YOUR_PRIVATE_KEY_HERE'; // Replace with your private key
const RPC_URL = 'https://mainnet.infura.io/v3/YOUR_PROJECT_ID'; // Replace with your RPC
const CONTRACT_ADDRESS = 'YOUR_DEPLOYED_CONTRACT_ADDRESS'; // Replace after deploying contract

async function deployChunksToBlockchain() {
    console.log('🚀 NotDeafbeef Blockchain Deployment');
    console.log('====================================');
    console.log('');

    // Setup provider and wallet
    const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
    
    console.log(`📡 Connected to network: ${provider.network?.name || 'unknown'}`);
    console.log(`💰 Deploying from: ${wallet.address}`);
    console.log('');

    // Load all hex chunks in order
    const chunkDir = './deployment_chunks';
    const hexFiles = fs.readdirSync(chunkDir)
        .filter(f => f.endsWith('.hex'))
        .sort(); // Natural sort should work for chunk_00, chunk_01, etc.

    console.log(`📦 Found ${hexFiles.length} chunks to deploy`);
    console.log('');

    const transactionHashes = [];
    let totalGasUsed = 0;

    // Deploy each chunk as transaction input data
    for (let i = 0; i < hexFiles.length; i++) {
        const hexFile = hexFiles[i];
        const hexPath = path.join(chunkDir, hexFile);
        
        console.log(`📤 Deploying chunk ${i}: ${hexFile}`);
        
        try {
            // Read hex data (already has 0x prefix)
            const hexData = fs.readFileSync(hexPath, 'utf8').trim();
            const dataSize = (hexData.length - 2) / 2; // Remove 0x and convert to bytes
            
            console.log(`   Size: ${dataSize.toLocaleString()} bytes`);
            
            // Send transaction with chunk data
            const tx = await wallet.sendTransaction({
                to: wallet.address, // Send to self
                value: 0,           // 0 ETH
                data: hexData,      // Our source code
                gasLimit: Math.min(30000000, 21000 + (dataSize * 16)) // Estimate gas
            });
            
            console.log(`   TX: ${tx.hash}`);
            console.log(`   Waiting for confirmation...`);
            
            // Wait for confirmation
            const receipt = await tx.wait();
            totalGasUsed += receipt.gasUsed.toNumber();
            
            console.log(`   ✅ Confirmed in block ${receipt.blockNumber}`);
            console.log(`   Gas used: ${receipt.gasUsed.toLocaleString()}`);
            console.log('');
            
            transactionHashes.push(tx.hash);
            
            // Small delay to avoid nonce issues
            await new Promise(resolve => setTimeout(resolve, 2000));
            
        } catch (error) {
            console.error(`❌ Failed to deploy chunk ${i}: ${error.message}`);
            process.exit(1);
        }
    }

    console.log('🎉 All chunks deployed successfully!');
    console.log('===================================');
    console.log('');
    console.log(`📊 Summary:`);
    console.log(`   Chunks deployed: ${transactionHashes.length}`);
    console.log(`   Total gas used: ${totalGasUsed.toLocaleString()}`);
    console.log('');

    // Generate contract calls
    console.log('📋 Contract Setup Commands:');
    console.log('');
    console.log('// 1. Set number of code locations');
    console.log(`contract.setNumCodeLocations(0, ${transactionHashes.length})`);
    console.log('');
    console.log('// 2. Register each chunk transaction hash');
    
    transactionHashes.forEach((hash, index) => {
        console.log(`contract.setCodeLocation(0, ${index}, "${hash}")`);
    });
    
    console.log('');
    console.log('// 3. Open public minting');  
    console.log('contract.setPaused(0, false)');
    console.log('contract.setPublicMintEnabled(0, true)');
    console.log('');
    console.log('// 4. Lock code forever (optional but recommended)');
    console.log('contract.lockCodeForever(0)');
    console.log('');

    // Save transaction hashes for reference
    const manifestData = {
        deployment_date: new Date().toISOString(),
        total_chunks: transactionHashes.length,
        total_gas_used: totalGasUsed,
        chunks: transactionHashes.map((hash, index) => ({
            index,
            transaction_hash: hash,
            file: hexFiles[index]
        }))
    };

    fs.writeFileSync('deployment_manifest.json', JSON.stringify(manifestData, null, 2));
    console.log('💾 Saved deployment_manifest.json for your records');
    console.log('');
    console.log('🎯 Next Steps:');
    console.log('   1. Copy the contract setup commands above');
    console.log('   2. Execute them on your deployed NotDeafbeef721 contract'); 
    console.log('   3. Your NFT system will be live on-chain!');
}

// Handle command line execution
if (require.main === module) {
    deployChunksToBlockchain().catch(console.error);
}

module.exports = { deployChunksToBlockchain };
