CREATE SCHEMA identity;

CREATE TABLE identity.user_account (
  id uuid PRIMARY KEY, email citext NOT NULL UNIQUE, email_verified_at timestamptz,
  password_hash varchar(255), status varchar(40) NOT NULL, failed_login_count integer NOT NULL DEFAULT 0,
  locked_until timestamptz, last_login_at timestamptz, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_user_account_status CHECK (status IN ('PENDING_VERIFICATION','ACTIVE','SUSPENDED','CLOSED')),
  CONSTRAINT ck_user_account_failed_logins CHECK (failed_login_count >= 0)
);
CREATE INDEX ix_user_account_status_created_at ON identity.user_account (status, created_at);

CREATE TABLE identity.role (
  id uuid PRIMARY KEY, code varchar(64) NOT NULL UNIQUE, name varchar(120) NOT NULL,
  description text, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL
);
CREATE TABLE identity.user_role (
  user_account_id uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE RESTRICT,
  role_id uuid NOT NULL REFERENCES identity.role(id) ON DELETE RESTRICT,
  granted_at timestamptz NOT NULL, granted_by_user_account_id uuid REFERENCES identity.user_account(id) ON DELETE SET NULL,
  PRIMARY KEY (user_account_id, role_id)
);
CREATE INDEX ix_user_role_role_account ON identity.user_role (role_id, user_account_id);
CREATE TABLE identity.refresh_session (
  id uuid PRIMARY KEY, user_account_id uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
  token_hash char(64) NOT NULL UNIQUE, device_label varchar(160), ip_address inet, user_agent text,
  expires_at timestamptz NOT NULL, revoked_at timestamptz, created_at timestamptz NOT NULL,
  CONSTRAINT ck_refresh_session_expiry CHECK (expires_at > created_at)
);
CREATE INDEX ix_refresh_session_account_expiry ON identity.refresh_session (user_account_id, expires_at);
CREATE INDEX ix_refresh_session_active ON identity.refresh_session (expires_at) WHERE revoked_at IS NULL;
CREATE TABLE identity.external_identity (
  id uuid PRIMARY KEY, user_account_id uuid NOT NULL REFERENCES identity.user_account(id) ON DELETE CASCADE,
  provider varchar(64) NOT NULL, provider_subject varchar(255) NOT NULL, email_at_provider citext,
  created_at timestamptz NOT NULL, CONSTRAINT uq_external_identity_provider_subject UNIQUE (provider, provider_subject)
);
CREATE INDEX ix_external_identity_account ON identity.external_identity (user_account_id);

