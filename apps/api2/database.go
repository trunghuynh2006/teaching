package main

import (
	"context"
	"errors"
	"strings"

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
	const createUsersTableSQL = `
		CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			username VARCHAR(64) UNIQUE NOT NULL,
			full_name VARCHAR(120) NOT NULL,
			role VARCHAR(20) NOT NULL,
			hashed_password VARCHAR(255) NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
		CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
	`

	if _, err := a.db.Exec(ctx, createUsersTableSQL); err != nil {
		return err
	}

	return nil
}

func (a *app) seedUsers(ctx context.Context) error {
	for _, demo := range demoUsers {
		var existingHash string
		err := a.db.QueryRow(ctx, "SELECT hashed_password FROM users WHERE username=$1", demo.Username).Scan(&existingHash)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				hashedPassword, hashErr := bcrypt.GenerateFromPassword([]byte(demo.Password), bcrypt.DefaultCost)
				if hashErr != nil {
					return hashErr
				}

				_, insertErr := a.db.Exec(
					ctx,
					"INSERT INTO users (username, full_name, role, hashed_password) VALUES ($1, $2, $3, $4)",
					demo.Username,
					demo.FullName,
					demo.Role,
					string(hashedPassword),
				)
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

		_, err = a.db.Exec(
			ctx,
			"UPDATE users SET full_name=$1, role=$2, hashed_password=$3 WHERE username=$4",
			demo.FullName,
			demo.Role,
			string(hashedPassword),
			demo.Username,
		)
		if err != nil {
			return err
		}
	}

	return nil
}
