"""Steps 3 & 4 – Generate TTS audio and measure segment durations.

Uses OpenAI TTS API (tts-1 model) to produce per-segment MP3 files, then
reads duration via mutagen.  Falls back to a bitrate estimate if mutagen fails.

The full audio track is assembled by concatenating raw MP3 bytes – no ffmpeg
dependency required.  For production-quality gapless audio consider pydub/ffmpeg.
"""

from pathlib import Path

from openai import AsyncOpenAI

from app.models import AudioSegment, NarrationSegment


async def generate_tts(
    segments: list[NarrationSegment],
    lesson_id: str,
    output_dir: Path,
    client: AsyncOpenAI,
    voice: str = "alloy",
) -> list[AudioSegment]:
    """Step 3: call OpenAI TTS for each segment and save MP3 files.
    Step 4: measure each file's duration.
    Returns AudioSegments with duration_sec set; start will be filled by timeline step.
    """
    audio_dir = output_dir / lesson_id / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)

    result: list[AudioSegment] = []
    for seg in segments:
        file_path = audio_dir / f"{seg.segment_id}.mp3"

        response = await client.audio.speech.create(
            model="tts-1",
            voice=voice,
            input=seg.text,
            response_format="mp3",
        )
        file_path.write_bytes(response.content)

        duration = _measure_duration(file_path)
        result.append(
            AudioSegment(
                segment_id=seg.segment_id,
                text=seg.text,
                audio_file=f"audio/{seg.segment_id}.mp3",
                duration_sec=duration,
                start=0.0,  # assigned by the timeline step
            )
        )

    return result


def concatenate_audio(
    segments: list[AudioSegment],
    lesson_id: str,
    output_dir: Path,
) -> str:
    """Concatenate individual MP3 files into a single full.mp3.

    Returns the relative path string stored in the video plan.
    """
    audio_dir = output_dir / lesson_id / "audio"
    full_path = audio_dir / "full.mp3"

    with open(full_path, "wb") as out:
        for seg in segments:
            part = output_dir / lesson_id / seg.audio_file
            out.write(part.read_bytes())

    return "audio/full.mp3"


def _measure_duration(file_path: Path) -> float:
    """Return MP3 duration in seconds.

    Primary: mutagen reads VBR/CBR headers accurately.
    Fallback: estimate from file size at 128 kbps.
    """
    try:
        from mutagen.mp3 import MP3

        info = MP3(str(file_path)).info
        return round(info.length, 3)
    except Exception:
        size_bytes = file_path.stat().st_size
        return round(size_bytes * 8 / 128_000, 3)
