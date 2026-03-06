-- name: InitUsersTable :exec
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(64) UNIQUE NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    role VARCHAR(20) NOT NULL,
    hashed_password VARCHAR(255) NOT NULL
);

-- name: InitUsersUsernameIndex :exec
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

-- name: InitUsersRoleIndex :exec
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);

-- name: GetUserByUsername :one
SELECT id, username, full_name, role, hashed_password
FROM users
WHERE username = $1
LIMIT 1;

-- name: GetUserHashByUsername :one
SELECT hashed_password
FROM users
WHERE username = $1
LIMIT 1;

-- name: CreateUser :exec
INSERT INTO users (username, full_name, role, hashed_password)
VALUES ($1, $2, $3, $4);

-- name: UpdateUserByUsername :exec
UPDATE users
SET full_name = $1, role = $2, hashed_password = $3
WHERE username = $4;
