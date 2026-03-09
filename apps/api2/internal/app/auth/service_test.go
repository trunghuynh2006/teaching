package auth_test

import (
	"context"
	"errors"
	"testing"

	"api2/internal/app/auth"
	"api2/internal/domain/user"
)

// --- mocks ---

type mockUsers struct {
	users map[string]user.User
}

func (m *mockUsers) GetByUsername(_ context.Context, username string) (user.User, error) {
	u, ok := m.users[username]
	if !ok {
		return user.User{}, user.ErrNotFound
	}
	return u, nil
}

type mockPassword struct {
	shouldFail bool
}

func (m *mockPassword) Verify(_, _ string) error {
	if m.shouldFail {
		return errors.New("wrong password")
	}
	return nil
}

type mockTokens struct {
	token      string
	subject    string
	createErr  error
	parseErr   error
}

func (m *mockTokens) CreateAccessToken(_, _ string) (string, error) {
	return m.token, m.createErr
}

func (m *mockTokens) ParseSubject(_ string) (string, error) {
	return m.subject, m.parseErr
}

// --- helpers ---

func newService(users map[string]user.User, pwFail bool, token, subject string) auth.Service {
	return auth.Service{
		Users:    &mockUsers{users: users},
		Password: &mockPassword{shouldFail: pwFail},
		Tokens:   &mockTokens{token: token, subject: subject},
	}
}

func seedUser() map[string]user.User {
	return map[string]user.User{
		"alice": {ID: 1, Username: "alice", FullName: "Alice Wonder", Role: "teacher", HashedPassword: "hashed"},
	}
}

// --- Login tests ---

func TestLogin_Success(t *testing.T) {
	svc := newService(seedUser(), false, "tok123", "alice")
	out, err := svc.Login(context.Background(), auth.LoginInput{Username: "alice", Password: "secret"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if out.AccessToken != "tok123" {
		t.Errorf("token = %q, want %q", out.AccessToken, "tok123")
	}
	if out.TokenType != "bearer" {
		t.Errorf("token_type = %q, want bearer", out.TokenType)
	}
	if out.User.Username != "alice" {
		t.Errorf("user.Username = %q, want alice", out.User.Username)
	}
}

func TestLogin_UnknownUser(t *testing.T) {
	svc := newService(seedUser(), false, "", "")
	_, err := svc.Login(context.Background(), auth.LoginInput{Username: "nobody", Password: "x"})
	if !errors.Is(err, auth.ErrInvalidCredentials) {
		t.Errorf("err = %v, want ErrInvalidCredentials", err)
	}
}

func TestLogin_WrongPassword(t *testing.T) {
	svc := newService(seedUser(), true, "", "")
	_, err := svc.Login(context.Background(), auth.LoginInput{Username: "alice", Password: "wrong"})
	if !errors.Is(err, auth.ErrInvalidCredentials) {
		t.Errorf("err = %v, want ErrInvalidCredentials", err)
	}
}

// --- Authenticate tests ---

func TestAuthenticate_Success(t *testing.T) {
	svc := newService(seedUser(), false, "", "alice")
	u, err := svc.Authenticate(context.Background(), "validtoken")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if u.Username != "alice" {
		t.Errorf("username = %q, want alice", u.Username)
	}
}

func TestAuthenticate_InvalidToken(t *testing.T) {
	svc := auth.Service{
		Users:    &mockUsers{users: seedUser()},
		Password: &mockPassword{},
		Tokens:   &mockTokens{parseErr: errors.New("bad token")},
	}
	_, err := svc.Authenticate(context.Background(), "garbage")
	if !errors.Is(err, auth.ErrInvalidToken) {
		t.Errorf("err = %v, want ErrInvalidToken", err)
	}
}

func TestAuthenticate_UserDisappeared(t *testing.T) {
	svc := auth.Service{
		Users:    &mockUsers{users: map[string]user.User{}},
		Password: &mockPassword{},
		Tokens:   &mockTokens{subject: "ghost"},
	}
	_, err := svc.Authenticate(context.Background(), "tok")
	if !errors.Is(err, auth.ErrUserNotFound) {
		t.Errorf("err = %v, want ErrUserNotFound", err)
	}
}
