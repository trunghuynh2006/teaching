package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"golang.org/x/crypto/bcrypt"
)

type app struct {
	db               *pgxpool.Pool
	jwtSecret        string
	jwtAlgorithm     string
	jwtExpireMinutes int
	allowedOrigin    string
}

type user struct {
	ID             int    `json:"id"`
	Username       string `json:"username"`
	FullName       string `json:"full_name"`
	Role           string `json:"role"`
	HashedPassword string `json:"-"`
}

type loginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type loginResponse struct {
	AccessToken string `json:"access_token"`
	TokenType   string `json:"token_type"`
	User        user   `json:"user"`
}

type errorResponse struct {
	Detail string `json:"detail"`
}

type rolePayload struct {
	Role string         `json:"role"`
	Data map[string]any `json:"data"`
}

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

func main() {
	_ = godotenv.Load()

	databaseURL := getenv("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/study_platform?sslmode=disable")
	jwtSecret := getenv("JWT_SECRET", "change_me_in_production")
	jwtAlgorithm := getenv("JWT_ALGORITHM", "HS256")
	jwtExpireMinutes := getenvInt("JWT_EXPIRE_MINUTES", 120)
	port := getenv("PORT", "8000")

	ctx := context.Background()
	db, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatalf("failed to connect to db: %v", err)
	}
	defer db.Close()

	application := &app{
		db:               db,
		jwtSecret:        jwtSecret,
		jwtAlgorithm:     jwtAlgorithm,
		jwtExpireMinutes: jwtExpireMinutes,
		allowedOrigin:    "http://localhost:5173",
	}

	if err := application.initDB(ctx); err != nil {
		log.Fatalf("failed to initialize db: %v", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", application.health)
	mux.HandleFunc("POST /auth/login", application.login)
	mux.HandleFunc("GET /me", application.auth(application.me))
	mux.HandleFunc("GET /role/", application.auth(application.roleData))

	handler := application.cors(mux)
	addr := fmt.Sprintf(":%s", port)
	log.Printf("api2 listening on %s", addr)
	if err := http.ListenAndServe(addr, handler); err != nil {
		log.Fatalf("server stopped: %v", err)
	}
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

	return a.seedUsers(ctx)
}

func (a *app) seedUsers(ctx context.Context) error {
	for _, demo := range demoUsers {
		var exists bool
		err := a.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM users WHERE username=$1)", demo.Username).Scan(&exists)
		if err != nil {
			return err
		}
		if exists {
			continue
		}

		hashedPassword, err := bcrypt.GenerateFromPassword([]byte(demo.Password), bcrypt.DefaultCost)
		if err != nil {
			return err
		}

		_, err = a.db.Exec(
			ctx,
			"INSERT INTO users (username, full_name, role, hashed_password) VALUES ($1, $2, $3, $4)",
			demo.Username,
			demo.FullName,
			demo.Role,
			string(hashedPassword),
		)
		if err != nil {
			return err
		}
	}

	return nil
}

func (a *app) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (a *app) login(w http.ResponseWriter, r *http.Request) {
	var payload loginRequest
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeJSON(w, http.StatusBadRequest, errorResponse{Detail: "Invalid request body"})
		return
	}

	u, err := a.getUserByUsername(r.Context(), payload.Username)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeJSON(w, http.StatusUnauthorized, errorResponse{Detail: "Invalid username or password"})
			return
		}
		writeJSON(w, http.StatusInternalServerError, errorResponse{Detail: "Internal server error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(u.HashedPassword), []byte(payload.Password)); err != nil {
		writeJSON(w, http.StatusUnauthorized, errorResponse{Detail: "Invalid username or password"})
		return
	}

	token, err := a.createAccessToken(u.Username, u.Role)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, errorResponse{Detail: "Internal server error"})
		return
	}

	writeJSON(w, http.StatusOK, loginResponse{
		AccessToken: token,
		TokenType:   "bearer",
		User: user{
			ID:       u.ID,
			Username: u.Username,
			FullName: u.FullName,
			Role:     u.Role,
		},
	})
}

