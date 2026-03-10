"""Step 6 – Compute animation timeline.

Audio segments: start times are relative to the audio file (0-based).
Scenes:         start times are in the video timeline (scenes are sequential).

The two timelines are independent:
  - The audio track plays from t=0 in the audio file.
  - The video renderer starts the audio track when the first narration scene begins.
  Scene event times (e.g. highlight_phrase) are in video timeline coordinates.
"""

from app.models import AudioSegment, SceneScript
from app.scene_rules import get_rule


def compute_timeline(
    scene_data: list[tuple[SceneScript, float]],
    audio_segments: list[AudioSegment],
) -> tuple[list[dict], list[AudioSegment]]:
    """Returns (scenes, timed_audio_segments)."""

    # --- Audio track: assign start times within the audio file ---
    audio_cursor = 0.0
    seg_map: dict[str, AudioSegment] = {}
    timed_segments: list[AudioSegment] = []
    for seg in audio_segments:
        timed = seg.model_copy(update={"start": round(audio_cursor, 3)})
        seg_map[seg.segment_id] = timed
        timed_segments.append(timed)
        audio_cursor += seg.duration_sec

    # --- Video timeline: assign scene start times sequentially ---
    video_cursor = 0.0
    scenes: list[dict] = []
    for script, duration in scene_data:
        rule = get_rule(script.scene_type)

        scene_audio = [seg_map[sid] for sid in script.narration_segment_ids if sid in seg_map]
        scene = rule.build(script, scene_audio, round(video_cursor, 3), round(duration, 3))
        scenes.append(scene)
        video_cursor += duration

    return scenes, timed_segments
