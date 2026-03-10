"""Step 2 – Split narration into segments.

Currently returns the pre-defined segments from the lesson fixture.
Future: accept a single narration string and auto-split on sentence boundaries.
"""

from app.models import LessonContent, NarrationSegment


def split_narration(lesson: LessonContent) -> list[NarrationSegment]:
    return lesson.narration
