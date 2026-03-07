package postgres

import (
	"context"
	"errors"

	"api2/internal/domain/user"
	"api2/internal/store"

	"github.com/jackc/pgx/v5"
)

type UserRepository struct {
	Queries *store.Queries
}

func (r UserRepository) GetByUsername(ctx context.Context, username string) (user.User, error) {
	record, err := r.Queries.GetUserByUsername(ctx, username)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return user.User{}, user.ErrNotFound
		}
		return user.User{}, err
	}

	return user.User{
		ID:             int(record.ID),
		Username:       record.Username,
		FullName:       record.FullName,
		Role:           record.Role,
		HashedPassword: record.HashedPassword,
	}, nil
}
