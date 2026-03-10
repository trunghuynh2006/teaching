from typing import Any

from app.models import AudioSegment, SceneScript
from app.scene_rules.base import SceneRule


class EditSentenceRule(SceneRule):
    """Shows an original sentence, highlights a weak phrase, then replaces it.

    Expected SceneScript.data keys:
      original_text    : str  – sentence shown at scene start
      replacement_text : str  – cleaner version revealed at replace_at
      highlight_phrase : str  – substring of original_text to highlight
      highlight_at     : float – seconds after scene_start to highlight (default 1.2)
      replace_at       : float – seconds after scene_start to swap sentence (default 2.0)
    """

    def build(
        self,
        script: SceneScript,
        audio_segments: list[AudioSegment],
        scene_start: float,
        scene_duration: float,
    ) -> dict[str, Any]:
        data = script.data
        highlight_at = round(scene_start + data.get("highlight_at", 1.2), 3)
        replace_at = round(scene_start + data.get("replace_at", 2.0), 3)

        events: list[dict[str, Any]] = [
            {"time": scene_start, "action": "show_original"},
            {"time": highlight_at, "action": "highlight_phrase", "text": data.get("highlight_phrase", "")},
            {"time": replace_at, "action": "replace_sentence"},
        ]

        return {
            "scene_id": script.scene_id,
            "scene_type": "edit_sentence",
            "start": scene_start,
            "duration": scene_duration,
            "original_text": data.get("original_text", ""),
            "replacement_text": data.get("replacement_text", ""),
            "events": events,
        }
