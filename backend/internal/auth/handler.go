package auth

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"

	"github.com/navel/ci_watcher/backend/internal/config"
	"github.com/navel/ci_watcher/backend/internal/githubapp"
	"github.com/navel/ci_watcher/backend/internal/store"
)

const oauthStateTTL = 15 * time.Minute

type Handler struct {
	cfg       config.Config
	store     *store.Store
	githubApp *githubapp.Client
}

func NewHandler(cfg config.Config, store *store.Store, githubApp *githubapp.Client) *Handler {
	return &Handler{
		cfg:       cfg,
		store:     store,
		githubApp: githubApp,
	}
}

type startRequest struct {
	DeviceID     string `json:"device_id"`
	DeviceSecret string `json:"device_secret"`
}

type startResponse struct {
	AuthURL string `json:"auth_url"`
	State   string `json:"state"`
}

type tokenResponse struct {
	Token     string     `json:"token"`
	ExpiresAt *time.Time `json:"expires_at,omitempty"`
}

type statusResponse struct {
	Connected         bool   `json:"connected"`
	InstallationID    *int64 `json:"installation_id,omitempty"`
	GitHubLogin       string `json:"github_login,omitempty"`
	GitHubAccountType string `json:"github_account_type,omitempty"`
}

func (h *Handler) Start(w http.ResponseWriter, r *http.Request) {
	var req startRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid json body")
		return
	}

	deviceID, err := uuid.Parse(strings.TrimSpace(req.DeviceID))
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid device_id")
		return
	}
	if len(strings.TrimSpace(req.DeviceSecret)) < 16 {
		writeError(w, http.StatusBadRequest, "device_secret must be at least 16 characters")
		return
	}

	secretHash, err := bcrypt.GenerateFromPassword([]byte(req.DeviceSecret), bcrypt.DefaultCost)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to hash device secret")
		return
	}

	if err := h.store.UpsertDevice(r.Context(), deviceID, string(secretHash)); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to register device")
		return
	}

	state, err := randomState()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create oauth state")
		return
	}

	expiresAt := time.Now().Add(oauthStateTTL)
	if err := h.store.CreateOAuthState(r.Context(), state, deviceID, expiresAt); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to create oauth state")
		return
	}

	authURL := fmt.Sprintf(
		"https://github.com/apps/%s/installations/new?state=%s",
		url.PathEscape(h.cfg.GitHubAppSlug),
		url.QueryEscape(state),
	)

	writeJSON(w, http.StatusOK, startResponse{
		AuthURL: authURL,
		State:   state,
	})
}

func (h *Handler) Callback(w http.ResponseWriter, r *http.Request) {
	installationIDRaw := strings.TrimSpace(r.URL.Query().Get("installation_id"))
	state := strings.TrimSpace(r.URL.Query().Get("state"))

	if installationIDRaw == "" || state == "" {
		redirectWithError(w, r, h.cfg.AppURLScheme, "missing installation_id or state")
		return
	}

	installationID, err := strconv.ParseInt(installationIDRaw, 10, 64)
	if err != nil || installationID <= 0 {
		redirectWithError(w, r, h.cfg.AppURLScheme, "invalid installation_id")
		return
	}

	oauthState, err := h.store.ConsumeOAuthState(r.Context(), state)
	if err != nil {
		redirectWithError(w, r, h.cfg.AppURLScheme, "invalid or expired oauth state")
		return
	}

	installation, err := h.githubApp.GetInstallation(r.Context(), installationID)
	if err != nil {
		redirectWithError(w, r, h.cfg.AppURLScheme, "failed to verify installation")
		return
	}

	login := ""
	accountType := ""
	if installation.Account != nil {
		login = installation.Account.Login
		accountType = installation.Account.Type
	}

	if err := h.store.LinkInstallation(
		r.Context(),
		oauthState.DeviceID,
		installationID,
		login,
		accountType,
	); err != nil {
		redirectWithError(w, r, h.cfg.AppURLScheme, "failed to link installation")
		return
	}

	redirectURL := fmt.Sprintf("%s://auth/callback?success=1", h.cfg.AppURLScheme)
	http.Redirect(w, r, redirectURL, http.StatusFound)
}

