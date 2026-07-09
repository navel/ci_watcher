package store_test

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/navel/ci_watcher/backend/internal/migrate"
	"github.com/navel/ci_watcher/backend/internal/store"
)

func testStore(t *testing.T) *store.Store {
	t.Helper()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		t.Skip("DATABASE_URL not set")
	}

	ctx := context.Background()
	db, err := store.New(ctx, databaseURL)
	if err != nil {
		t.Fatalf("new store: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	if err := migrate.Up(ctx, db.DB()); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	if _, err := db.DB().ExecContext(ctx, "TRUNCATE oauth_states, devices RESTART IDENTITY CASCADE"); err != nil {
		t.Fatalf("truncate tables: %v", err)
	}

	return db
}

func TestStoreDeviceLifecycle(t *testing.T) {
	ctx := context.Background()
	db := testStore(t)

	deviceID := uuid.New()
	if err := db.UpsertDevice(ctx, deviceID, "hash"); err != nil {
		t.Fatalf("upsert device: %v", err)
	}

	hash, err := db.GetDeviceSecretHash(ctx, deviceID)
	if err != nil {
		t.Fatalf("get secret hash: %v", err)
	}
	if hash != "hash" {
		t.Fatalf("unexpected hash: %q", hash)
	}

	if err := db.LinkInstallation(ctx, deviceID, 42, "octocat", "User"); err != nil {
		t.Fatalf("link installation: %v", err)
	}

	device, err := db.GetDevice(ctx, deviceID)
	if err != nil {
		t.Fatalf("get device: %v", err)
	}
	if device.InstallationID == nil || *device.InstallationID != 42 {
		t.Fatalf("unexpected installation id: %#v", device.InstallationID)
	}
}

func TestConsumeOAuthState(t *testing.T) {
	ctx := context.Background()
	db := testStore(t)

	deviceID := uuid.New()
	if err := db.UpsertDevice(ctx, deviceID, "hash"); err != nil {
		t.Fatalf("upsert device: %v", err)
	}

	state := "test-state"
	expiresAt := time.Now().Add(10 * time.Minute)
	if err := db.CreateOAuthState(ctx, state, deviceID, expiresAt); err != nil {
		t.Fatalf("create oauth state: %v", err)
	}

	oauthState, err := db.ConsumeOAuthState(ctx, state)
	if err != nil {
		t.Fatalf("consume oauth state: %v", err)
	}
	if oauthState.DeviceID != deviceID {
		t.Fatalf("unexpected device id: %s", oauthState.DeviceID)
	}

	if _, err := db.ConsumeOAuthState(ctx, state); err == nil {
		t.Fatal("expected second consume to fail")
	}
}
