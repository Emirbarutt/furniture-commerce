CREATE SCHEMA cart;
CREATE SCHEMA wishlist;

CREATE TABLE cart.cart (
  id uuid PRIMARY KEY, customer_id uuid, guest_token_hash char(64), market varchar(16) NOT NULL, currency char(3) NOT NULL,
  status varchar(40) NOT NULL, expires_at timestamptz, coupon_code citext, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_cart_owner CHECK (num_nonnulls(customer_id, guest_token_hash) = 1)
);
CREATE UNIQUE INDEX uq_cart_guest_token ON cart.cart (guest_token_hash) WHERE guest_token_hash IS NOT NULL;
CREATE UNIQUE INDEX uq_cart_active_customer ON cart.cart (customer_id, market, currency) WHERE status = 'ACTIVE';
CREATE INDEX ix_cart_status_expiry ON cart.cart (status, expires_at);
CREATE TABLE cart.cart_item (
  id uuid PRIMARY KEY, cart_id uuid NOT NULL REFERENCES cart.cart(id) ON DELETE CASCADE, variant_id uuid NOT NULL,
  quantity integer NOT NULL, selected_options_snapshot jsonb, added_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  CONSTRAINT uq_cart_item_variant UNIQUE (cart_id, variant_id), CONSTRAINT ck_cart_item_quantity CHECK (quantity > 0)
);
CREATE INDEX ix_cart_item_cart_added ON cart.cart_item (cart_id, added_at);

CREATE TABLE wishlist.wishlist (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL, name varchar(120) NOT NULL, normalized_name citext NOT NULL,
  is_default boolean NOT NULL DEFAULT false, visibility varchar(24) NOT NULL, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT uq_wishlist_customer_name UNIQUE (customer_id, normalized_name)
);
CREATE UNIQUE INDEX uq_wishlist_default ON wishlist.wishlist (customer_id) WHERE is_default;
CREATE INDEX ix_wishlist_customer_default ON wishlist.wishlist (customer_id, is_default);
CREATE TABLE wishlist.wishlist_item (
  id uuid PRIMARY KEY, wishlist_id uuid NOT NULL REFERENCES wishlist.wishlist(id) ON DELETE CASCADE,
  product_id uuid NOT NULL, variant_id uuid, note varchar(1000), added_at timestamptz NOT NULL
);
CREATE UNIQUE INDEX uq_wishlist_item_selection ON wishlist.wishlist_item (wishlist_id, product_id, variant_id) NULLS NOT DISTINCT;
CREATE INDEX ix_wishlist_item_wishlist_added ON wishlist.wishlist_item (wishlist_id, added_at);

