package main

import (
	"context"
	"errors"
	"strings"

	"api2/internal/store"

	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

var demoUsers = []struct {
	Username string
	Password string
	FullName string
	Role     string
}{
	{Username: "learner_alex", Password: "Pass1234!", FullName: "Alex Kim", Role: "learner"},
	{Username: "learner_mia", Password: "Pass1234!", FullName: "Mia Johnson", Role: "learner"},
	{Username: "teacher_john", Password: "Teach1234!", FullName: "John Carter", Role: "teacher"},
	{Username: "teacher_nina", Password: "Teach1234!", FullName: "Nina Patel", Role: "teacher"},
	{Username: "admin_sara", Password: "Admin1234!", FullName: "Sara Lee", Role: "admin"},
	{Username: "admin_mike", Password: "Admin1234!", FullName: "Mike Brown", Role: "admin"},
	{Username: "parent_olivia", Password: "Parent1234!", FullName: "Olivia Wilson", Role: "parent"},
	{Username: "parent_david", Password: "Parent1234!", FullName: "David Taylor", Role: "parent"},
}

func (a *app) initDB(ctx context.Context) error {
	if err := a.queries.InitUsersTable(ctx); err != nil {
		return err
	}
	if err := a.queries.InitUsersUsernameIndex(ctx); err != nil {
		return err
	}
	if err := a.queries.InitUsersRoleIndex(ctx); err != nil {
		return err
	}

	return nil
}

func (a *app) seedUsers(ctx context.Context) error {
	for _, demo := range demoUsers {
		existingHash, err := a.queries.GetUserHashByUsername(ctx, demo.Username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				hashedPassword, hashErr := bcrypt.GenerateFromPassword([]byte(demo.Password), bcrypt.DefaultCost)
				if hashErr != nil {
					return hashErr
				}

				insertErr := a.queries.CreateUser(ctx, store.CreateUserParams{
					Username:       demo.Username,
					FullName:       demo.FullName,
					Role:           demo.Role,
					HashedPassword: string(hashedPassword),
				})
				if insertErr != nil {
					return insertErr
				}
				continue
			}
			return err
		}

		// Existing demo users from the old Python service may use passlib's
		// bcrypt_sha256 format, which Go's bcrypt verifier cannot read.
		if strings.HasPrefix(existingHash, "$2a$") || strings.HasPrefix(existingHash, "$2b$") || strings.HasPrefix(existingHash, "$2y$") {
			continue
		}

		hashedPassword, hashErr := bcrypt.GenerateFromPassword([]byte(demo.Password), bcrypt.DefaultCost)
		if hashErr != nil {
			return hashErr
		}

		err = a.queries.UpdateUserByUsername(ctx, store.UpdateUserByUsernameParams{
			FullName:       demo.FullName,
			Role:           demo.Role,
			HashedPassword: string(hashedPassword),
			Username:       demo.Username,
		})
		if err != nil {
			return err
		}
	}

	return nil
}
