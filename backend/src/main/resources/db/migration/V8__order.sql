CREATE SCHEMA ordering;

CREATE TABLE ordering."order" (
  id uuid PRIMARY KEY, order_number varchar(32) NOT NULL UNIQUE, customer_id uuid, checkout_session_id uuid,
  email_snapshot citext NOT NULL, status varchar(40) NOT NULL, payment_status varchar(40) NOT NULL,
  fulfilment_status varchar(40) NOT NULL, currency char(3) NOT NULL, subtotal_amount numeric(19,4) NOT NULL,
  discount_amount numeric(19,4) NOT NULL, shipping_amount numeric(19,4) NOT NULL, tax_amount numeric(19,4) NOT NULL,
  grand_total_amount numeric(19,4) NOT NULL, placed_at timestamptz NOT NULL, cancelled_at timestamptz,
  cancellation_reason varchar(500), created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_order_totals CHECK (grand_total_amount = subtotal_amount - discount_amount + shipping_amount + tax_amount)
);
CREATE UNIQUE INDEX uq_order_checkout ON ordering."order" (checkout_session_id) WHERE checkout_session_id IS NOT NULL;
CREATE INDEX ix_order_customer_placed ON ordering."order" (customer_id, placed_at DESC);
CREATE INDEX ix_order_status_placed ON ordering."order" (status, placed_at);
CREATE INDEX ix_order_payment_placed ON ordering."order" (payment_status, placed_at);
CREATE TABLE ordering.order_item (
  id uuid PRIMARY KEY, order_id uuid NOT NULL REFERENCES ordering."order"(id) ON DELETE RESTRICT, variant_id uuid NOT NULL,
  sku_snapshot varchar(80) NOT NULL, product_title_snapshot varchar(300) NOT NULL, variant_title_snapshot varchar(180),
  quantity_ordered integer NOT NULL, quantity_cancelled integer NOT NULL DEFAULT 0, quantity_shipped integer NOT NULL DEFAULT 0,
  unit_list_price numeric(19,4) NOT NULL, unit_sale_price numeric(19,4) NOT NULL, discount_amount numeric(19,4) NOT NULL DEFAULT 0,
  tax_amount numeric(19,4) NOT NULL DEFAULT 0, line_total numeric(19,4) NOT NULL, tax_category_snapshot varchar(64) NOT NULL,
  weight_snapshot numeric(12,3), created_at timestamptz NOT NULL,
  CONSTRAINT ck_order_item_quantities CHECK (quantity_ordered >= 0 AND quantity_cancelled >= 0 AND quantity_shipped >= 0
    AND quantity_cancelled + quantity_shipped <= quantity_ordered)
);
CREATE INDEX ix_order_item_order ON ordering.order_item (order_id);
CREATE INDEX ix_order_item_variant_created ON ordering.order_item (variant_id, created_at);
CREATE TABLE ordering.order_address (
  id uuid PRIMARY KEY, order_id uuid NOT NULL REFERENCES ordering."order"(id) ON DELETE RESTRICT,
  address_type varchar(16) NOT NULL, recipient_name varchar(240) NOT NULL, line1 varchar(255) NOT NULL,
  line2 varchar(255), district varchar(120), city varchar(120) NOT NULL, region varchar(120),
  postal_code varchar(32), country_code char(2) NOT NULL, phone varchar(32), created_at timestamptz NOT NULL,
  CONSTRAINT uq_order_address_type UNIQUE (order_id, address_type),
  CONSTRAINT ck_order_address_type CHECK (address_type IN ('SHIPPING','BILLING'))
);
CREATE TABLE ordering.order_status_history (
  id uuid PRIMARY KEY, order_id uuid NOT NULL REFERENCES ordering."order"(id) ON DELETE RESTRICT,
  from_status varchar(40), to_status varchar(40) NOT NULL, reason varchar(500), actor_type varchar(40) NOT NULL,
  actor_id uuid, occurred_at timestamptz NOT NULL
);
CREATE INDEX ix_order_status_history_order_time ON ordering.order_status_history (order_id, occurred_at);

