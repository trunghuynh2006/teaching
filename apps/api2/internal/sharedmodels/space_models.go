package sharedmodels

// Space is a typed collection inside a folder.
type Space struct {
	Id          string  `json:"id"`
	FolderId    string  `json:"folder_id"`
	Name        string  `json:"name"`
	SpaceType   *string `json:"space_type,omitempty"`
	Description *string `json:"description,omitempty"`
	CreatedBy   *string `json:"created_by,omitempty"`
	UpdatedBy   *string `json:"updated_by,omitempty"`
	CreatedTime *string `json:"created_time,omitempty"`
	UpdatedTime *string `json:"updated_time,omitempty"`
}

// Question belongs to a Space.
type Question struct {
	Id           string   `json:"id"`
	SpaceId      string   `json:"space_id"`
	QuestionType string   `json:"question_type"`
	Body         string   `json:"body"`
	Answers      []Answer `json:"answers,omitempty"`
	CreatedBy    *string  `json:"created_by,omitempty"`
	UpdatedBy    *string  `json:"updated_by,omitempty"`
	CreatedTime  *string  `json:"created_time,omitempty"`
	UpdatedTime  *string  `json:"updated_time,omitempty"`
}

// Answer is one option within a Question.
type Answer struct {
	Id          string  `json:"id"`
	QuestionId  string  `json:"question_id"`
	Text        string  `json:"text"`
	IsCorrect   bool    `json:"is_correct"`
	Position    *int    `json:"position,omitempty"`
	CreatedBy   *string `json:"created_by,omitempty"`
	UpdatedBy   *string `json:"updated_by,omitempty"`
	CreatedTime *string `json:"created_time,omitempty"`
	UpdatedTime *string `json:"updated_time,omitempty"`
}

// Problem is a worked problem attached to a Space.
type Problem struct {
	Id          string        `json:"id"`
	SpaceId     string        `json:"space_id"`
	Question    string        `json:"question"`
	Solution    string        `json:"solution"`
	Steps       []ProblemStep `json:"steps,omitempty"`
	CreatedBy   *string       `json:"created_by,omitempty"`
	UpdatedBy   *string       `json:"updated_by,omitempty"`
	CreatedTime *string       `json:"created_time,omitempty"`
	UpdatedTime *string       `json:"updated_time,omitempty"`
}

// ProblemStep is one step in the solution of a Problem.
type ProblemStep struct {
	Id          string  `json:"id"`
	ProblemId   string  `json:"problem_id"`
	Body        string  `json:"body"`
	Position    *int    `json:"position,omitempty"`
	CreatedBy   *string `json:"created_by,omitempty"`
	UpdatedBy   *string `json:"updated_by,omitempty"`
	CreatedTime *string `json:"created_time,omitempty"`
	UpdatedTime *string `json:"updated_time,omitempty"`
}

// FlashCard belongs to a Space.
type FlashCard struct {
	Id          string  `json:"id"`
	SpaceId     string  `json:"space_id"`
	Front       string  `json:"front"`
	Back        string  `json:"back"`
	CreatedBy   *string `json:"created_by,omitempty"`
	UpdatedBy   *string `json:"updated_by,omitempty"`
	CreatedTime *string `json:"created_time,omitempty"`
	UpdatedTime *string `json:"updated_time,omitempty"`
}
