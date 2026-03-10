from typing import Any

from app.models import AudioSegment, SceneScript
from app.scene_rules.base import SceneRule


class TitleSceneRule(SceneRule):
    def build(
        self,
        script: SceneScript,
        audio_segments: list[AudioSegment],
        scene_start: float,
        scene_duration: float,
    ) -> dict[str, Any]:
        return {
            "scene_id": script.scene_id,
            "scene_type": "title_scene",
            "start": scene_start,
            "duration": scene_duration,
            "title": script.data.get("title", ""),
        }
