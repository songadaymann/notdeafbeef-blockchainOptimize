#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// WAV header structure
typedef struct {
    // RIFF Header
    char riff_header[4];     // "RIFF"
    uint32_t wav_size;       // Size of the wav portion of the file
    char wave_header[4];     // "WAVE"
    
    // Format Header
    char fmt_header[4];      // "fmt "
    uint32_t fmt_chunk_size; // Size of the format chunk
    uint16_t audio_format;   // Audio format 1=PCM,6=mulaw,7=alaw, 257=IBM Mu-Law, 258=IBM A-Law, 259=ADPCM
    uint16_t num_channels;   // Number of channels 1=Mono 2=Stereo
    uint32_t sample_rate;    // Sampling Frequency in Hz
    uint32_t byte_rate;      // bytes per second
    uint16_t sample_alignment; // 2=16-bit mono, 4=16-bit stereo
    uint16_t bit_depth;      // Number of bits per sample
    
    // Data Header
    char data_header[4];     // "data"
    uint32_t data_bytes;     // Number of bytes in data
} wav_header_t;

int main(int argc, char *argv[]) {
    if (argc < 4) {
        printf("Usage: %s <input.wav> <output.wav> <num_copies>\n", argv[0]);
        printf("Example: %s seed_0xcafebabe.wav concatenated_4x.wav 4\n", argv[0]);
        return 1;
    }
    
    const char *input_file = argv[1];
    const char *output_file = argv[2];
    int num_copies = atoi(argv[3]);
    
    if (num_copies <= 0) {
        printf("Error: num_copies must be positive\n");
        return 1;
    }
    
    // Open input file
    FILE *input = fopen(input_file, "rb");
    if (!input) {
        printf("Error: Cannot open input file %s\n", input_file);
        return 1;
    }
    
    // Read original WAV header
    wav_header_t header;
    if (fread(&header, sizeof(wav_header_t), 1, input) != 1) {
        printf("Error: Cannot read WAV header\n");
        fclose(input);
        return 1;
    }
    
    // Verify it's a WAV file
    if (strncmp(header.riff_header, "RIFF", 4) != 0 || 
        strncmp(header.wave_header, "WAVE", 4) != 0) {
        printf("Error: Not a valid WAV file\n");
        fclose(input);
        return 1;
    }
    
    printf("Input WAV: %d Hz, %d channels, %d-bit, %u data bytes\n", 
           header.sample_rate, header.num_channels, header.bit_depth, header.data_bytes);
    
    // Calculate new sizes
    uint32_t original_data_bytes = header.data_bytes;
    uint32_t new_data_bytes = original_data_bytes * num_copies;
    uint32_t new_wav_size = header.wav_size + (original_data_bytes * (num_copies - 1));
    
    // Read all audio data from input
    uint8_t *audio_data = malloc(original_data_bytes);
    if (!audio_data) {
        printf("Error: Cannot allocate memory for audio data\n");
        fclose(input);
        return 1;
    }
    
    if (fread(audio_data, 1, original_data_bytes, input) != original_data_bytes) {
        printf("Error: Cannot read audio data\n");
        free(audio_data);
        fclose(input);
        return 1;
    }
    fclose(input);
    
    // Open output file
    FILE *output = fopen(output_file, "wb");
    if (!output) {
        printf("Error: Cannot create output file %s\n", output_file);
        free(audio_data);
        return 1;
    }
    
    // Update header for concatenated file
    header.data_bytes = new_data_bytes;
    header.wav_size = new_wav_size;
    
    // Write updated header
    if (fwrite(&header, sizeof(wav_header_t), 1, output) != 1) {
        printf("Error: Cannot write WAV header\n");
        free(audio_data);
        fclose(output);
        return 1;
    }
    
    // Write audio data num_copies times
    for (int i = 0; i < num_copies; i++) {
        if (fwrite(audio_data, 1, original_data_bytes, output) != original_data_bytes) {
            printf("Error: Cannot write audio data (copy %d)\n", i + 1);
            free(audio_data);
            fclose(output);
            return 1;
        }
        printf("Wrote copy %d/%d\n", i + 1, num_copies);
    }
    
    free(audio_data);
    fclose(output);
    
    printf("Success: Created %s with %d copies (%u total data bytes)\n", 
           output_file, num_copies, new_data_bytes);
    
    return 0;
}
