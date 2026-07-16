CREATE SCHEMA payment;

CREATE TABLE payment.payment (
  id uuid PRIMARY KEY, order_id uuid NOT NULL, provider varchar(64) NOT NULL, method_type varchar(40) NOT NULL,
  amount_authorized numeric(19,4) NOT NULL DEFAULT 0, amount_captured numeric(19,4) NOT NULL DEFAULT 0,
  amount_refunded numeric(19,4) NOT NULL DEFAULT 0, currency char(3) NOT NULL, status varchar(40) NOT NULL,
  provider_customer_reference varchar(255), created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_payment_amounts CHECK (amount_authorized >= 0 AND amount_captured >= 0 AND amount_refunded >= 0
    AND amount_captured <= amount_authorized AND amount_refunded <= amount_captured)
);
CREATE INDEX ix_payment_order_status ON payment.payment (order_id, status);
CREATE INDEX ix_payment_provider_status_time ON payment.payment (provider, status, created_at);
CREATE TABLE payment.payment_attempt (
  id uuid PRIMARY KEY, payment_id uuid NOT NULL REFERENCES payment.payment(id) ON DELETE RESTRICT,
  operation varchar(40) NOT NULL, idempotency_key varchar(128) NOT NULL, provider_transaction_id varchar(255),
  status varchar(40) NOT NULL, requested_amount numeric(19,4) NOT NULL, response_code varchar(80),
  failure_code varchar(80), failure_message varchar(500), initiated_at timestamptz NOT NULL, completed_at timestamptz,
  CONSTRAINT uq_payment_attempt_idempotency UNIQUE (payment_id, operation, idempotency_key),
  CONSTRAINT ck_payment_attempt_amount CHECK (requested_amount >= 0)
);
CREATE UNIQUE INDEX uq_payment_attempt_provider_tx ON payment.payment_attempt (provider_transaction_id) WHERE provider_transaction_id IS NOT NULL;
CREATE INDEX ix_payment_attempt_payment_time ON payment.payment_attempt (payment_id, initiated_at);
CREATE TABLE payment.refund (
  id uuid PRIMARY KEY, payment_id uuid NOT NULL REFERENCES payment.payment(id) ON DELETE RESTRICT, order_id uuid NOT NULL,
  amount numeric(19,4) NOT NULL, currency char(3) NOT NULL, reason varchar(500) NOT NULL, status varchar(40) NOT NULL,
  provider_refund_id varchar(255), requested_at timestamptz NOT NULL, completed_at timestamptz,
  CONSTRAINT ck_refund_amount CHECK (amount > 0)
);
CREATE UNIQUE INDEX uq_refund_provider_id ON payment.refund (provider_refund_id) WHERE provider_refund_id IS NOT NULL;
CREATE INDEX ix_refund_payment_status ON payment.refund (payment_id, status);

