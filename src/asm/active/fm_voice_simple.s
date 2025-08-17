	.text
	.align 2
	.globl _fm_voice_process

// Simple FM voice implementation - starting with pure tones
// Progressive approach: pure sine -> carrier+mod -> full FM
fm_constants:
    .float 6.2831853071795864769      // [0] TAU
    .float 1.0                        // [4] ONE
    .float 2.0                        // [8] TWO
    .float 0.1                        // [12] TEST_AMP

_fm_voice_process:
    // Prologue - simple frame
    stp x29, x30, [sp, #-64]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    stp x21, x22, [sp, #32]

    // Save arguments
    mov x19, x0      // fm_voice_t*
    mov x20, x1      // L*
    mov x21, x2      // R*
    mov w22, w3      // n

    // Early exit checks
    cbz w22, Ldone
    
    // Load FM voice struct members (from fm_voice.h)
    // typedef struct { sr, carrier_freq, ratio, index0, amp, decay, len, pos, carrier_phase, mod_phase }
    ldr s0, [x19]        // sr
    ldr s1, [x19, #4]    // carrier_freq
    ldr s2, [x19, #8]    // ratio (for modulator freq)
    ldr s3, [x19, #12]   // index0 (FM index)
    ldr s4, [x19, #16]   // amp
    ldr s5, [x19, #20]   // decay
    ldr w23, [x19, #24]  // len
    ldr w24, [x19, #28]  // pos
    ldr s6, [x19, #32]   // carrier_phase
    ldr s7, [x19, #36]   // mod_phase

    // Check if voice is active
    cmp w24, w23
    b.ge Ldone

    // Load constants
    adrp x4, fm_constants@PAGE
    add  x4, x4, fm_constants@PAGEOFF
    ldr  s10, [x4]       // TAU
    ldr  s11, [x4, #4]   // ONE
    ldr  s16, [x4, #8]   // TWO
    ldr  s17, [x4, #12]  // TEST_AMP

    // Calculate phase increments
    // c_inc = TAU * carrier_freq / sr
    fmul s12, s10, s1    // TAU * carrier_freq
    fdiv s12, s12, s0    // / sr -> c_inc
    
    // m_inc = TAU * carrier_freq * ratio / sr  
    fmul s13, s12, s2    // c_inc * ratio -> m_inc

    mov w4, wzr          // loop counter i

Lloop:
    // Loop bounds check
    cmp w4, w22
    b.ge Lend
    cmp w24, w23
    b.ge Lend

    // PHASE 1: Start with pure carrier tone (no FM modulation yet)
    // Later phases will add: env = exp_decay(t, decay), index modulation, etc.
    
    // For now: sample = sin(carrier_phase) * 0.1  (low amplitude for safety)
    fmov s14, s6         // current carrier phase
    
    // Call sinf(carrier_phase) - but this requires libm and complex register saving
    // Let's use a simple approximation for now: sin(x) ≈ x (for small x)
    // This will create a saw-like wave, not sine, but will prove the system works
    
    // Normalize phase to [-1, 1] range: normalized = (phase / TAU) * 2 - 1
    fdiv s15, s14, s10   // phase / TAU -> [0, 1]
    fmul s15, s15, s16   // * 2 -> [0, 2]
    fsub s15, s15, s11   // - 1
    
    // Simple amplitude scaling
    fmul s15, s15, s17   // sample = normalized * TEST_AMP

    // Add to L[i] and R[i]
    ldr s18, [x20, w4, sxtw #2]
    fadd s18, s18, s15
    str s18, [x20, w4, sxtw #2]

    ldr s18, [x21, w4, sxtw #2]
    fadd s18, s18, s15
    str s18, [x21, w4, sxtw #2]

    // Update counters and phases
    add w4, w4, #1       // i++
    add w24, w24, #1     // pos++
    fadd s6, s6, s12     // carrier_phase += c_inc
    fadd s7, s7, s13     // mod_phase += m_inc (not used yet but keep it updated)

    // Wrap phases
    fcmp s6, s10
    b.lt Lcheck_mod
    fsub s6, s6, s10     // carrier_phase -= TAU
Lcheck_mod:
    fcmp s7, s10
    b.lt Lloop
    fsub s7, s7, s10     // mod_phase -= TAU
    b Lloop

Lend:
    // Store back state
    str w24, [x19, #28]  // pos
    str s6, [x19, #32]   // carrier_phase
    str s7, [x19, #36]   // mod_phase

Ldone:
    // Epilogue
    ldp x21, x22, [sp, #32]
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #64
    ret