func (a *app) me(w http.ResponseWriter, r *http.Request, currentUser user) {
	writeJSON(w, http.StatusOK, user{
		ID:       currentUser.ID,
		Username: currentUser.Username,
		FullName: currentUser.FullName,
		Role:     currentUser.Role,
	})
}

func (a *app) roleData(w http.ResponseWriter, r *http.Request, currentUser user) {
	roleName := strings.TrimPrefix(r.URL.Path, "/role/")
	if roleName == "" {
		writeJSON(w, http.StatusNotFound, errorResponse{Detail: "Not found"})
		return
	}

	if currentUser.Role != roleName {
		writeJSON(w, http.StatusForbidden, errorResponse{Detail: "Forbidden for this role"})
		return
	}

	data := map[string]map[string]any{
		"learner": {"message": "Learner-specific data", "tasks_due": 4},
		"teacher": {"message": "Teacher-specific data", "classes_today": 3},
		"admin":   {"message": "Admin-specific data", "open_alerts": 1},
		"parent":  {"message": "Parent-specific data", "children_linked": 2},
	}

	roleData, ok := data[roleName]
	if !ok {
		roleData = map[string]any{}
	}

	writeJSON(w, http.StatusOK, rolePayload{Role: roleName, Data: roleData})
}

func (a *app) getUserByUsername(ctx context.Context, username string) (user, error) {
	const query = `
		SELECT id, username, full_name, role, hashed_password
		FROM users
		WHERE username = $1
	`

	var u user
	err := a.db.QueryRow(ctx, query, username).Scan(&u.ID, &u.Username, &u.FullName, &u.Role, &u.HashedPassword)
	if err != nil {
		return user{}, err
	}

	return u, nil
}

func (a *app) createAccessToken(subject, role string) (string, error) {
	expiresAt := time.Now().UTC().Add(time.Duration(a.jwtExpireMinutes) * time.Minute)

	method := jwt.GetSigningMethod(a.jwtAlgorithm)
	if method == nil {
		return "", fmt.Errorf("unsupported jwt algorithm: %s", a.jwtAlgorithm)
	}

	token := jwt.NewWithClaims(method, jwt.MapClaims{
		"sub":  subject,
		"role": role,
		"exp":  expiresAt.Unix(),
	})

	return token.SignedString([]byte(a.jwtSecret))
}

func (a *app) parseToken(tokenString string) (string, error) {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (any, error) {
		if token.Method.Alg() != a.jwtAlgorithm {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return []byte(a.jwtSecret), nil
	})
	if err != nil || !token.Valid {
		return "", errors.New("invalid token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return "", errors.New("invalid token payload")
	}

	sub, ok := claims["sub"].(string)
	if !ok || sub == "" {
		return "", errors.New("invalid token payload")
	}

	return sub, nil
}

type authedHandler func(http.ResponseWriter, *http.Request, user)

func (a *app) auth(next authedHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		parts := strings.SplitN(authHeader, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") || strings.TrimSpace(parts[1]) == "" {
			writeJSON(w, http.StatusUnauthorized, errorResponse{Detail: "Invalid token"})
			return
		}

		username, err := a.parseToken(parts[1])
		if err != nil {
			writeJSON(w, http.StatusUnauthorized, errorResponse{Detail: "Invalid token"})
			return
		}

		currentUser, err := a.getUserByUsername(r.Context(), username)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				writeJSON(w, http.StatusUnauthorized, errorResponse{Detail: "User not found"})
				return
			}
			writeJSON(w, http.StatusInternalServerError, errorResponse{Detail: "Internal server error"})
			return
		}

		next(w, r, currentUser)
	}
}

func (a *app) cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin == a.allowedOrigin {
			w.Header().Set("Access-Control-Allow-Origin", origin)
			w.Header().Set("Access-Control-Allow-Credentials", "true")
			w.Header().Set("Vary", "Origin")
		}
		w.Header().Set("Access-Control-Allow-Methods", "GET,POST,PUT,PATCH,DELETE,OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization,Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		http.Error(w, "failed to encode response", http.StatusInternalServerError)
	}
}

func getenv(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}

func getenvInt(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}

	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}

	return parsed
}
