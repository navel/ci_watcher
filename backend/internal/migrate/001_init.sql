CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    secret_hash TEXT NOT NULL,
    installation_id BIGINT,
    github_login TEXT,
    github_account_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS oauth_states (
    state TEXT PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_oauth_states_device_id ON oauth_states(device_id);
CREATE INDEX IF NOT EXISTS idx_devices_installation_id ON devices(installation_id);
