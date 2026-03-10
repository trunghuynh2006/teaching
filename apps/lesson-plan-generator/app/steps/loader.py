"""Step 1 – Load lesson content.

Currently loads from hard-coded fixtures.
Swap load_lesson's implementation to fetch from a database or API.
"""

from app.fixtures import LESSONS
from app.models import LessonContent


def load_lesson(lesson_id: str) -> LessonContent:
    lesson = LESSONS.get(lesson_id)
    if lesson is None:
        raise ValueError(f"Lesson '{lesson_id}' not found")
    return lesson
