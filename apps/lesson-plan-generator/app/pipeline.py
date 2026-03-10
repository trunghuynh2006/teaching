"""Orchestrates all pipeline steps in order."""

from pathlib import Path

from openai import AsyncOpenAI

from app.models import VideoPlan
from app.steps.assembler import assemble
from app.steps.loader import load_lesson
from app.steps.narration import split_narration
from app.steps.scenes import generate_scenes
from app.steps.timeline import compute_timeline
from app.steps.tts import concatenate_audio, generate_tts


async def generate_plan(
    lesson_id: str,
    output_dir: Path,
    openai_client: AsyncOpenAI,
    tts_voice: str = "alloy",
) -> VideoPlan:
    # 1. Load lesson
    lesson = load_lesson(lesson_id)

    # 2. Split narration into segments
    narration_segments = split_narration(lesson)

    # 3 & 4. Generate TTS audio files + measure durations
    audio_segments = await generate_tts(
        narration_segments, lesson_id, output_dir, openai_client, tts_voice
    )

    # Concatenate segments into full audio track
    full_audio_file = concatenate_audio(audio_segments, lesson_id, output_dir)

    # 5. Map scene scripts → (script, duration)
    scene_data = generate_scenes(lesson.scene_scripts, audio_segments)

    # 6. Compute video timeline + assign audio start times
    scenes, timed_segments = compute_timeline(scene_data, audio_segments)

    # 7. Assemble final VideoPlan
    return assemble(lesson_id, timed_segments, full_audio_file, scenes)
