CREATE SCHEMA catalog;

CREATE TABLE catalog.product (
  id uuid PRIMARY KEY, slug citext NOT NULL UNIQUE, product_type varchar(64) NOT NULL, brand varchar(120),
  title varchar(300) NOT NULL, description text, status varchar(40) NOT NULL, tax_category varchar(64) NOT NULL,
  assembled_length numeric(12,3), assembled_width numeric(12,3), assembled_height numeric(12,3), dimension_unit varchar(8),
  seo_title varchar(300), seo_description varchar(500), published_at timestamptz,
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_product_status CHECK (status IN ('DRAFT','ACTIVE','ARCHIVED')),
  CONSTRAINT ck_product_dimensions CHECK ((assembled_length IS NULL AND assembled_width IS NULL AND assembled_height IS NULL)
    OR (assembled_length > 0 AND assembled_width > 0 AND assembled_height > 0 AND dimension_unit IS NOT NULL))
);
CREATE INDEX ix_product_status_published ON catalog.product (status, published_at);
CREATE INDEX ix_product_brand_status ON catalog.product (brand, status);
CREATE INDEX gin_product_search ON catalog.product USING gin (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(description,'')));

CREATE TABLE catalog.product_variant (
  id uuid PRIMARY KEY, product_id uuid NOT NULL REFERENCES catalog.product(id) ON DELETE RESTRICT,
  sku varchar(80) NOT NULL UNIQUE, barcode varchar(80), title_suffix varchar(180), status varchar(40) NOT NULL,
  weight numeric(12,3), weight_unit varchar(8), package_length numeric(12,3), package_width numeric(12,3),
  package_height numeric(12,3), dimension_unit varchar(8), requires_assembly boolean NOT NULL DEFAULT false,
  lead_time_days smallint NOT NULL DEFAULT 0, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0, CONSTRAINT ck_variant_lead_time CHECK (lead_time_days >= 0),
  CONSTRAINT ck_variant_weight CHECK (weight IS NULL OR (weight > 0 AND weight_unit IS NOT NULL)),
  CONSTRAINT ck_variant_dimensions CHECK ((package_length IS NULL AND package_width IS NULL AND package_height IS NULL)
    OR (package_length > 0 AND package_width > 0 AND package_height > 0 AND dimension_unit IS NOT NULL))
);
CREATE UNIQUE INDEX uq_variant_barcode ON catalog.product_variant (barcode) WHERE barcode IS NOT NULL;
CREATE INDEX ix_variant_product_status ON catalog.product_variant (product_id, status);
CREATE TABLE catalog.category (
  id uuid PRIMARY KEY, parent_id uuid REFERENCES catalog.category(id) ON DELETE RESTRICT,
  slug citext NOT NULL UNIQUE, name varchar(180) NOT NULL, description text, sort_order integer NOT NULL DEFAULT 0,
  status varchar(40) NOT NULL, created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  version bigint NOT NULL DEFAULT 0, CONSTRAINT ck_category_not_self_parent CHECK (parent_id IS NULL OR parent_id <> id)
);
CREATE INDEX ix_category_parent_sort ON catalog.category (parent_id, sort_order);
CREATE INDEX ix_category_status_sort ON catalog.category (status, sort_order);
CREATE TABLE catalog.product_category (
  product_id uuid NOT NULL REFERENCES catalog.product(id) ON DELETE CASCADE,
  category_id uuid NOT NULL REFERENCES catalog.category(id) ON DELETE RESTRICT,
  is_primary boolean NOT NULL DEFAULT false, sort_order integer NOT NULL DEFAULT 0, PRIMARY KEY (product_id, category_id)
);
CREATE UNIQUE INDEX uq_product_category_primary ON catalog.product_category (product_id) WHERE is_primary;
CREATE INDEX ix_product_category_category_sort ON catalog.product_category (category_id, sort_order, product_id);
CREATE TABLE catalog.product_media (
  id uuid PRIMARY KEY, product_id uuid NOT NULL REFERENCES catalog.product(id) ON DELETE CASCADE,
  variant_id uuid REFERENCES catalog.product_variant(id) ON DELETE CASCADE, media_type varchar(32) NOT NULL,
  url text NOT NULL, alt_text varchar(300), sort_order integer NOT NULL DEFAULT 0, status varchar(40) NOT NULL,
  created_at timestamptz NOT NULL, CONSTRAINT uq_product_media_url UNIQUE (product_id, url)
);
CREATE INDEX ix_product_media_scope_sort ON catalog.product_media (product_id, variant_id, sort_order);
CREATE TABLE catalog.attribute_definition (
  id uuid PRIMARY KEY, code varchar(64) NOT NULL UNIQUE, name varchar(120) NOT NULL, data_type varchar(24) NOT NULL,
  is_variant_defining boolean NOT NULL DEFAULT true, sort_order integer NOT NULL DEFAULT 0, status varchar(40) NOT NULL,
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL,
  CONSTRAINT ck_attribute_data_type CHECK (data_type IN ('TEXT','NUMBER','BOOLEAN','CODE'))
);
CREATE TABLE catalog.variant_attribute_value (
  variant_id uuid NOT NULL REFERENCES catalog.product_variant(id) ON DELETE CASCADE,
  attribute_definition_id uuid NOT NULL REFERENCES catalog.attribute_definition(id) ON DELETE RESTRICT,
  value_text varchar(500), value_number numeric(19,4), value_boolean boolean, value_code varchar(100),
  PRIMARY KEY (variant_id, attribute_definition_id),
  CONSTRAINT ck_variant_attribute_one_value CHECK (num_nonnulls(value_text, value_number, value_boolean, value_code) = 1)
);
CREATE INDEX ix_variant_attribute_facet ON catalog.variant_attribute_value (attribute_definition_id, value_code, variant_id);
CREATE TABLE catalog.price (
  id uuid PRIMARY KEY, variant_id uuid NOT NULL REFERENCES catalog.product_variant(id) ON DELETE RESTRICT,
  market varchar(16) NOT NULL, channel varchar(32) NOT NULL, currency char(3) NOT NULL,
  list_amount numeric(19,4) NOT NULL, sale_amount numeric(19,4) NOT NULL, valid_from timestamptz NOT NULL,
  valid_until timestamptz, status varchar(40) NOT NULL, created_at timestamptz NOT NULL,
  updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_price_amounts CHECK (list_amount >= 0 AND sale_amount >= 0 AND sale_amount <= list_amount),
  CONSTRAINT ck_price_dates CHECK (valid_until IS NULL OR valid_until > valid_from),
  CONSTRAINT ex_price_active_period EXCLUDE USING gist (
    variant_id WITH =, market WITH =, channel WITH =, currency WITH =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') WITH &&
  ) WHERE (status = 'ACTIVE')
);
CREATE INDEX ix_price_lookup ON catalog.price (variant_id, market, channel, currency, status, valid_from, valid_until);

