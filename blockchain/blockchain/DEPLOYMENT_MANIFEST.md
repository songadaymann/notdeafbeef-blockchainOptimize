# NotDeafBeef Blockchain Deployment Manifest
# ==========================================

Total chunks to deploy: 15
All chunks are ≤24KB for optimal transaction processing.

## Deployment Order:
 0. bundle_0_core.txt (22,297 bytes) - Core system: seed + build instructions + small audio voices
 1. bundle_1_generator_chunk01.txt (24,092 bytes) - Main audio generator (large file)
 2. bundle_1_generator_chunk02.txt (10,755 bytes) - Main audio generator (large file)
 3. bundle_2_fm_voice.txt (8,195 bytes) - FM synthesis voice (large file)
 4. bundle_3_visual_core_chunk01.txt (24,094 bytes) - Visual foundation: drawing, colors, ASCII rendering
 5. bundle_3_visual_core_chunk02.txt (24,094 bytes) - Visual foundation: drawing, colors, ASCII rendering
 6. bundle_3_visual_core_chunk03.txt (15,410 bytes) - Visual foundation: drawing, colors, ASCII rendering
 7. bundle_4_terrain_chunk01.txt (24,090 bytes) - Terrain generation system (large file)
 8. bundle_4_terrain_chunk02.txt (13,243 bytes) - Terrain generation system (large file)
 9. bundle_5_bass_hits_chunk01.txt (24,092 bytes) - Bass hits and shape system (largest file)
10. bundle_5_bass_hits_chunk02.txt (24,092 bytes) - Bass hits and shape system (largest file)
11. bundle_5_bass_hits_chunk03.txt (14,216 bytes) - Bass hits and shape system (largest file)
12. bundle_6_c_bridge_chunk01.txt (24,091 bytes) - C bridge code and build system
13. bundle_6_c_bridge_chunk02.txt (24,091 bytes) - C bridge code and build system
14. bundle_6_c_bridge_chunk03.txt (6,159 bytes) - C bridge code and build system

## Deployment Process:
1. Deploy contract (NotDeafbeef721)
2. setNumCodeLocations(0, 15)
3. For each chunk: send 0-ETH tx with chunk as hex data
4. setCodeLocation(0, i, txHash) for each transaction hash
5. setPaused(0, false) + setPublicMintEnabled(0, true) to open minting
6. lockCodeForever(0) when satisfied

## Build Command for Users:
make generate_frames USE_ASM=1 VOICE_ASM="GENERATOR_ASM KICK_ASM SNARE_ASM HAT_ASM MELODY_ASM LIMITER_ASM FM_VOICE_ASM"
./generate_nft.sh [SEED] ./output
