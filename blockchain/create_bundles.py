#!/usr/bin/env python3
"""
NotDeafBeef Blockchain Bundle Creator
=====================================
Organizes ARM64 assembly files into logical bundles for on-chain storage.
Following deafbeef methodology: UTF-8 source code in transaction input data.
"""

import os
from pathlib import Path

# File organization by logical modules
BUNDLE_ORGANIZATION = {
    "bundle_0_core": {
        "description": "Core system: seed + build instructions + small audio voices",
        "files": [
            ("seed.s", "seed.s"),
            ("../src/asm/active/kick.s", "audio/kick.s"),
            ("../src/asm/active/snare.s", "audio/snare.s"), 
            ("../src/asm/active/hat.s", "audio/hat.s"),
            ("../src/asm/active/melody.s", "audio/melody.s"),
            ("../src/asm/active/delay.s", "audio/delay.s"),
            ("../src/asm/active/limiter.s", "audio/limiter.s"),
        ]
    },
    "bundle_1_generator": {
        "description": "Main audio generator (large file)",
        "files": [
            ("../src/asm/active/generator.s", "audio/generator.s"),
        ]
    },
    "bundle_2_fm_voice": {
        "description": "FM synthesis voice (large file)",
        "files": [
            ("../src/asm/active/fm_voice.s", "audio/fm_voice.s"),
        ]
    },
    "bundle_3_visual_core": {
        "description": "Visual foundation: drawing, colors, ASCII rendering",
        "files": [
            ("../src/asm/visual/visual_core.s", "visual/visual_core.s"),
            ("../src/asm/visual/drawing.s", "visual/drawing.s"),
            ("../src/asm/visual/ascii_renderer.s", "visual/ascii_renderer.s"),
            ("../src/asm/visual/particles.s", "visual/particles.s"),
            ("../src/asm/visual/glitch_system.s", "visual/glitch_system.s"),
        ]
    },
    "bundle_4_terrain": {
        "description": "Terrain generation system (large file)",
        "files": [
            ("../src/asm/visual/terrain.s", "visual/terrain.s"),
        ]
    },
    "bundle_5_bass_hits": {
        "description": "Bass hits and shape system (largest file)",
        "files": [
            ("../src/asm/visual/bass_hits.s", "visual/bass_hits.s"),
        ]
    },
    "bundle_6_c_bridge": {
        "description": "C bridge code and build system",
        "files": [
            ("../generate_frames.c", "generate_frames.c"),
            ("../simple_wav_reader.c", "simple_wav_reader.c"),
            ("../generate_nft.sh", "generate_nft.sh"),
            ("../Makefile", "Makefile"),
        ]
    }
}

def read_file_content(file_path):
    """Read file content, handling potential encoding issues."""
    full_path = Path(file_path)
    if not full_path.exists():
        return f"// FILE NOT FOUND: {file_path}\n"
    
    try:
        with open(full_path, 'r', encoding='utf-8') as f:
            return f.read()
    except UnicodeDecodeError:
        # Try binary files as hex dump
        with open(full_path, 'rb') as f:
            content = f.read()
            return f"// BINARY FILE - HEX DUMP:\n// {content.hex()}\n"
    except Exception as e:
        return f"// ERROR READING {file_path}: {e}\n"

def create_bundle(bundle_name, bundle_info):
    """Create a bundle file with proper deafbeef-style formatting."""
    
    content = f"""[NOTDEAFBEEF BLOCKCHAIN BUNDLE - {bundle_name.upper()}]
={'=' * 60}
{bundle_info['description']}
Generated for on-chain storage following deafbeef methodology.

[MANIFEST]
Bundle: {bundle_name}
Total files: {len(bundle_info['files'])}
Files included:
"""
    
    # Add file list to manifest
    for source_path, bundle_path in bundle_info['files']:
        file_size = 0
        if Path(source_path).exists():
            file_size = Path(source_path).stat().st_size
        content += f"  - {bundle_path} ({file_size} bytes)\n"
    
    content += f"\nReconstruction: Save each file to its path and build with provided instructions.\n\n"
    
    # Add each file with clear delimiters
    for source_path, bundle_path in bundle_info['files']:
        content += f"=== FILE: {bundle_path} ===\n"
        content += "---BEGIN---\n"
        content += read_file_content(source_path)
        content += "\n---END---\n\n"
    
    return content

