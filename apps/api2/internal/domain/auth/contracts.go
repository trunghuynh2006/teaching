package auth

type PasswordVerifier interface {
	Verify(hashed, plain string) error
}

type TokenManager interface {
	CreateAccessToken(subject, role string) (string, error)
	ParseSubject(token string) (string, error)
}
