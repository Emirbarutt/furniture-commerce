CREATE SCHEMA notification;

CREATE TABLE notification.notification_preference (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL, channel varchar(24) NOT NULL, topic varchar(64) NOT NULL,
  status varchar(24) NOT NULL, source varchar(80) NOT NULL, legal_text_version varchar(40), changed_at timestamptz NOT NULL,
  CONSTRAINT uq_notification_preference UNIQUE (customer_id, channel, topic)
);
CREATE INDEX ix_notification_preference_customer_status ON notification.notification_preference (customer_id, status);
CREATE TABLE notification.notification (
  id uuid PRIMARY KEY, customer_id uuid, recipient varchar(320) NOT NULL, channel varchar(24) NOT NULL,
  topic varchar(64) NOT NULL, template_code varchar(100) NOT NULL, template_version varchar(40) NOT NULL,
  payload_reference jsonb NOT NULL, idempotency_key varchar(128) NOT NULL UNIQUE, status varchar(40) NOT NULL,
  scheduled_at timestamptz NOT NULL, sent_at timestamptz, created_at timestamptz NOT NULL
);
CREATE INDEX ix_notification_status_scheduled ON notification.notification (status, scheduled_at);
CREATE INDEX ix_notification_customer_time ON notification.notification (customer_id, created_at DESC);
CREATE TABLE notification.notification_delivery (
  id uuid PRIMARY KEY, notification_id uuid NOT NULL REFERENCES notification.notification(id) ON DELETE CASCADE,
  provider varchar(64) NOT NULL, provider_message_id varchar(255), status varchar(40) NOT NULL,
  attempt_number smallint NOT NULL, failure_reason varchar(1000), attempted_at timestamptz NOT NULL, delivered_at timestamptz,
  CONSTRAINT uq_notification_delivery_attempt UNIQUE (notification_id, attempt_number),
  CONSTRAINT ck_notification_delivery_attempt CHECK (attempt_number > 0)
);
CREATE UNIQUE INDEX uq_delivery_provider_message ON notification.notification_delivery (provider, provider_message_id) WHERE provider_message_id IS NOT NULL;
CREATE INDEX ix_delivery_notification_time ON notification.notification_delivery (notification_id, attempted_at);

