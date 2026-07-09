package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	_ "modernc.org/sqlite"
)

var ErrNotFound = errors.New("not found")

type Device struct {
	ID                uuid.UUID
	InstallationID    *int64
	GitHubLogin       *string
	GitHubAccountType *string
	CreatedAt         time.Time
	UpdatedAt         time.Time
}

type OAuthState struct {
	State     string
	DeviceID  uuid.UUID
	ExpiresAt time.Time
	Completed bool
}

type Store struct {
	db *sql.DB
}

func New(ctx context.Context, databasePath string) (*Store, error) {
	if err := os.MkdirAll(filepath.Dir(databasePath), 0o755); err != nil {
		return nil, fmt.Errorf("create database directory: %w", err)
	}

	dsn := fmt.Sprintf("file:%s?_pragma=busy_timeout(5000)&_pragma=foreign_keys(ON)", databasePath)
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	db.SetMaxOpenConns(1)

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	return &Store{db: db}, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

func (s *Store) DB() *sql.DB {
	return s.db
}

func (s *Store) UpsertDevice(ctx context.Context, deviceID uuid.UUID, secretHash string) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO devices (id, secret_hash)
		VALUES (?, ?)
		ON CONFLICT(id) DO UPDATE SET
			secret_hash = excluded.secret_hash,
			updated_at = datetime('now')
	`, deviceID.String(), secretHash)
	return err
}

func (s *Store) GetDeviceSecretHash(ctx context.Context, deviceID uuid.UUID) (string, error) {
	var secretHash string
	err := s.db.QueryRowContext(ctx, `
		SELECT secret_hash FROM devices WHERE id = ?
	`, deviceID.String()).Scan(&secretHash)
	if errors.Is(err, sql.ErrNoRows) {
		return "", ErrNotFound
	}
	return secretHash, err
}

func (s *Store) GetDevice(ctx context.Context, deviceID uuid.UUID) (*Device, error) {
	var device Device
	var id string
	var installationID sql.NullInt64
	var githubLogin sql.NullString
	var githubAccountType sql.NullString
	var createdAt string
	var updatedAt string

	err := s.db.QueryRowContext(ctx, `
		SELECT id, installation_id, github_login, github_account_type, created_at, updated_at
		FROM devices
		WHERE id = ?
	`, deviceID.String()).Scan(
		&id,
		&installationID,
		&githubLogin,
		&githubAccountType,
		&createdAt,
		&updatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	parsedID, err := uuid.Parse(id)
	if err != nil {
		return nil, err
	}
	device.ID = parsedID
	device.InstallationID = nullInt64Ptr(installationID)
	device.GitHubLogin = nullStringPtr(githubLogin)
	device.GitHubAccountType = nullStringPtr(githubAccountType)
	device.CreatedAt, err = parseSQLiteTime(createdAt)
	if err != nil {
		return nil, err
	}
	device.UpdatedAt, err = parseSQLiteTime(updatedAt)
	if err != nil {
		return nil, err
	}

	return &device, nil
}

func (s *Store) CreateOAuthState(ctx context.Context, state string, deviceID uuid.UUID, expiresAt time.Time) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO oauth_states (state, device_id, expires_at)
		VALUES (?, ?, ?)
	`, state, deviceID.String(), expiresAt.UTC().Format(time.RFC3339))
	return err
}

func (s *Store) ConsumeOAuthState(ctx context.Context, state string) (*OAuthState, error) {
	conn, err := s.db.Conn(ctx)
	if err != nil {
		return nil, err
	}
	defer conn.Close()

	if _, err := conn.ExecContext(ctx, "BEGIN IMMEDIATE"); err != nil {
		return nil, err
	}
	committed := false
	defer func() {
		if !committed {
			_, _ = conn.ExecContext(ctx, "ROLLBACK")
		}
	}()

	var oauthState OAuthState
	var deviceID string
	var expiresAt string
	var completed int

	err = conn.QueryRowContext(ctx, `
		SELECT state, device_id, expires_at, completed
		FROM oauth_states
		WHERE state = ?
	`, state).Scan(&oauthState.State, &deviceID, &expiresAt, &completed)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}

	parsedDeviceID, err := uuid.Parse(deviceID)
	if err != nil {
		return nil, err
	}
	oauthState.DeviceID = parsedDeviceID
	oauthState.ExpiresAt, err = parseSQLiteTime(expiresAt)
	if err != nil {
		return nil, err
	}
	oauthState.Completed = completed != 0

	if oauthState.Completed {
		return nil, fmt.Errorf("oauth state already used")
	}
	if time.Now().After(oauthState.ExpiresAt) {
		return nil, fmt.Errorf("oauth state expired")
	}

	_, err = conn.ExecContext(ctx, `
		UPDATE oauth_states SET completed = 1 WHERE state = ?
	`, state)
	if err != nil {
		return nil, err
	}

	if _, err := conn.ExecContext(ctx, "COMMIT"); err != nil {
		return nil, err
	}
	committed = true

	return &oauthState, nil
}

func (s *Store) LinkInstallation(
	ctx context.Context,
	deviceID uuid.UUID,
	installationID int64,
	githubLogin string,
	githubAccountType string,
) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE devices
		SET installation_id = ?,
		    github_login = ?,
		    github_account_type = ?,
		    updated_at = datetime('now')
		WHERE id = ?
	`, installationID, githubLogin, githubAccountType, deviceID.String())
	return err
}

func (s *Store) UnlinkInstallation(ctx context.Context, deviceID uuid.UUID) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE devices
		SET installation_id = NULL,
		    github_login = NULL,
		    github_account_type = NULL,
		    updated_at = datetime('now')
		WHERE id = ?
	`, deviceID.String())
	return err
}

func nullInt64Ptr(value sql.NullInt64) *int64 {
	if !value.Valid {
		return nil
	}
	v := value.Int64
	return &v
}

func nullStringPtr(value sql.NullString) *string {
	if !value.Valid {
		return nil
	}
	v := value.String
	return &v
}

func parseSQLiteTime(value string) (time.Time, error) {
	formats := []string{
		time.RFC3339,
		"2006-01-02 15:04:05",
		time.RFC3339Nano,
	}
	for _, format := range formats {
		if parsed, err := time.Parse(format, value); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("parse sqlite time %q", value)
}
