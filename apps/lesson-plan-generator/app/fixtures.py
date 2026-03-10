"""Hard-coded lesson fixtures.

Replace with a database/API loader when lessons are stored externally.
"""

from app.models import LessonContent, NarrationSegment, SceneScript

LESSONS: dict[str, LessonContent] = {
    "email_clear_requests": LessonContent(
        lesson_id="email_clear_requests",
        title="Writing Clear Emails",
        narration=[
            NarrationSegment(
                segment_id="s1",
                text="Many emails begin with unnecessary apologies.",
            ),
            NarrationSegment(
                segment_id="s2",
                text="These phrases weaken the message.",
            ),
            NarrationSegment(
                segment_id="s3",
                text="Instead of saying sorry to bother you, get straight to the point.",
            ),
            NarrationSegment(
                segment_id="s4",
                text="Compare these two versions of the same request.",
            ),
            NarrationSegment(
                segment_id="s5",
                text="The second version is shorter, clearer, and more confident.",
            ),
        ],
        scene_scripts=[
            SceneScript(
                scene_id="scene_1",
                scene_type="title_scene",
                narration_segment_ids=[],
                data={
                    "title": "Writing Clear Emails",
                    "duration": 3.0,
                },
            ),
            SceneScript(
                scene_id="scene_2",
                scene_type="edit_sentence",
                narration_segment_ids=["s1", "s2"],
                data={
                    "original_text": "Sorry to bother you but I was wondering if we could move the meeting.",
                    "replacement_text": "Can we move the meeting?",
                    "highlight_phrase": "Sorry to bother you",
                    # seconds after scene start
                    "highlight_at": 1.2,
                    "replace_at": 2.0,
                },
            ),
            SceneScript(
                scene_id="scene_3",
                scene_type="edit_sentence",
                narration_segment_ids=["s3", "s4", "s5"],
                data={
                    "original_text": "I was just wondering if maybe you had a chance to look at my proposal.",
                    "replacement_text": "Have you reviewed my proposal?",
                    "highlight_phrase": "I was just wondering if maybe",
                    "highlight_at": 1.5,
                    "replace_at": 2.5,
                },
            ),
        ],
    ),
}
