CREATE SCHEMA review;

CREATE TABLE review.review (
  id uuid PRIMARY KEY, customer_id uuid NOT NULL, product_id uuid NOT NULL, order_item_id uuid,
  rating smallint NOT NULL, title varchar(300), body text, status varchar(40) NOT NULL,
  is_verified_purchase boolean NOT NULL DEFAULT false, helpful_count integer NOT NULL DEFAULT 0, moderated_at timestamptz,
  created_at timestamptz NOT NULL, updated_at timestamptz NOT NULL, version bigint NOT NULL DEFAULT 0,
  CONSTRAINT ck_review_rating CHECK (rating BETWEEN 1 AND 5), CONSTRAINT ck_review_helpful_count CHECK (helpful_count >= 0),
  CONSTRAINT uq_review_purchase UNIQUE NULLS NOT DISTINCT (customer_id, product_id, order_item_id)
);
CREATE INDEX ix_review_product_status_time ON review.review (product_id, status, created_at DESC);
CREATE INDEX ix_review_customer_time ON review.review (customer_id, created_at DESC);
CREATE TABLE review.review_media (
  id uuid PRIMARY KEY, review_id uuid NOT NULL REFERENCES review.review(id) ON DELETE CASCADE,
  media_type varchar(32) NOT NULL, url text NOT NULL, sort_order integer NOT NULL DEFAULT 0, status varchar(40) NOT NULL,
  created_at timestamptz NOT NULL, CONSTRAINT uq_review_media_url UNIQUE (review_id, url)
);
CREATE INDEX ix_review_media_review_sort ON review.review_media (review_id, sort_order);

