// Package audio provides utilities for working with audio files.
package audio

import (
	"math"
	"os"
)

// MeasureDuration returns the approximate duration of an MP3 file in seconds.
//
// It reads the first valid MPEG1 Layer3 frame header to determine bitrate,
// then estimates duration from file size (accurate for CBR, which OpenAI TTS produces).
// Falls back to a 128 kbps estimate if the header cannot be parsed.
func MeasureDuration(path string) (float64, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return 0, err
	}
	return measureFromBytes(data), nil
}

func measureFromBytes(data []byte) float64 {
	offset := skipID3v2(data)

	for i := offset; i < len(data)-3; i++ {
		// MPEG sync word: 11 set bits
		if data[i] != 0xFF || data[i+1]&0xE0 != 0xE0 {
			continue
		}
		h := uint32(data[i])<<24 | uint32(data[i+1])<<16 | uint32(data[i+2])<<8 | uint32(data[i+3])

		version := (h >> 19) & 0x3  // 3 = MPEG1
		layer := (h >> 17) & 0x3    // 1 = Layer3
		bitrateIdx := (h >> 12) & 0xF
		sampleIdx := (h >> 10) & 0x3

		if version != 3 || layer != 1 {
			continue
		}

		// MPEG1 Layer3 bitrate table (kbps), index 0 = free/invalid
		bitrates := [16]int{0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0}
		// MPEG1 sample rate table (Hz)
		sampleRates := [4]int{44100, 48000, 32000, 0}

		bitrate := bitrates[bitrateIdx] * 1000
		sampleRate := sampleRates[sampleIdx]
		if bitrate == 0 || sampleRate == 0 {
			continue
		}

		audioBytes := len(data) - offset
		duration := float64(audioBytes) * 8.0 / float64(bitrate)
		return math.Round(duration*1000) / 1000
	}

	// Fallback: assume 128 kbps CBR
	return math.Round(float64(len(data))*8.0/128_000.0*1000) / 1000
}

// skipID3v2 returns the byte offset past an ID3v2 header, or 0 if none.
func skipID3v2(data []byte) int {
	if len(data) < 10 || string(data[0:3]) != "ID3" {
		return 0
	}
	// ID3v2 size is a 28-bit synchsafe integer in bytes 6-9
	size := int(data[6])<<21 | int(data[7])<<14 | int(data[8])<<7 | int(data[9])
	return 10 + size
}
