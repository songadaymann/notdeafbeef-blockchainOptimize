/*
 * Isolated test file with just the mixing function
 */

.text

	.globl _generator_mix_buffers_asm

/*
 * generator_mix_buffers_asm - NEON vectorized buffer mixing
 * ---------------------------------------------------------
 * void generator_mix_buffers_asm(float *L, float *R, 
 *                                const float *Ld, const float *Rd,
 *                                const float *Ls, const float *Rs, 
 *                                uint32_t num_frames);
 *
 * Performs: L[i] = Ld[i] + Ls[i], R[i] = Rd[i] + Rs[i] for i = 0..num_frames-1
 * Uses NEON vectors to process 4 samples at a time for efficiency.
 * Handles remainder samples with scalar operations.
 */

_generator_mix_buffers_asm:
	// Arguments: x0=L, x1=R, x2=Ld, x3=Rd, x4=Ls, x5=Rs, w6=num_frames
	
	// Early exit if no frames to process
	cbz w6, .Lmix_done
	
	// Calculate how many complete NEON vectors (4 samples) we can process
	lsr w7, w6, #2          // w7 = num_frames / 4 (complete vectors)
	and w8, w6, #3          // w8 = num_frames % 4 (remainder samples)
	
	// Process complete 4-sample vectors with NEON
	cbz w7, .Lmix_scalar    // Skip if no complete vectors
	
.Lmix_vector_loop:
	// Load 4 samples from each source buffer
	ld1 {v0.4s}, [x2], #16  // v0 = Ld[i..i+3], advance pointer
	ld1 {v1.4s}, [x3], #16  // v1 = Rd[i..i+3], advance pointer  
	ld1 {v2.4s}, [x4], #16  // v2 = Ls[i..i+3], advance pointer
	ld1 {v3.4s}, [x5], #16  // v3 = Rs[i..i+3], advance pointer
	
	// Vector addition: drums + synths
	fadd v4.4s, v0.4s, v2.4s  // v4 = Ld + Ls
	fadd v5.4s, v1.4s, v3.4s  // v5 = Rd + Rs
	
	// Store results to output buffers
	st1 {v4.4s}, [x0], #16   // L[i..i+3] = v4, advance pointer
	st1 {v5.4s}, [x1], #16   // R[i..i+3] = v5, advance pointer
	
	// Loop control
	subs w7, w7, #1
	b.ne .Lmix_vector_loop
	
.Lmix_scalar:
	// Handle remaining samples (0-3) with scalar operations
	cbz w8, .Lmix_done
	
.Lmix_scalar_loop:
	// Load single samples
	ldr s0, [x2], #4        // s0 = Ld[i]
	ldr s1, [x3], #4        // s1 = Rd[i]
	ldr s2, [x4], #4        // s2 = Ls[i]
	ldr s3, [x5], #4        // s3 = Rs[i]
	
	// Scalar addition
	fadd s4, s0, s2         // s4 = Ld[i] + Ls[i]
	fadd s5, s1, s3         // s5 = Rd[i] + Rs[i]
	
	// Store results
	str s4, [x0], #4        // L[i] = s4
	str s5, [x1], #4        // R[i] = s5
	
	// Loop control
	subs w8, w8, #1
	b.ne .Lmix_scalar_loop
	
.Lmix_done:
	ret
