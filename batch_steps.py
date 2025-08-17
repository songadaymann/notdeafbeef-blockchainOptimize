#!/usr/bin/env python3

import csv
import subprocess
import sys
import os
import time
import json
from pathlib import Path
from datetime import datetime

def hash_to_32bit(tx_hash):
    """Convert long transaction hash to 32-bit seed (same as C function)"""
    hex_start = tx_hash[2:] if tx_hash.startswith('0x') else tx_hash
    
    seed = 0
    # XOR all 8-character chunks together
    for i in range(0, len(hex_start), 8):
        chunk = hex_start[i:i+8]
        if chunk:
            chunk_val = int(chunk, 16) if chunk else 0
            seed ^= chunk_val
    
    # Avoid degenerate case
    if seed == 0:
        seed = 0xDEADBEEF
    
    return f"0x{seed:08x}"

def step1_hash_seeds(input_csv, run_id, output_base):
    """Step 1: Convert long hashes to 32-bit hashes"""
    print("🔨 Step 1: Hashing transaction hashes to 32-bit seeds")
    
    # Read input CSV
    tx_hashes = []
    with open(input_csv, 'r') as f:
        reader = csv.reader(f)
        for i, row in enumerate(reader):
            if i == 0 and ('transaction' in row[0].lower() or 'hash' in row[0].lower()):
                continue  # Skip header
            if row and row[0].strip():
                tx_hashes.append(row[0].strip())
    
    # Create hashed CSV in output directory
    hashes_dir = output_base / "hashes"
    hashes_dir.mkdir(parents=True, exist_ok=True)
    
    hash_csv = hashes_dir / f"run_{run_id}.csv"
    
    with open(hash_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['original_hash', 'hashed_seed', 'description'])
        
        for tx_hash in tx_hashes:
            hashed_seed = hash_to_32bit(tx_hash)
            writer.writerow([tx_hash, hashed_seed, f"NFT from {tx_hash[:10]}..."])
    
    print(f"✅ Created hash mapping: {hash_csv}")
    print(f"   📊 Processed {len(tx_hashes)} transaction hashes")
    return hash_csv, tx_hashes

