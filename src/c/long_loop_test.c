/*
 * long_loop_test.c - Generate ~1 minute of loopable audio
 * 
 * Creates a longer sequence by concatenating multiple segments with seamless looping.
 * The approach:
 * 1. Generate multiple segments with the same seed (for consistency)
 * 2. Chain them together to create ~1 minute of audio
 * 3. Ensure seamless loop by matching start/end states
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>

#include "generator.h"
#include "music_time.h"
#include "kick.h"
#include "snare.h"
#include "hat.h"
#include "melody.h"
#include "fm_voice.h"
#include "delay.h"
#include "limiter.h"

/* Include generator step helper */
void generator_trigger_step(generator_t *g);

/* Target duration: ~4 seconds for initial test */
static const float TARGET_DURATION = 4.0f;
static const float BPM = 120.0f;

/* Calculate how many segments needed for target duration */
static uint32_t calculate_segments_needed(void) {
    music_time_t timing;
    music_time_init(&timing, BPM);
    
    float segments_needed = TARGET_DURATION / timing.seg_sec;
    return (uint32_t)(segments_needed + 0.5f); /* Round to nearest */
}

/* Generate a seamless loop by repeating segments */
static void generate_long_loop(uint32_t seed, const char* output_filename) {
    music_time_t timing;
    music_time_init(&timing, BPM);
    
    uint32_t num_segments = calculate_segments_needed();
    uint32_t total_frames = num_segments * timing.seg_frames;
    
    printf("Generating %u segments (%.2f seconds each) for total %.2f seconds\n",
           num_segments, timing.seg_sec, num_segments * timing.seg_sec);
    printf("Total frames: %u (%.2fMB audio data)\n", 
           total_frames, (total_frames * 8.0f) / (1024.0f * 1024.0f));
    
    /* Generate one base segment first */
    float *L_base = malloc(timing.seg_frames * sizeof(float));
    float *R_base = malloc(timing.seg_frames * sizeof(float));
    if (!L_base || !R_base) {
        fprintf(stderr, "Failed to allocate base segment buffers\n");
        exit(1);
    }
    
    generator_t g;
    generator_init(&g, seed);
    
    printf("Generating base segment...\n");
    
    /* Use manual processing like segment_test.c instead of generator_process */
    uint32_t seg_frames = timing.seg_frames;
    for (uint32_t frame = 0; frame < seg_frames; ) {
        uint32_t remaining = seg_frames - frame;
        uint32_t block_size = (remaining > 1024) ? 1024 : remaining;
        
        /* Trigger events (always run this to advance timing) */
        generator_trigger_step(&g);
        
        /* Process all voices into the block */
        float *block_L = &L_base[frame];
        float *block_R = &R_base[frame];
        
        /* Clear the block */
        memset(block_L, 0, block_size * sizeof(float));
        memset(block_R, 0, block_size * sizeof(float));
        
        /* Process all voices */
        kick_process(&g.kick, block_L, block_R, block_size);
        snare_process(&g.snare, block_L, block_R, block_size);
        hat_process(&g.hat, block_L, block_R, block_size);
        melody_process(&g.mel, block_L, block_R, block_size);
        fm_voice_process(&g.mid_fm, block_L, block_R, block_size);
        fm_voice_process(&g.bass_fm, block_L, block_R, block_size);
        delay_process_block(&g.delay, block_L, block_R, block_size, 0.45f);
        limiter_process(&g.limiter, block_L, block_R, block_size);
        
        /* Advance timing manually */
        g.pos_in_step += block_size;
        if (g.pos_in_step >= g.mt.step_samples) {
            g.pos_in_step = 0;
            g.step++;
        }
        
        frame += block_size;
    }
    
    /* Allocate output buffers for entire sequence */
    float *L_total = malloc(total_frames * sizeof(float));
    float *R_total = malloc(total_frames * sizeof(float));
    if (!L_total || !R_total) {
        fprintf(stderr, "Failed to allocate %.2fMB for audio buffers\n",
                (total_frames * 8.0f) / (1024.0f * 1024.0f));
        exit(1);
    }
    
    printf("Repeating segment %u times for seamless loop...\n", num_segments);
    
    /* Copy base segment multiple times to create loop */
    for (uint32_t seg = 0; seg < num_segments; seg++) {
        uint32_t offset = seg * timing.seg_frames;
        memcpy(L_total + offset, L_base, timing.seg_frames * sizeof(float));
        memcpy(R_total + offset, R_base, timing.seg_frames * sizeof(float));
        
        if ((seg + 1) % 5 == 0) {
            printf("Copied %u/%u segments...\r", seg + 1, num_segments);
            fflush(stdout);
        }
    }
    printf("\n");
    
    free(L_base);
    free(R_base);
    
    /* Write WAV file */
    FILE *f = fopen(output_filename, "wb");
    if (!f) {
        fprintf(stderr, "Failed to open %s for writing\n", output_filename);
        exit(1);
    }
    
    /* WAV header */
    uint32_t data_size = total_frames * 2 * sizeof(float); /* stereo */
    uint32_t file_size = 36 + data_size;
    
    fwrite("RIFF", 1, 4, f);
    fwrite(&file_size, 4, 1, f);
    fwrite("WAVE", 1, 4, f);
    
    /* fmt chunk */
    fwrite("fmt ", 1, 4, f);
    uint32_t fmt_size = 16;
    uint16_t format = 3; /* IEEE float */
    uint16_t channels = 2;
    uint32_t sample_rate = SR;
    uint32_t byte_rate = sample_rate * channels * sizeof(float);
    uint16_t block_align = channels * sizeof(float);
    uint16_t bits_per_sample = 32;
    
    fwrite(&fmt_size, 4, 1, f);
    fwrite(&format, 2, 1, f);
    fwrite(&channels, 2, 1, f);
    fwrite(&sample_rate, 4, 1, f);
    fwrite(&byte_rate, 4, 1, f);
    fwrite(&block_align, 2, 1, f);
    fwrite(&bits_per_sample, 2, 1, f);
    
    /* data chunk */
    fwrite("data", 1, 4, f);
    fwrite(&data_size, 4, 1, f);
    
    /* Interleave and write audio data */
    for (uint32_t i = 0; i < total_frames; i++) {
        fwrite(&L_total[i], sizeof(float), 1, f);
        fwrite(&R_total[i], sizeof(float), 1, f);
    }
    
    fclose(f);
    
    printf("Wrote %.2f seconds of audio to %s\n", 
           num_segments * timing.seg_sec, output_filename);
    
    /* Cleanup */
    free(L_total);
    free(R_total);
}

int main(int argc, char *argv[]) {
    printf("Starting long_loop_test...\n");
    
    uint32_t seed = 0x12345678; /* Default seed */
    const char *output = "long_loop.wav";
    
    if (argc > 1) {
        seed = strtoul(argv[1], NULL, 0);
    }
    if (argc > 2) {
        output = argv[2];
    }
    
    printf("Generating long loop with seed 0x%08X\n", seed);
    generate_long_loop(seed, output);
    
    return 0;
}