func (h *Handler) Token(w http.ResponseWriter, r *http.Request) {
	deviceID, deviceSecret, ok := parseDeviceCredentials(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid authorization")
		return
	}

	if err := h.verifyDevice(r.Context(), deviceID, deviceSecret); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid device credentials")
		return
	}

	device, err := h.store.GetDevice(r.Context(), deviceID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusUnauthorized, "device not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to load device")
		return
	}

	if device.InstallationID == nil {
		writeError(w, http.StatusConflict, "device is not linked to a github installation")
		return
	}

	token, err := h.githubApp.CreateInstallationToken(r.Context(), *device.InstallationID)
	if err != nil {
		writeError(w, http.StatusBadGateway, "failed to create installation token")
		return
	}

	writeJSON(w, http.StatusOK, tokenResponse{
		Token:     token.Token,
		ExpiresAt: token.ExpiresAt,
	})
}

func (h *Handler) Installation(w http.ResponseWriter, r *http.Request) {
	deviceID, deviceSecret, ok := parseDeviceCredentials(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid authorization")
		return
	}

	if err := h.verifyDevice(r.Context(), deviceID, deviceSecret); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid device credentials")
		return
	}

	device, err := h.store.GetDevice(r.Context(), deviceID)
	if err != nil {
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusUnauthorized, "device not found")
			return
		}
		writeError(w, http.StatusInternalServerError, "failed to load device")
		return
	}

	if device.InstallationID == nil {
		writeJSON(w, http.StatusOK, statusResponse{Connected: false})
		return
	}

	writeJSON(w, http.StatusOK, statusResponse{
		Connected:         true,
		InstallationID:    device.InstallationID,
		GitHubLogin:       derefString(device.GitHubLogin),
		GitHubAccountType: derefString(device.GitHubAccountType),
	})
}

func (h *Handler) Disconnect(w http.ResponseWriter, r *http.Request) {
	deviceID, deviceSecret, ok := parseDeviceCredentials(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "missing or invalid authorization")
		return
	}

	if err := h.verifyDevice(r.Context(), deviceID, deviceSecret); err != nil {
		writeError(w, http.StatusUnauthorized, "invalid device credentials")
		return
	}

	if err := h.store.UnlinkInstallation(r.Context(), deviceID); err != nil {
		writeError(w, http.StatusInternalServerError, "failed to disconnect device")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) verifyDevice(ctx context.Context, deviceID uuid.UUID, deviceSecret string) error {
	secretHash, err := h.store.GetDeviceSecretHash(ctx, deviceID)
	if err != nil {
		return err
	}
	return bcrypt.CompareHashAndPassword([]byte(secretHash), []byte(deviceSecret))
}

func parseDeviceCredentials(r *http.Request) (uuid.UUID, string, bool) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(header, "Bearer ") {
		header = strings.TrimPrefix(header, "Bearer ")
	}

	parts := strings.SplitN(header, ".", 2)
	if len(parts) != 2 {
		return uuid.Nil, "", false
	}

	deviceID, err := uuid.Parse(parts[0])
	if err != nil {
		return uuid.Nil, "", false
	}

	secret := strings.TrimSpace(parts[1])
	if secret == "" {
		return uuid.Nil, "", false
	}

	return deviceID, secret, true
}

func randomState() (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}

func redirectWithError(w http.ResponseWriter, r *http.Request, scheme, message string) {
	redirectURL := fmt.Sprintf("%s://auth/callback?success=0&error=%s", scheme, url.QueryEscape(message))
	http.Redirect(w, r, redirectURL, http.StatusFound)
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func derefString(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}
