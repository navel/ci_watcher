package config_test

import (
	"os"
	"testing"

	"github.com/navel/ci_watcher/backend/internal/config"
)

func TestLoadRequiresCoreValues(t *testing.T) {
	t.Setenv("SQLITE_PATH", "")
	t.Setenv("BASE_URL", "")
	t.Setenv("GITHUB_APP_ID", "")
	t.Setenv("GITHUB_PRIVATE_KEY", "")

	_, err := config.Load()
	if err == nil {
		t.Fatal("expected error when required env vars are missing")
	}
}

func TestLoadNormalizesPrivateKey(t *testing.T) {
	t.Setenv("BASE_URL", "http://localhost:8080")
	t.Setenv("GITHUB_APP_ID", "123")
	t.Setenv("GITHUB_PRIVATE_KEY", "-----BEGIN RSA PRIVATE KEY-----\\nabc\\n-----END RSA PRIVATE KEY-----")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}

	if cfg.GitHubPrivateKey != "-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----" {
		t.Fatalf("unexpected private key normalization: %q", cfg.GitHubPrivateKey)
	}
}

func TestLoadReadsEnv(t *testing.T) {
	for _, key := range []string{"BASE_URL", "GITHUB_APP_ID", "GITHUB_PRIVATE_KEY"} {
		if err := os.Setenv(key, "x"); err != nil {
			t.Fatal(err)
		}
	}
	t.Setenv("BASE_URL", "https://api.example.com/")
	t.Setenv("SQLITE_PATH", "/tmp/test.db")

	cfg, err := config.Load()
	if err != nil {
		t.Fatalf("load config: %v", err)
	}

	if cfg.BaseURL != "https://api.example.com" {
		t.Fatalf("expected trimmed base url, got %q", cfg.BaseURL)
	}
	if cfg.DatabasePath != "/tmp/test.db" {
		t.Fatalf("expected sqlite path, got %q", cfg.DatabasePath)
	}
}
