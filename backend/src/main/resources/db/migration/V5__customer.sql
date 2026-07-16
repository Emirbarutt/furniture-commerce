CREATE SCHEMA customer;

CREATE TABLE customer.customer_profile (
  id uuid PRIMARY KEY, user_account_id uuid, first_name varchar(120) NOT NULL, last_name varchar(120) NOT NULL,
  phone varchar(32), date_of_birth date, locale varchar(35) NOT NULL, status varchar(40) NOT NULL,
  marketing_consent_at timestamptz, consent_source varchar(80), consent_text_version varchar(40),
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX uq_customer_user_account ON customer.customer_profile (user_account_id) WHERE user_account_id IS NOT NULL;
CREATE INDEX ix_customer_status_created ON customer.customer_profile (status, created_at);
CREATE TABLE customer.address (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL REFERENCES customer.customer_profile(id) ON DELETE RESTRICT,
  label varchar(100), recipient_name varchar(240) NOT NULL, line1 varchar(255) NOT NULL, line2 varchar(255),
  district varchar(120), city varchar(120) NOT NULL, region varchar(120), postal_code varchar(32),
  country_code char(2) NOT NULL, phone varchar(32), is_default_shipping boolean NOT NULL DEFAULT false,
  is_default_billing boolean NOT NULL DEFAULT false, status varchar(40) NOT NULL,
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX uq_address_default_shipping ON customer.address (customer_id) WHERE is_default_shipping AND status = 'ACTIVE';
CREATE UNIQUE INDEX uq_address_default_billing ON customer.address (customer_id) WHERE is_default_billing AND status = 'ACTIVE';
CREATE INDEX ix_address_customer_status_updated ON customer.address (customer_id, status, updated_at);

