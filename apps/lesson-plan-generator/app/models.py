from typing import Any

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Internal lesson models (pipeline input)
# ---------------------------------------------------------------------------


class NarrationSegment(BaseModel):
    segment_id: str
    text: str


class SceneScript(BaseModel):
    """One scene's script: which narration segments it uses and type-specific config."""

    scene_id: str
    scene_type: str
    narration_segment_ids: list[str] = []
    data: dict[str, Any] = {}


class LessonContent(BaseModel):
    lesson_id: str
    title: str
    narration: list[NarrationSegment]
    scene_scripts: list[SceneScript]


# ---------------------------------------------------------------------------
# Output models (video plan JSON contract)
# ---------------------------------------------------------------------------


class AudioSegment(BaseModel):
    segment_id: str
    text: str
    audio_file: str
    duration_sec: float
    start: float


class AudioTrack(BaseModel):
    segments: list[AudioSegment]
    full_audio_file: str
    total_duration: float


class VideoPlan(BaseModel):
    lesson_id: str
    audio_track: AudioTrack
    scenes: list[dict[str, Any]]