def split_bundle_if_needed(bundle_content, bundle_name, max_size=24000):
    """Split bundle into chunks if it exceeds max_size bytes."""
    content_bytes = bundle_content.encode('utf-8')
    
    if len(content_bytes) <= max_size:
        return [(f"{bundle_name}.txt", bundle_content)]
    
    # Need to split - this is tricky to do cleanly
    # For now, create multiple parts
    chunks = []
    chunk_size = max_size
    
    for i in range(0, len(content_bytes), chunk_size):
        chunk_data = content_bytes[i:i + chunk_size]
        chunk_content = chunk_data.decode('utf-8', errors='ignore')
        
        # Add header to each chunk
        chunk_num = i // chunk_size
        total_chunks = (len(content_bytes) + chunk_size - 1) // chunk_size
        
        header = f"""[CHUNK {chunk_num + 1} OF {total_chunks}]
{bundle_name.upper()} - PART {chunk_num + 1}
Concatenate all chunks in order to reconstruct.

"""
        chunks.append((f"{bundle_name}_chunk{chunk_num + 1:02d}.txt", header + chunk_content))
    
    return chunks

def main():
    """Create all bundles for blockchain deployment."""
    os.makedirs("blockchain", exist_ok=True)
    
    total_chunks = 0
    chunk_manifest = []
    
    print("Creating NotDeafBeef blockchain bundles...")
    
    for bundle_name, bundle_info in BUNDLE_ORGANIZATION.items():
        print(f"\nProcessing {bundle_name}...")
        
        # Create bundle content
        bundle_content = create_bundle(bundle_name, bundle_info)
        
        # Split if needed  
        chunks = split_bundle_if_needed(bundle_content, bundle_name)
        
        for chunk_name, chunk_content in chunks:
            chunk_path = f"blockchain/{chunk_name}"
            
            with open(chunk_path, 'w', encoding='utf-8') as f:
                f.write(chunk_content)
            
            chunk_size = len(chunk_content.encode('utf-8'))
            print(f"  Created {chunk_name}: {chunk_size:,} bytes")
            
            chunk_manifest.append({
                'file': chunk_name,
                'size': chunk_size,
                'description': bundle_info['description']
            })
            total_chunks += 1
    
    # Create deployment manifest
    manifest_content = f"""# NotDeafBeef Blockchain Deployment Manifest
# ==========================================

Total chunks to deploy: {total_chunks}
All chunks are ≤24KB for optimal transaction processing.

## Deployment Order:
"""
    
    for i, chunk_info in enumerate(chunk_manifest):
        manifest_content += f"{i:2d}. {chunk_info['file']} ({chunk_info['size']:,} bytes) - {chunk_info['description']}\n"
    
    manifest_content += f"""
## Deployment Process:
1. Deploy contract (NotDeafbeef721)
2. setNumCodeLocations(0, {total_chunks})
3. For each chunk: send 0-ETH tx with chunk as hex data
4. setCodeLocation(0, i, txHash) for each transaction hash
5. setPaused(0, false) + setPublicMintEnabled(0, true) to open minting
6. lockCodeForever(0) when satisfied

## Build Command for Users:
make generate_frames USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM FM_VOICE_ASM"
./generate_nft.sh [SEED] ./output
"""
    
    with open("blockchain/DEPLOYMENT_MANIFEST.md", 'w') as f:
        f.write(manifest_content)
    
    print(f"\n✅ Created {total_chunks} chunks ready for blockchain deployment!")
    print(f"📋 See blockchain/DEPLOYMENT_MANIFEST.md for deployment instructions")

if __name__ == "__main__":
    main()
