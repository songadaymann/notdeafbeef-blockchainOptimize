#include "wav_writer.h"
#include "fm_voice.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

int main(void)
{
    const uint32_t sr = 44100;
    const uint32_t total_frames = sr * 1; // 1 second
    float *L = calloc(total_frames, sizeof(float));
    float *R = calloc(total_frames, sizeof(float));

    fm_voice_t fm; 
    fm_voice_init(&fm, (float)sr);
    
    // Trigger FM voice
    fm_voice_trigger(&fm, 440.0f, 1.0f, 2.0f, 5.0f, 0.5f, 0.01f);
    printf("FM triggered freq=440 dur=1.0 ratio=2.0 index=5.0 amp=0.5 decay=0.01\n");
    
    // Process the entire duration in one call
    fm_voice_process(&fm, L, R, total_frames);
    printf("Processed %u frames\n", total_frames);

    // Check if anything was generated
    float max_val = 0.0f;
    for(uint32_t i = 0; i < total_frames; i++) {
        if(fabsf(L[i]) > max_val) max_val = fabsf(L[i]);
    }
    printf("Max amplitude: %f\n", max_val);

    /* convert to int16 wav */
    int16_t *pcm = malloc(sizeof(int16_t)*total_frames*2);
    for(uint32_t i=0;i<total_frames;i++){
        float vL=L[i]; if(vL>1) vL=1; if(vL<-1) vL=-1;
        pcm[2*i] = (int16_t)(vL*32767);
        pcm[2*i+1] = pcm[2*i];
    }
    write_wav("fm_asm_single.wav", pcm, total_frames, 2, sr);
    
    printf("Generated fm_asm_single.wav\n");

    free(L);free(R);free(pcm);
    return 0;
}
