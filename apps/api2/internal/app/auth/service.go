package auth

import (
	"context"
	"errors"

	domainauth "api2/internal/domain/auth"
	"api2/internal/domain/user"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrInvalidToken       = errors.New("invalid token")
	ErrUserNotFound       = errors.New("user not found")
)

type Service struct {
	Users    user.Repository
	Password domainauth.PasswordVerifier
	Tokens   domainauth.TokenManager
}

type LoginInput struct {
	Username string
	Password string
}

type LoginOutput struct {
	AccessToken string
	TokenType   string
	User        user.PublicUser
}

func (s Service) Login(ctx context.Context, input LoginInput) (LoginOutput, error) {
	u, err := s.Users.GetByUsername(ctx, input.Username)
	if err != nil {
		if errors.Is(err, user.ErrNotFound) {
			return LoginOutput{}, ErrInvalidCredentials
		}
		return LoginOutput{}, err
	}

	if err := s.Password.Verify(u.HashedPassword, input.Password); err != nil {
		return LoginOutput{}, ErrInvalidCredentials
	}

	token, err := s.Tokens.CreateAccessToken(u.Username, u.Role)
	if err != nil {
		return LoginOutput{}, err
	}

	return LoginOutput{
		AccessToken: token,
		TokenType:   "bearer",
		User:        u.Public(),
	}, nil
}

func (s Service) Authenticate(ctx context.Context, bearerToken string) (user.User, error) {
	subject, err := s.Tokens.ParseSubject(bearerToken)
	if err != nil {
		return user.User{}, ErrInvalidToken
	}

	u, err := s.Users.GetByUsername(ctx, subject)
	if err != nil {
		if errors.Is(err, user.ErrNotFound) {
			return user.User{}, ErrUserNotFound
		}
		return user.User{}, err
	}

	return u, nil
}
