package domain

// ---------------------------------------------------------------------------
// Internal lesson types (pipeline input)
// ---------------------------------------------------------------------------

type NarrationSegment struct {
	SegmentID string `json:"segment_id"`
	Text      string `json:"text"`
}

type SceneScript struct {
	SceneID             string         `json:"scene_id"`
	SceneType           string         `json:"scene_type"`
	NarrationSegmentIDs []string       `json:"narration_segment_ids"`
	Data                map[string]any `json:"data"`
}

type LessonContent struct {
	LessonID     string            `json:"lesson_id"`
	Title        string            `json:"title"`
	Narration    []NarrationSegment `json:"narration"`
	SceneScripts []SceneScript     `json:"scene_scripts"`
}

// ---------------------------------------------------------------------------
// Output types (video plan JSON contract)
// ---------------------------------------------------------------------------

type AudioSegment struct {
	SegmentID   string  `json:"segment_id"`
	Text        string  `json:"text"`
	AudioFile   string  `json:"audio_file"`
	DurationSec float64 `json:"duration_sec"`
	Start       float64 `json:"start"`
}

type AudioTrack struct {
	Segments      []AudioSegment `json:"segments"`
	FullAudioFile string         `json:"full_audio_file"`
	TotalDuration float64        `json:"total_duration"`
}

type VideoPlan struct {
	LessonID   string           `json:"lesson_id"`
	AudioTrack AudioTrack       `json:"audio_track"`
	Scenes     []map[string]any `json:"scenes"`
}
