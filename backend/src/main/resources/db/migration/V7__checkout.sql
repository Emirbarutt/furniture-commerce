CREATE SCHEMA checkout;

CREATE TABLE checkout.checkout_session (
  id uuid PRIMARY KEY, cart_id uuid NOT NULL, customer_id uuid, idempotency_key varchar(128) NOT NULL,
  status varchar(40) NOT NULL, currency char(3) NOT NULL, line_snapshot jsonb NOT NULL,
  shipping_address_snapshot jsonb, billing_address_snapshot jsonb, shipping_option_snapshot jsonb,
  totals_snapshot jsonb NOT NULL, coupon_snapshot jsonb, expires_at timestamptz NOT NULL, order_id uuid,
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT uq_checkout_idempotency UNIQUE (idempotency_key)
);
CREATE UNIQUE INDEX uq_checkout_active_cart ON checkout.checkout_session (cart_id) WHERE status IN ('OPEN','PAYMENT_PENDING');
CREATE UNIQUE INDEX uq_checkout_order ON checkout.checkout_session (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX ix_checkout_status_expiry ON checkout.checkout_session (status, expires_at);

