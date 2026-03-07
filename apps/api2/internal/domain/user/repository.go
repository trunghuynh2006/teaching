package user

import (
	"context"
	"errors"
)

var ErrNotFound = errors.New("user not found")

type Repository interface {
	GetByUsername(ctx context.Context, username string) (User, error)
}
