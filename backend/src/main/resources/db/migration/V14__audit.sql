CREATE SCHEMA audit;

CREATE TABLE audit.audit_log (
  id uuid PRIMARY KEY, occurred_at timestamptz NOT NULL, actor_type varchar(40) NOT NULL, actor_id uuid,
  action varchar(120) NOT NULL, resource_type varchar(80) NOT NULL, resource_id uuid NOT NULL,
  correlation_id uuid, causation_id uuid, request_id varchar(128), ip_address inet, before_hash char(64),
  after_hash char(64), metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX ix_audit_resource_time ON audit.audit_log (resource_type, resource_id, occurred_at DESC);
CREATE INDEX ix_audit_actor_time ON audit.audit_log (actor_id, occurred_at DESC);
CREATE INDEX ix_audit_correlation ON audit.audit_log (correlation_id);
CREATE TABLE audit.outbox_event (
  id uuid PRIMARY KEY, aggregate_type varchar(80) NOT NULL, aggregate_id uuid NOT NULL, event_type varchar(120) NOT NULL,
  payload jsonb NOT NULL, occurred_at timestamptz NOT NULL, published_at timestamptz, attempt_count integer NOT NULL DEFAULT 0,
  last_error text, CONSTRAINT uq_outbox_event_dedup UNIQUE (aggregate_type, aggregate_id, event_type, occurred_at),
  CONSTRAINT ck_outbox_attempt_count CHECK (attempt_count >= 0)
);
CREATE INDEX ix_outbox_unpublished ON audit.outbox_event (published_at, occurred_at);

