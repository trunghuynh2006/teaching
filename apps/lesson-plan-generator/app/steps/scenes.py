"""Step 5 – Map scene scripts to (script, duration) pairs.

Duration for scenes with narration = sum of their assigned audio segment durations.
Duration for scenes without narration (e.g. title_scene) = data["duration"] field.
"""

from app.models import AudioSegment, SceneScript


def generate_scenes(
    scene_scripts: list[SceneScript],
    audio_segments: list[AudioSegment],
) -> list[tuple[SceneScript, float]]:
    seg_dur: dict[str, float] = {s.segment_id: s.duration_sec for s in audio_segments}

    result: list[tuple[SceneScript, float]] = []
    for script in scene_scripts:
        if script.narration_segment_ids:
            duration = sum(seg_dur[sid] for sid in script.narration_segment_ids if sid in seg_dur)
        else:
            duration = float(script.data.get("duration", 3.0))
        result.append((script, duration))

    return result
