"""Step 7 – Assemble the final VideoPlan JSON contract."""

from app.models import AudioSegment, AudioTrack, VideoPlan


def assemble(
    lesson_id: str,
    audio_segments: list[AudioSegment],
    full_audio_file: str,
    scenes: list[dict],
) -> VideoPlan:
    total_duration = round(sum(s.duration_sec for s in audio_segments), 3)

    audio_track = AudioTrack(
        segments=audio_segments,
        full_audio_file=full_audio_file,
        total_duration=total_duration,
    )

    return VideoPlan(
        lesson_id=lesson_id,
        audio_track=audio_track,
        scenes=scenes,
    )
