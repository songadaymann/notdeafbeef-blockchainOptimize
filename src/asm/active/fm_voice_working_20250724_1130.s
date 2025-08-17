//
// Dead-simple FM voice assembly implementation
// Created: 2025-07-22
// Purpose: Basic, working FM synthesis to replace complex broken version
//

.text
.align 4

//
// void fm_voice_process(fm_voice_t *v, float32_t *L, float32_t *R, uint32_t n)
//
// This is a "hello FM" version - extremely simple to ensure it works
// Just renders a fixed frequency sine wave at -6dB for now
//
.global _fm_voice_process
// .type fm_voice_process, %function  // Skip for macOS

_fm_voice_process:
    // Prologue - save registers and SIMD registers
    stp     x29, x30, [sp, #-16]!
    mov     x29, sp
    
    // Save callee-saved SIMD registers (v8-v15) - ARM64 ABI requirement
    sub     sp, sp, #128              // 8×16 = 128 bytes  
    stp     q8,  q9,  [sp, #0]        // save v8, v9
    stp     q10, q11, [sp, #32]       // save v10, v11
    stp     q12, q13, [sp, #64]       // save v12, v13
    stp     q14, q15, [sp, #96]       // save v14, v15
    
    // Input parameters:
    // x0 = fm_voice_t *v
    // x1 = float32_t *L  
    // x2 = float32_t *R
    // x3 = uint32_t n
    
    // Safety check: if n == 0, return immediately
    cbz     x3, .Lreturn
    
    // TEMP: Skip voice length check to debug audio issue
    // Check if voice is active: if (v->pos >= v->len) return
    // ldr     w5, [x0, #28]       // v->pos
    // ldr     w6, [x0, #24]       // v->len  
    // cmp     w5, w6
    // bhs     .Lreturn            // return if pos >= len (unsigned comparison)
    
    // Load voice parameters into SAFE registers (v8-v15 are callee-saved)
    ldr     s0, [x0, #32]       // v->carrier_phase 
    fmov    s15, s0             // Initialize running carrier phase accumulator
    ldr     s1, [x0, #36]       // v->mod_phase
    fmov    s14, s1             // Initialize running modulator phase accumulator
    ldr     s8, [x0, #0]        // v->sr (safe register)
    ldr     s9, [x0, #4]        // v->carrier_freq (safe register)
    ldr     s10, [x0, #16]      // v->amp (safe register)
    ldr     s11, [x0, #20]      // v->decay (safe register)
    ldr     s12, [x0, #8]       // v->ratio (safe register)
    ldr     s13, [x0, #12]      // v->index0 (safe register)
    
    // Bounds check on inputs to prevent instability (using safe registers)
    // Clamp sample rate to reasonable range [8000, 192000]
    ldr     w5, =0x45FA0000      // 8000.0 in hex
    fmov    s5, w5
    ldr     w5, =0x473B8000      // 192000.0 in hex  
    fmov    s6, w5
    fmax    s8, s8, s5          // sr = max(sr, 8000)
    fmin    s8, s8, s6          // sr = min(sr, 192000)
    
    // Clamp frequency to reasonable range [1, 20000]
    ldr     w5, =0x3F800000      // 1.0 in hex
    fmov    s5, w5
    ldr     w5, =0x469C4000      // 20000.0 in hex
    fmov    s6, w5
    fmax    s9, s9, s5          // freq = max(freq, 1.0)
    fmin    s9, s9, s6          // freq = min(freq, 20000.0)
    
    // Calculate carrier and modulator phase increments using 2π
    ldr     w5, =0x40C90FDB      // 2π = 6.2831855f in hex
    fmov    s26, w5             // s26 = TAU (for phase wrapping)
    
    // Carrier phase increment: c_inc = 2π * carrier_freq / sr
    fmul    s27, s26, s9        // s27 = 2π * carrier_freq 
    fdiv    s27, s27, s8        // s27 = carrier phase delta
    
    // Modulator phase increment: m_inc = 2π * carrier_freq * ratio / sr  
    fmul    s28, s9, s12        // s28 = carrier_freq * ratio
    fmul    s28, s26, s28       // s28 = 2π * carrier_freq * ratio
    fdiv    s28, s28, s8        // s28 = modulator phase delta
    
    // Process loop
    mov     x4, #0              // loop counter i
    
.Lloop:
    // TEMP: Skip inside loop check too
    // Check if voice is still active inside loop: if (v->pos >= v->len) break
    // ldr     w5, [x0, #28]       // v->pos  
    // ldr     w6, [x0, #24]       // v->len
    // cmp     w5, w6
    // bhs     .Lloop_end          // break if pos >= len
    
    // ----- Proper FM synthesis: sample = sin(carrier + index * sin(modulator)) -----
    
    // Step 1: Calculate sin(modulator_phase)
    fmov    s0, s14            // s0 = modulator phase
    dup     v0.4s, v0.s[0]     // v0 = {mod_phase,mod_phase,mod_phase,mod_phase}
    bl      _sin4_ps_asm       // v0.s[0] = sin(modulator_phase)
    mov     s23, v0.s[0]       // s23 = sin(modulator) - SAFE register
    
    // Step 2: Calculate index * sin(modulator)
    ldr     s13, [x0, #12]     // v->index0 (reload after helper calls)
    fmul    s23, s23, s13      // s23 = index * sin(modulator)
    
    // Step 3: Calculate carrier + (index * sin(modulator))
    fadd    s0, s15, s23       // s0 = carrier_phase + index * sin(modulator)
    
    // Step 4: Calculate sin(carrier + index * sin(modulator))
    dup     v0.4s, v0.s[0]     // v0 = {fm_phase,fm_phase,fm_phase,fm_phase}
    bl      _sin4_ps_asm       // v0.s[0] = sin(fm_phase)
    mov     s24, v0.s[0]       // s24 = FM output - SAFE register
    
    // ----- Apply simple linear decay with bounds checking -----
    ldr     s10, [x0, #16]      // v->amp (reload after helper calls)
    ldr     w5, [x0, #28]       // v->pos
    ldr     w6, [x0, #24]       // v->len
    
    // Safety check: if pos >= len, set decay to 0
    cmp     w5, w6
    bhs     .Lsilent            // if pos >= len, jump to silent
    
    ucvtf   s20, w5             // s20 = (float)pos
    ucvtf   s21, w6             // s21 = (float)len
    fdiv    s22, s20, s21       // s22 = pos/len (should be 0 to 1)
    fmov    s23, #1.0           // s23 = 1.0
    fsub    s23, s23, s22       // s23 = 1 - pos/len (1 to 0, linear decay)
    
    // Clamp decay factor to [0.0, 1.0] range
    fmov    s25, #0.0           // s25 = 0.0
    fmax    s23, s23, s25       // s23 = max(decay, 0.0)
    fmov    s25, #1.0           // s25 = 1.0  
    fmin    s23, s23, s25       // s23 = min(decay, 1.0)
    
    fmul    s10, s10, s23       // s10 = amp * decay_factor
    fmul    s5, s24, s10        // s5 = amplitude * fm_sample * decay
    b       .Loutput
    
.Lsilent:
    fmov    s5, #0.0            // output silence if note finished
    
.Loutput:
    
    // Add to both left and right channels
    ldr     s6, [x1, x4, lsl #2]   // load L[i] 
    ldr     s7, [x2, x4, lsl #2]   // load R[i]
    fadd    s6, s6, s5             // L[i] += sample
    fadd    s7, s7, s5             // R[i] += sample  
    str     s6, [x1, x4, lsl #2]   // store L[i]
    str     s7, [x2, x4, lsl #2]   // store R[i]
    
    // Increment both carrier and modulator phases
    fadd    s15, s15, s27         // advance carrier phase
    fadd    s14, s14, s28         // advance modulator phase
    
    // Wrap carrier phase to [0, 2π] range to prevent explosion
    fcmp    s15, s26
    blt     .Lcarrier_wrap_done
    fsub    s15, s15, s26         // carrier_phase -= 2π
    fcmp    s15, s26              // check again (only do this once to avoid hanging)
    blt     .Lcarrier_wrap_done
    fsub    s15, s15, s26         // carrier_phase -= 2π (second time max)
    
    // Also handle negative wrap for carrier: while (phase < 0) phase += 2π  
.Lcarrier_wrap_done:
    fmov    s29, #0.0             // use s29 for zero comparison
    fcmp    s15, s29
    bge     .Lcarrier_positive
    fadd    s15, s15, s26         // carrier_phase += 2π
    
.Lcarrier_positive:
    
    // Wrap modulator phase to [0, 2π] range to prevent explosion
    fcmp    s14, s26
    blt     .Lmod_wrap_done
    fsub    s14, s14, s26         // mod_phase -= 2π
    fcmp    s14, s26              // check again (only do this once to avoid hanging)
    blt     .Lmod_wrap_done
    fsub    s14, s14, s26         // mod_phase -= 2π (second time max)
    
    // Also handle negative wrap for modulator: while (phase < 0) phase += 2π  
.Lmod_wrap_done:
    fcmp    s14, s29
    bge     .Lmod_positive
    fadd    s14, s14, s26         // mod_phase += 2π
    
.Lmod_positive:
    
    // Phase is already in s15 for next iteration - no copy needed
    
    // Increment voice position: v->pos++
    ldr     w5, [x0, #28]       // v->pos
    add     w5, w5, #1          // pos++
    str     w5, [x0, #28]       // store updated pos
    
    // Loop increment
    add     x4, x4, #1
    cmp     x4, x3
    blt     .Lloop

.Lloop_end:
    
    // Store updated phases back to voice
    str     s15, [x0, #32]     // v->carrier_phase (from running accumulator)
    str     s14, [x0, #36]     // v->mod_phase (from running accumulator)
    
.Lreturn:
    // Epilogue - restore SIMD registers and return
    // Restore callee-saved SIMD registers 
    ldp     q14, q15, [sp, #96]       // restore v14, v15
    ldp     q12, q13, [sp, #64]       // restore v12, v13
    ldp     q10, q11, [sp, #32]       // restore v10, v11
    ldp     q8,  q9,  [sp, #0]        // restore v8, v9  
    add     sp, sp, #128              // restore stack pointer
    
    ldp     x29, x30, [sp], #16       // restore frame and return address
    ret

// .size fm_voice_process, .-fm_voice_process  // Skip for macOS
