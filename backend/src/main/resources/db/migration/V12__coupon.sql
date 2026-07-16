CREATE SCHEMA promotion;

CREATE TABLE promotion.coupon (
  id uuid PRIMARY KEY, code citext NOT NULL UNIQUE, name varchar(200) NOT NULL, description text,
  discount_type varchar(24) NOT NULL, discount_value numeric(19,4) NOT NULL, currency char(3),
  minimum_order_amount numeric(19,4), maximum_discount_amount numeric(19,4), valid_from timestamptz NOT NULL,
  valid_until timestamptz, usage_limit integer, per_customer_limit integer, status varchar(40) NOT NULL,
  eligibility_rule_snapshot jsonb NOT NULL, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_coupon_discount CHECK (discount_value > 0 AND (discount_type <> 'PERCENTAGE' OR discount_value <= 100)
    AND (discount_type <> 'FIXED' OR currency IS NOT NULL)),
  CONSTRAINT ck_coupon_dates CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT ck_coupon_limits CHECK ((usage_limit IS NULL OR usage_limit > 0) AND (per_customer_limit IS NULL OR per_customer_limit > 0))
);
CREATE INDEX ix_coupon_status_validity ON promotion.coupon (status, valid_from, valid_until);
CREATE TABLE promotion.coupon_redemption (
  id uuid PRIMARY KEY, coupon_id uuid NOT NULL REFERENCES promotion.coupon(id) ON DELETE RESTRICT,
  customer_id uuid, checkout_session_id uuid, order_id uuid, discount_amount numeric(19,4) NOT NULL,
  currency char(3) NOT NULL, status varchar(40) NOT NULL, reserved_at timestamptz NOT NULL,
  redeemed_at timestamptz, released_at timestamptz,
  CONSTRAINT ck_coupon_redemption_amount CHECK (discount_amount >= 0),
  CONSTRAINT ck_coupon_redemption_reference CHECK (checkout_session_id IS NOT NULL OR order_id IS NOT NULL)
);
CREATE UNIQUE INDEX uq_coupon_checkout ON promotion.coupon_redemption (coupon_id, checkout_session_id) WHERE checkout_session_id IS NOT NULL;
CREATE UNIQUE INDEX uq_coupon_order ON promotion.coupon_redemption (coupon_id, order_id) WHERE order_id IS NOT NULL;
CREATE INDEX ix_coupon_redemption_coupon_status ON promotion.coupon_redemption (coupon_id, status);
CREATE INDEX ix_coupon_redemption_customer_coupon ON promotion.coupon_redemption (customer_id, coupon_id, status);

