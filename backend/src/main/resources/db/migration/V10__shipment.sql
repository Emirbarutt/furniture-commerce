CREATE SCHEMA shipment;

CREATE TABLE shipment.shipment (
  id uuid PRIMARY KEY, order_id uuid NOT NULL, warehouse_id uuid NOT NULL, shipment_number varchar(40) NOT NULL UNIQUE,
  carrier_code varchar(64), service_level varchar(64), tracking_number varchar(160), status varchar(40) NOT NULL,
  shipping_address_snapshot jsonb NOT NULL, estimated_delivery_from date, estimated_delivery_until date,
  shipped_at timestamptz, delivered_at timestamptz, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_shipment_estimate CHECK (estimated_delivery_until IS NULL OR estimated_delivery_from IS NULL
    OR estimated_delivery_until >= estimated_delivery_from)
);
CREATE UNIQUE INDEX uq_shipment_carrier_tracking ON shipment.shipment (carrier_code, tracking_number) WHERE tracking_number IS NOT NULL;
CREATE INDEX ix_shipment_order_status ON shipment.shipment (order_id, status);
CREATE INDEX ix_shipment_warehouse_status ON shipment.shipment (warehouse_id, status);
CREATE TABLE shipment.shipment_item (
  id uuid PRIMARY KEY, shipment_id uuid NOT NULL REFERENCES shipment.shipment(id) ON DELETE RESTRICT,
  order_item_id uuid NOT NULL, quantity integer NOT NULL, CONSTRAINT uq_shipment_item_line UNIQUE (shipment_id, order_item_id),
  CONSTRAINT ck_shipment_item_quantity CHECK (quantity > 0)
);
CREATE INDEX ix_shipment_item_order_item ON shipment.shipment_item (order_item_id);
CREATE TABLE shipment.tracking_event (
  id uuid PRIMARY KEY, shipment_id uuid NOT NULL REFERENCES shipment.shipment(id) ON DELETE CASCADE,
  carrier_event_code varchar(80), status varchar(40) NOT NULL, description varchar(1000), location varchar(300),
  occurred_at timestamptz NOT NULL, received_at timestamptz NOT NULL, raw_event_hash char(64) NOT NULL,
  CONSTRAINT uq_tracking_event_dedup UNIQUE NULLS NOT DISTINCT (shipment_id, carrier_event_code, occurred_at, raw_event_hash)
);
CREATE INDEX ix_tracking_event_shipment_time ON shipment.tracking_event (shipment_id, occurred_at);

