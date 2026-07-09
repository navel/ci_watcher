package config

import (
	"fmt"
	"os"
	"strings"
)

type Config struct {
	Port             string
	BaseURL          string
	AppURLScheme     string
	DatabasePath     string
	GitHubAppID      string
	GitHubAppSlug    string
	GitHubClientID   string
	GitHubPrivateKey string
}

func Load() (Config, error) {
	cfg := Config{
		Port:             envOrDefault("PORT", "8080"),
		BaseURL:          strings.TrimRight(os.Getenv("BASE_URL"), "/"),
		AppURLScheme:     envOrDefault("APP_URL_SCHEME", "ciwatcher"),
		DatabasePath:     envOrDefault("SQLITE_PATH", "./data/ciwatcher.db"),
		GitHubAppID:      os.Getenv("GITHUB_APP_ID"),
		GitHubAppSlug:    envOrDefault("GITHUB_APP_SLUG", "ciwatcher-native"),
		GitHubClientID:   os.Getenv("GITHUB_CLIENT_ID"),
		GitHubPrivateKey: normalizePrivateKey(os.Getenv("GITHUB_PRIVATE_KEY")),
	}

	if cfg.BaseURL == "" {
		return cfg, fmt.Errorf("BASE_URL is required")
	}
	if cfg.GitHubAppID == "" {
		return cfg, fmt.Errorf("GITHUB_APP_ID is required")
	}
	if cfg.GitHubPrivateKey == "" {
		return cfg, fmt.Errorf("GITHUB_PRIVATE_KEY is required")
	}

	return cfg, nil
}

func envOrDefault(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}

func normalizePrivateKey(value string) string {
	if value == "" {
		return ""
	}
	return strings.NewReplacer(`\n`, "\n", `\r`, "\r").Replace(value)
}
