package githubapp

import (
	"bytes"
	"context"
	"crypto/rsa"
	"crypto/x509"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const apiBaseURL = "https://api.github.com"

type Client struct {
	appID      string
	privateKey *rsa.PrivateKey
	httpClient *http.Client
}

type Installation struct {
	ID      int64                `json:"id"`
	Account *InstallationAccount `json:"account"`
}

type InstallationAccount struct {
	Login string `json:"login"`
	Type  string `json:"type"`
}

type InstallationToken struct {
	Token     string     `json:"token"`
	ExpiresAt *time.Time `json:"expires_at"`
}

func New(appID, privateKeyPEM string) (*Client, error) {
	key, err := parsePrivateKey(privateKeyPEM)
	if err != nil {
		return nil, err
	}

	return &Client{
		appID:      appID,
		privateKey: key,
		httpClient: &http.Client{Timeout: 30 * time.Second},
	}, nil
}

func (c *Client) GetInstallation(ctx context.Context, installationID int64) (*Installation, error) {
	var installation Installation
	if err := c.getJSON(ctx, fmt.Sprintf("/app/installations/%d", installationID), &installation); err != nil {
		return nil, err
	}
	return &installation, nil
}

func (c *Client) CreateInstallationToken(ctx context.Context, installationID int64) (*InstallationToken, error) {
	jwtToken, err := c.createJWT()
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		apiBaseURL+fmt.Sprintf("/app/installations/%d/access_tokens", installationID),
		bytes.NewReader([]byte("{}")),
	)
	if err != nil {
		return nil, err
	}

	req.Header.Set("Authorization", "Bearer "+jwtToken)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		return nil, readAPIError(resp)
	}

	var token InstallationToken
	if err := json.NewDecoder(resp.Body).Decode(&token); err != nil {
		return nil, err
	}
	return &token, nil
}

func (c *Client) getJSON(ctx context.Context, path string, dest any) error {
	jwtToken, err := c.createJWT()
	if err != nil {
		return err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, apiBaseURL+path, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+jwtToken)
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("X-GitHub-Api-Version", "2022-11-28")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return readAPIError(resp)
	}

	return json.NewDecoder(resp.Body).Decode(dest)
}

func (c *Client) createJWT() (string, error) {
	now := time.Now().Unix()
	claims := jwt.MapClaims{
		"iss": c.appID,
		"iat": now - 60,
		"exp": now + 600,
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	return token.SignedString(c.privateKey)
}

func parsePrivateKey(pemString string) (*rsa.PrivateKey, error) {
	pemString = strings.TrimSpace(pemString)
	block, _ := pem.Decode([]byte(pemString))
	if block == nil {
		return nil, fmt.Errorf("invalid private key PEM")
	}

	key, err := x509.ParsePKCS1PrivateKey(block.Bytes)
	if err == nil {
		return key, nil
	}

	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("parse private key: %w", err)
	}

	rsaKey, ok := parsed.(*rsa.PrivateKey)
	if !ok {
		return nil, fmt.Errorf("private key is not RSA")
	}
	return rsaKey, nil
}

func readAPIError(resp *http.Response) error {
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	return fmt.Errorf("github api %s: %s", resp.Status, strings.TrimSpace(string(body)))
}
