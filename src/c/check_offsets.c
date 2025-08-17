#include <stdio.h>
#include <stddef.h>
#include "generator.h"

int main() {
    printf("generator_t size: %zu bytes\n", sizeof(generator_t));
    printf("Offsets:\n");
    printf("  kick: %zu\n", offsetof(generator_t, kick));
    printf("  snare: %zu\n", offsetof(generator_t, snare));
    printf("  hat: %zu\n", offsetof(generator_t, hat));
    printf("  mel: %zu\n", offsetof(generator_t, mel));
    printf("  mid_fm: %zu\n", offsetof(generator_t, mid_fm));
    printf("  bass_fm: %zu\n", offsetof(generator_t, bass_fm));
    printf("  q: %zu\n", offsetof(generator_t, q));
    printf("  event_idx: %zu\n", offsetof(generator_t, event_idx));
    printf("  step: %zu\n", offsetof(generator_t, step));
    printf("  pos_in_step: %zu\n", offsetof(generator_t, pos_in_step));
    printf("  delay: %zu\n", offsetof(generator_t, delay));
    printf("  limiter: %zu\n", offsetof(generator_t, limiter));
    return 0;
}
