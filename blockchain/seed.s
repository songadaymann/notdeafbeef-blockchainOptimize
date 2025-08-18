; NotDeafBeef - Transaction Hash Seed Placeholder
; ==================================================
; This file contains the token's unique seed that drives all generation.
; 
; INSTRUCTIONS FOR USERS:
; 1. Get your token's seed: call getTokenParams(tokenId) on the contract
; 2. Replace the SEED_HEX string below with your 64-character hex seed
; 3. Keep the "0x" prefix and quotes
; 4. Compile and run the complete pipeline
;
; The seed determines ALL audio and visual characteristics of your NFT.
; Same seed = identical NFT every time (deterministic generation).

.section __DATA,__data
.align 3

; REPLACE THIS LINE: paste your token's 64-character hex seed here
; Example: SEED_HEX: .ascii "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef\0"
SEED_HEX: .ascii "PASTE_YOUR_TOKEN_SEED_HERE_FROM_CONTRACT_getTokenParams\0"

; Alternative format: 32 bytes as 4 64-bit values (little-endian)
; Users can choose either hex string above OR replace these 4 lines:
.global SEED_BYTES
SEED_BYTES:
    .quad 0x0000000000000000  ; bytes 0-7   - REPLACE WITH TOKEN SEED
    .quad 0x0000000000000000  ; bytes 8-15  - REPLACE WITH TOKEN SEED  
    .quad 0x0000000000000000  ; bytes 16-23 - REPLACE WITH TOKEN SEED
    .quad 0x0000000000000000  ; bytes 24-31 - REPLACE WITH TOKEN SEED

; Export symbols for use by other assembly files
.global SEED_HEX
.global SEED_BYTES
