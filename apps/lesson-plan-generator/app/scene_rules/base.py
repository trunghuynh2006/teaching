from abc import ABC, abstractmethod
from typing import Any

from app.models import AudioSegment, SceneScript


class SceneRule(ABC):
    """Base class for scene-type rules.

    Each subclass knows how to turn a SceneScript + audio timing into
    a scene dict for the final VideoPlan.

    To add a new scene type:
      1. Subclass SceneRule and implement `build`.
      2. Register the instance in scene_rules/__init__.py REGISTRY.
    """

    @abstractmethod
    def build(
        self,
        script: SceneScript,
        audio_segments: list[AudioSegment],
        scene_start: float,
        scene_duration: float,
    ) -> dict[str, Any]:
        """Return a fully-timed scene dict."""
        ...
