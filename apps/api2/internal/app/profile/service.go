package profile

import "errors"

var (
	ErrNotFound  = errors.New("not found")
	ErrForbidden = errors.New("forbidden")
)

type Service struct{}

func (s Service) RoleData(currentRole, requestedRole string) (map[string]any, error) {
	if requestedRole == "" {
		return nil, ErrNotFound
	}

	if currentRole != requestedRole {
		return nil, ErrForbidden
	}

	data := map[string]map[string]any{
		"learner": {"message": "Learner-specific data", "tasks_due": 4},
		"teacher": {"message": "Teacher-specific data", "classes_today": 3},
		"admin":   {"message": "Admin-specific data", "open_alerts": 1},
		"parent":  {"message": "Parent-specific data", "children_linked": 2},
	}

	roleData, ok := data[requestedRole]
	if !ok {
		return map[string]any{}, nil
	}

	return roleData, nil
}
