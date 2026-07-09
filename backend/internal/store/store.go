package store

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	_ "github.com/jackc/pgx/v5/stdlib"
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

func New(ctx context.Context, databaseURL string) (*Store, error) {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	db.SetMaxOpenConns(10)

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
		VALUES ($1, $2)
		ON CONFLICT (id) DO UPDATE SET
			secret_hash = EXCLUDED.secret_hash,
			updated_at = NOW()
	`, deviceID.String(), secretHash)
	return err
}

func (s *Store) GetDeviceSecretHash(ctx context.Context, deviceID uuid.UUID) (string, error) {
	var secretHash string
	err := s.db.QueryRowContext(ctx, `
		SELECT secret_hash FROM devices WHERE id = $1
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

	err := s.db.QueryRowContext(ctx, `
		SELECT id, installation_id, github_login, github_account_type, created_at, updated_at
		FROM devices
		WHERE id = $1
	`, deviceID.String()).Scan(
		&id,
		&installationID,
		&githubLogin,
		&githubAccountType,
		&device.CreatedAt,
		&device.UpdatedAt,
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

	return &device, nil
}

func (s *Store) CreateOAuthState(ctx context.Context, state string, deviceID uuid.UUID, expiresAt time.Time) error {
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO oauth_states (state, device_id, expires_at)
		VALUES ($1, $2, $3)
	`, state, deviceID.String(), expiresAt.UTC())
	return err
}

func (s *Store) ConsumeOAuthState(ctx context.Context, state string) (*OAuthState, error) {
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	var oauthState OAuthState
	var deviceID string

	err = tx.QueryRowContext(ctx, `
		SELECT state, device_id, expires_at, completed
		FROM oauth_states
		WHERE state = $1
		FOR UPDATE
	`, state).Scan(&oauthState.State, &deviceID, &oauthState.ExpiresAt, &oauthState.Completed)
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

	if oauthState.Completed {
		return nil, fmt.Errorf("oauth state already used")
	}
	if time.Now().After(oauthState.ExpiresAt) {
		return nil, fmt.Errorf("oauth state expired")
	}

	_, err = tx.ExecContext(ctx, `
		UPDATE oauth_states SET completed = TRUE WHERE state = $1
	`, state)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(); err != nil {
		return nil, err
	}

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
		SET installation_id = $1,
		    github_login = $2,
		    github_account_type = $3,
		    updated_at = NOW()
		WHERE id = $4
	`, installationID, githubLogin, githubAccountType, deviceID.String())
	return err
}

func (s *Store) UnlinkInstallation(ctx context.Context, deviceID uuid.UUID) error {
	_, err := s.db.ExecContext(ctx, `
		UPDATE devices
		SET installation_id = NULL,
		    github_login = NULL,
		    github_account_type = NULL,
		    updated_at = NOW()
		WHERE id = $1
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
