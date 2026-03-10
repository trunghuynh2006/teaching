from app.scene_rules.base import SceneRule
from app.scene_rules.edit_sentence import EditSentenceRule
from app.scene_rules.title_scene import TitleSceneRule

REGISTRY: dict[str, SceneRule] = {
    "title_scene": TitleSceneRule(),
    "edit_sentence": EditSentenceRule(),
}


def get_rule(scene_type: str) -> SceneRule:
    rule = REGISTRY.get(scene_type)
    if rule is None:
        raise ValueError(f"Unknown scene type: '{scene_type}'. Register it in scene_rules/")
    return rule