def step2_generate_segments(hash_csv, run_id):
    """Step 2: Generate audio segments"""
    print("🎵 Step 2: Generating audio segments")
    
    # Read hash mapping
    hash_mappings = []
    with open(hash_csv, 'r') as f:
        reader = csv.DictReader(f)
        hash_mappings = list(reader)
    
    wav_run_dir = Path("wav") / f"run_{run_id}"
    wav_run_dir.mkdir(parents=True, exist_ok=True)
    
    successful = 0
    for mapping in hash_mappings:
        original_hash = mapping['original_hash']
        hashed_seed = mapping['hashed_seed']
        
        print(f"🎼 Generating segment for {original_hash} (seed: {hashed_seed})")
        
        # Create directory for this hash
        hash_dir = wav_run_dir / original_hash
        hash_dir.mkdir(exist_ok=True)
        
        # Generate segment
        try:
            result = subprocess.run(
                ["src/c/bin/segment", original_hash],  # Use full hash for audio
                cwd=Path.cwd(),
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                # Find generated segment file
                segment_files = list(Path.cwd().glob("seed_0x*.wav"))
                if segment_files:
                    segment_file = segment_files[0]
                    target_file = hash_dir / f"{original_hash}-segment.wav"
                    segment_file.rename(target_file)
                    print(f"   ✅ {target_file}")
                    successful += 1
                else:
                    print(f"   ❌ No segment file generated")
            else:
                print(f"   ❌ Segment generation failed: {result.stderr}")
                
        except Exception as e:
            print(f"   💥 Exception: {e}")
    
    print(f"✅ Generated {successful}/{len(hash_mappings)} audio segments")
    return successful

def step3_concatenate_audio(run_id, output_base):
    """Step 3: Concatenate audio segments"""
    print("🔄 Step 3: Concatenating audio segments")
    
    wav_run_dir = output_base / "wav" / f"run_{run_id}"
    successful = 0
    
    for hash_dir in wav_run_dir.iterdir():
        if hash_dir.is_dir():
            original_hash = hash_dir.name
            segment_file = hash_dir / f"{original_hash}-segment.wav"
            concat_file = hash_dir / f"{original_hash}-concat.wav"
            
            if segment_file.exists():
                print(f"🔗 Concatenating {original_hash}")
                
                try:
                    # Use sox to concatenate 6 times for ~40s
                    result = subprocess.run([
                        "sox", str(segment_file), str(segment_file), str(segment_file),
                        str(segment_file), str(segment_file), str(segment_file), str(concat_file)
                    ], capture_output=True, text=True, timeout=30)
                    
                    if result.returncode == 0 and concat_file.exists():
                        print(f"   ✅ {concat_file}")
                        successful += 1
                    else:
                        print(f"   ❌ Concatenation failed: {result.stderr}")
                        
                except Exception as e:
                    print(f"   💥 Exception: {e}")
    
    print(f"✅ Concatenated {successful} audio files")
    return successful

def step4_generate_frames(run_id, output_base):
    """Step 4: Generate visual frames"""
    print("🖼️  Step 4: Generating visual frames")
    
    wav_run_dir = output_base / "wav" / f"run_{run_id}"
    frames_run_dir = output_base / "frames" / f"run_{run_id}"
    frames_run_dir.mkdir(parents=True, exist_ok=True)
    
    successful = 0
    
    for hash_dir in wav_run_dir.iterdir():
        if hash_dir.is_dir():
            original_hash = hash_dir.name
            concat_file = hash_dir / f"{original_hash}-concat.wav"
            
            if concat_file.exists():
                print(f"🎨 Generating frames for {original_hash}")
                
                # Create frames directory for this hash
                hash_frames_dir = frames_run_dir / original_hash
                hash_frames_dir.mkdir(exist_ok=True)
                
                try:
                    # Generate frames in the hash-specific directory
                    # Use absolute paths to avoid directory confusion
                    abs_concat_file = concat_file.resolve()
                    abs_generate_frames = (Path.cwd() / "generate_frames").resolve()
                    
                    result = subprocess.run([
                        str(abs_generate_frames), 
                        str(abs_concat_file), 
                        original_hash
                    ], 
                    cwd=hash_frames_dir,  # Run in target directory
                    capture_output=True, 
                    text=True, 
                    timeout=300
                    )
                    
                    if result.returncode == 0:
                        frame_count = len(list(hash_frames_dir.glob("frame_*.ppm")))
                        if frame_count > 0:
                            print(f"   ✅ Generated {frame_count} frames")
                            successful += 1
                        else:
                            print(f"   ❌ No frames generated")
                    else:
                        print(f"   ❌ Frame generation failed: {result.stderr[:100]}...")
                        
                except Exception as e:
                    print(f"   💥 Exception: {e}")
    
    print(f"✅ Generated frames for {successful} NFTs")
    return successful

def step5_create_videos(run_id, output_base):
    """Step 5: Create final videos"""
    print("🎬 Step 5: Creating final videos")
    
    frames_run_dir = output_base / "frames" / f"run_{run_id}"
    wav_run_dir = output_base / "wav" / f"run_{run_id}"
    video_run_dir = output_base / "video" / f"run_{run_id}"
    video_run_dir.mkdir(parents=True, exist_ok=True)
    
    successful = 0
    
    for hash_frames_dir in frames_run_dir.iterdir():
        if hash_frames_dir.is_dir():
            original_hash = hash_frames_dir.name
            concat_audio = wav_run_dir / original_hash / f"{original_hash}-concat.wav"
            output_video = video_run_dir / f"{original_hash}.mp4"
            
            if concat_audio.exists() and any(hash_frames_dir.glob("frame_*.ppm")):
                print(f"🎞️  Creating video for {original_hash}")
                print(f"   📁 Frames dir: {hash_frames_dir}")
                print(f"   🎵 Audio file: {concat_audio}")
                print(f"   🎬 Output video: {output_video}")
                
                try:
                    # Use absolute paths and devnull for stdout/stderr
                    abs_concat_audio = concat_audio.resolve()
                    abs_output_video = output_video.resolve()
                    
                    with open(os.devnull, 'w') as devnull:
                        result = subprocess.run([
                            "ffmpeg", "-y", "-r", "60", 
                            "-i", "frame_%04d.ppm",
                            "-i", str(abs_concat_audio),
                            "-c:v", "libx264", "-c:a", "aac",
                            "-pix_fmt", "yuv420p", "-shortest",
                            str(abs_output_video)
                        ], 
                        cwd=hash_frames_dir,
                        stdout=devnull,
                        stderr=devnull,
                        timeout=120
                        )
                    
                    # Check if video was successfully created regardless of return code
                    if output_video.exists() and output_video.stat().st_size > 1000:  # At least 1KB
                        size_mb = output_video.stat().st_size / (1024 * 1024)
                        print(f"   ✅ {output_video.name} ({size_mb:.1f}MB)")
                        successful += 1
                    else:
                        print(f"   ❌ Video creation failed: No valid output file")
                        
                except Exception as e:
                    print(f"   💥 Exception: {e}")
    
    print(f"✅ Created {successful} videos")
    return successful

def step6_generate_metadata(run_id, output_base):
    """Step 6: Generate JSON metadata"""
    print("📋 Step 6: Generating metadata")
    
    json_dir = output_base / "json"
    json_dir.mkdir(parents=True, exist_ok=True)
    
    video_run_dir = output_base / "video" / f"run_{run_id}"
    wav_run_dir = output_base / "wav" / f"run_{run_id}"
    
    successful = 0
    
    for video_file in video_run_dir.glob("*.mp4"):
        original_hash = video_file.stem
        json_file = json_dir / f"{original_hash}.json"
        
        concat_audio = wav_run_dir / original_hash / f"{original_hash}-concat.wav"
        
        # Get video duration
        try:
            result = subprocess.run([
                "ffprobe", "-v", "quiet", "-show_entries", "format=duration", 
                "-of", "csv=p=0", str(video_file)
            ], capture_output=True, text=True, timeout=10)
            
            duration = float(result.stdout.strip()) if result.returncode == 0 else 0
            
            metadata = {
                "transaction_hash": original_hash,
                "hashed_seed": hash_to_32bit(original_hash),
                "generated_at": datetime.now().isoformat(),
                "run_id": run_id,
                "duration_seconds": duration,
                "video_file": str(video_file),
                "audio_file": str(concat_audio),
                "size_mb": video_file.stat().st_size / (1024 * 1024),
                "reproducible": True,
                "version": "optimized"
            }
            
            with open(json_file, 'w') as f:
                json.dump(metadata, f, indent=2)
            
            print(f"   ✅ {json_file}")
            successful += 1
            
        except Exception as e:
            print(f"   💥 Metadata failed for {original_hash}: {e}")
    
    print(f"✅ Generated {successful} metadata files")
    return successful

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 batch_steps.py <step|all> [max_count] [csv_file] [output_dir] [run_id]")
        print()
        print("Steps:")
        print("  1 - Hash transaction hashes to 32-bit seeds")
        print("  2 - Generate audio segments") 
        print("  3 - Concatenate audio segments")
        print("  4 - Generate visual frames")
        print("  5 - Create final videos")
        print("  6 - Generate JSON metadata")
        print("  all - Run all steps")
        print()
        print("Examples:")
        print("  python3 batch_steps.py all 10")
        print("  python3 batch_steps.py 1 10 input/seeds.csv")
        print("  python3 batch_steps.py 3 3 input/seeds.csv 20250817_101142  # Use existing run")
        print("  python3 batch_steps.py 4  # Just generate frames")
        sys.exit(1)
    
    step = sys.argv[1]
    max_count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    csv_file = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("input/seeds.csv")
    output_base = Path(sys.argv[4]) if len(sys.argv) > 4 else Path("./step_output")
    
    # Use existing run_id or create new one
    if len(sys.argv) > 5:
        run_id = sys.argv[5]
        print(f"📁 Using existing run: {run_id}")
    else:
        run_id = datetime.now().strftime("%Y%m%d_%H%M%S")
        print(f"🆕 Creating new run: {run_id}")
    
    print("🎨 NotDeafBeef Step-by-Step Generator")
    print("====================================")
    print(f"📅 Run ID: {run_id}")
    print(f"📋 Input CSV: {csv_file}")
    print(f"🎯 Max count: {max_count}")
    print(f"📁 Output base: {output_base}")
    print()
    
    if not csv_file.exists():
        print(f"❌ CSV file not found: {csv_file}")
        sys.exit(1)
    
    # Read and limit input
    with open(csv_file, 'r') as f:
        reader = csv.reader(f)
        all_hashes = []
        for i, row in enumerate(reader):
            if i == 0 and ('transaction' in row[0].lower() or 'hash' in row[0].lower()):
                continue
            if row and row[0].strip():
                all_hashes.append(row[0].strip())
    
    tx_hashes = all_hashes[:max_count]
    print(f"📊 Processing {len(tx_hashes)} out of {len(all_hashes)} available hashes")
    print()
    
    # Execute requested steps
    if step == "1" or step == "all":
        hash_csv, _ = step1_hash_seeds(csv_file, run_id, output_base)
        print()
    
    if step == "2" or step == "all":
        step2_generate_segments(run_id, tx_hashes, output_base)
        print()
    
    if step == "3" or step == "all":
        step3_concatenate_audio(run_id, output_base)
        print()
        
    if step == "4" or step == "all":
        step4_generate_frames(run_id, output_base)
        print()
        
    if step == "5" or step == "all":
        step5_create_videos(run_id, output_base)
        print()
        
    if step == "6" or step == "all":
        step6_generate_metadata(run_id, output_base)
        print()
    
    print("🎉 Step-by-step generation complete!")
    print(f"📁 Check the following directories for outputs:")
    print(f"   🔨 {output_base}/hashes/run_{run_id}.csv")
    print(f"   🎵 {output_base}/wav/run_{run_id}/")
    print(f"   🖼️  {output_base}/frames/run_{run_id}/")
    print(f"   🎬 {output_base}/video/run_{run_id}/")
    print(f"   📋 {output_base}/json/")

def step2_generate_segments(run_id, tx_hashes, output_base):
    """Step 2: Generate audio segments for each hash"""
    print("🎵 Step 2: Generating audio segments")
    
    wav_run_dir = output_base / "wav" / f"run_{run_id}"
    wav_run_dir.mkdir(parents=True, exist_ok=True)
    
    successful = 0
    
    for original_hash in tx_hashes:
        print(f"🎼 Generating segment for {original_hash}")
        
        # Create directory for this hash
        hash_dir = wav_run_dir / original_hash
        hash_dir.mkdir(exist_ok=True)
        
        try:
            # Generate segment using 32-bit hashed seed (C can't parse long hex strings)
            hashed_seed = hash_to_32bit(original_hash)
            result = subprocess.run(
                ["src/c/bin/segment", hashed_seed],
                cwd=Path.cwd(),
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                # Find the specific segment file generated for this hashed seed
                # Use the 32-bit hashed seed for filename (what the C program actually creates)
                expected_seed = hashed_seed.lower()
                if expected_seed.startswith('0x'):
                    expected_seed = expected_seed[2:]  # Remove 0x prefix
                
                expected_filename = f"seed_0x{expected_seed}.wav"
                segment_file = Path.cwd() / expected_filename
                
                if segment_file.exists():
                    target_file = hash_dir / f"{original_hash}-segment.wav"
                    segment_file.rename(target_file)
                    print(f"   ✅ {target_file}")
                    successful += 1
                else:
                    # Fallback: look for any seed file (but this indicates a problem)
                    segment_files = list(Path.cwd().glob("seed_0x*.wav"))
                    if segment_files:
                        print(f"   ⚠️  Expected {expected_filename}, found {segment_files[0].name}")
                        segment_file = segment_files[0]
                        target_file = hash_dir / f"{original_hash}-segment.wav"
                        segment_file.rename(target_file)
                        successful += 1
                    else:
                        print(f"   ❌ No segment file generated")
            else:
                print(f"   ❌ Generation failed: {result.stderr[:100]}...")
                
        except Exception as e:
            print(f"   💥 Exception: {e}")
    
    print(f"✅ Generated {successful}/{len(tx_hashes)} segments")
    return successful

if __name__ == "__main__":
    main()
