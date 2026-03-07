package user

type User struct {
	ID             int
	Username       string
	FullName       string
	Role           string
	HashedPassword string
}

type PublicUser struct {
	ID       int    `json:"id"`
	Username string `json:"username"`
	FullName string `json:"full_name"`
	Role     string `json:"role"`
}

func (u User) Public() PublicUser {
	return PublicUser{
		ID:       u.ID,
		Username: u.Username,
		FullName: u.FullName,
		Role:     u.Role,
	}
}
