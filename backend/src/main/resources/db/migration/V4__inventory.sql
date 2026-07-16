CREATE SCHEMA inventory;

CREATE TABLE inventory.warehouse (
  id uuid PRIMARY KEY, code varchar(40) NOT NULL UNIQUE, name varchar(180) NOT NULL, address_snapshot jsonb NOT NULL,
  status varchar(40) NOT NULL, fulfilment_priority integer NOT NULL DEFAULT 0, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0
);
CREATE INDEX ix_warehouse_status_priority ON inventory.warehouse (status, fulfilment_priority);
CREATE TABLE inventory.stock_item (
  id uuid PRIMARY KEY, warehouse_id uuid NOT NULL REFERENCES inventory.warehouse(id) ON DELETE RESTRICT,
  variant_id uuid NOT NULL, on_hand_quantity integer NOT NULL DEFAULT 0, reserved_quantity integer NOT NULL DEFAULT 0,
  safety_stock_quantity integer NOT NULL DEFAULT 0, reorder_point integer, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT uq_stock_item_warehouse_variant UNIQUE (warehouse_id, variant_id),
  CONSTRAINT ck_stock_quantities CHECK (on_hand_quantity >= 0 AND reserved_quantity >= 0
    AND safety_stock_quantity >= 0 AND (reorder_point IS NULL OR reorder_point >= 0) AND reserved_quantity <= on_hand_quantity)
);
CREATE INDEX ix_stock_item_variant_warehouse ON inventory.stock_item (variant_id, warehouse_id);
CREATE TABLE inventory.stock_reservation (
  id uuid PRIMARY KEY, stock_item_id uuid NOT NULL REFERENCES inventory.stock_item(id) ON DELETE RESTRICT,
  reference_type varchar(40) NOT NULL, reference_id uuid NOT NULL, quantity integer NOT NULL, status varchar(40) NOT NULL,
  expires_at timestamptz NOT NULL, confirmed_at timestamptz, released_at timestamptz, created_at timestamptz NOT NULL,
  CONSTRAINT uq_stock_reservation_reference UNIQUE (stock_item_id, reference_type, reference_id),
  CONSTRAINT ck_stock_reservation_quantity CHECK (quantity > 0)
);
CREATE INDEX ix_stock_reservation_expiry ON inventory.stock_reservation (status, expires_at);
CREATE TABLE inventory.inventory_movement (
  id uuid PRIMARY KEY, stock_item_id uuid NOT NULL REFERENCES inventory.stock_item(id) ON DELETE RESTRICT,
  movement_type varchar(40) NOT NULL, quantity_delta integer NOT NULL, reference_type varchar(40), reference_id uuid,
  occurred_at timestamptz NOT NULL, performed_by uuid, reason varchar(500),
  CONSTRAINT ck_inventory_movement_delta CHECK (quantity_delta <> 0)
);
CREATE INDEX ix_inventory_movement_stock_time ON inventory.inventory_movement (stock_item_id, occurred_at);
CREATE INDEX ix_inventory_movement_reference ON inventory.inventory_movement (reference_type, reference_id);

