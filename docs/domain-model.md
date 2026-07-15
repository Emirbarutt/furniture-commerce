# Furniture Commerce Domain Model

## Architecture and conventions

This model supports a high-volume furniture retailer in a modular monolith. Each bounded context owns its records and exposes contracts or events. Cross-context foreign keys are logical references; physical foreign keys are mandatory within an owning context. All PKs are immutable UUIDs. Mutable aggregate roots have createdAt, updatedAt, and version. Timestamps are UTC. Money is decimal amount plus ISO-4217 currency; no floating-point monetary field is allowed.

Cardinality: 1--* one-to-many, 0..1 optional one, and *--* is represented by a join entity. Shared value objects are Money, Quantity, Sku, ProductDimensions, Weight, AddressSnapshot, EmailAddress, PhoneNumber, Locale, TaxRate, DateRange, PaymentReference, and TrackingNumber.

## Business capabilities and bounded contexts

| Capability | Context | Owns |
| --- | --- | --- |
| Access control | Identity | accounts, roles, sessions, provider identities |
| Merchandising | Catalog | products, variants, taxonomy, assets, attributes, prices |
| Availability | Inventory | warehouses, balances, reservations, movements |
| Customer data | Customer and Address | profiles, addresses, consent |
| Shopping intent | Cart and Wishlist | carts and saved products |
| Purchase orchestration | Checkout | checkout snapshots and idempotency |
| Commercial commitment | Order | orders, lines, address and status snapshots |
| Funds | Payment | payments, attempts, refunds |
| Fulfilment | Shipment | shipments, shipped lines, tracking |
| Feedback | Review | product reviews and review media |
| Promotions | Coupon | coupons and redemption limits |
| Communications | Notification | consent, messages, delivery attempts |
| Traceability | Audit | immutable audit and outbox events |

## Relationships and aggregate map

- UserAccount 1--0..1 CustomerProfile; CustomerProfile 1--* Address, Cart, Wishlist, Order, Review.
- Product 1--* ProductVariant; Product *--* Category through ProductCategory; ProductVariant 1--* Price and StockItem.
- Cart 1--* CartItem; Cart 0..1--1 CheckoutSession; CheckoutSession 0..1--1 Order.
- Order 1--* OrderItem, OrderAddress, OrderStatusHistory, Payment, Shipment.
- Shipment 1--* ShipmentItem and TrackingEvent. Coupon 1--* CouponRedemption.
- Any aggregate can generate 0--* AuditLog and OutboxEvent rows.

## Entity catalogue

### Identity: UserAccount aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| UserAccount | Authentication principal. | id PK; email, emailVerifiedAt, passwordHash, status, failedLoginCount, lockedUntil, lastLoginAt. | UQ normalized email; status PENDING_VERIFICATION/ACTIVE/SUSPENDED/CLOSED; 1--* RefreshSession and ExternalIdentity, *--* Role; indexes UQ(email), (status, createdAt). |
| Role | Stable authorization role. | id PK; code, name, description. | UQ immutable code; *--* UserAccount through UserRole; UQ(code). |
| UserRole | Role grant. | userAccountId PK/FK UserAccount; roleId PK/FK Role; grantedAt, grantedByUserAccountId FK UserAccount. | Composite PK prevents duplicate grants; index (roleId, userAccountId). |
| RefreshSession | Revocable device session. | id PK; userAccountId FK; tokenHash, deviceLabel, ipAddress, userAgent, expiresAt, revokedAt. | UQ tokenHash; belongs to 1 UserAccount; indexes UQ(tokenHash), (userAccountId, expiresAt), active-session partial index. |
| ExternalIdentity | External provider binding. | id PK; userAccountId FK; provider, providerSubject, emailAtProvider. | UQ(provider, providerSubject); belongs to 1 UserAccount; provider tokens are not stored. |

Identity rules: account suspension revokes sessions; verified email is required for sensitive actions; roles authorize action but never bypass module data ownership.

### Catalog: Product aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Product | Furniture product family. | id PK; slug, productType, brand, title, description, status, taxCategory, assembledDimensions, SEO fields, publishedAt. | UQ slug; ACTIVE requires active variant, category, media, and price; 1--* ProductVariant/ProductMedia/Review, *--* Category; indexes UQ(slug), (status, publishedAt), full-text title/description. |
| ProductVariant | Independently priced, stocked sellable item. | id PK; productId FK; sku, barcode, titleSuffix, status, weight, packageDimensions, requiresAssembly, leadTimeDays. | UQ immutable sku and barcode when present; belongs to 1 Product; 1--* Price, StockItem, VariantAttributeValue; indexes (productId, status), UQ(sku). |
| Category | Navigable merchandise taxonomy. | id PK; parentId self FK nullable; slug, name, description, sortOrder, status. | UQ slug; no parent cycle; 0--* children, *--* Product; indexes (parentId, sortOrder), (status, sortOrder). |
| ProductCategory | Product/category assignment. | productId PK/FK Product; categoryId PK/FK Category; isPrimary, sortOrder. | Composite PK; one primary category/product; index (categoryId, sortOrder, productId). |
| ProductMedia | Approved product/variant asset. | id PK; productId FK; variantId FK nullable; mediaType, url, altText, sortOrder, status. | Public only when approved; belongs to 1 Product and 0..1 ProductVariant; index (productId, variantId, sortOrder). |
| AttributeDefinition | Controlled option definition. | id PK; code, name, dataType, isVariantDefining, sortOrder, status. | UQ code; type immutable while values exist; 1--* VariantAttributeValue. |
| VariantAttributeValue | Variant attribute selection. | variantId PK/FK ProductVariant; attributeDefinitionId PK/FK; valueText/valueNumber/valueBoolean/valueCode. | Exactly one type-compatible value; belongs to one variant/definition; index (attributeDefinitionId, valueCode, variantId). |
| Price | Effective variant price. | id PK; variantId FK; market, channel, currency, listAmount, saleAmount, validFrom, validUntil, status. | saleAmount <= listAmount; no overlapping active range for variant/market/channel/currency; index (variantId, market, channel, status, validFrom, validUntil). |

Catalog rules: only ProductVariant is purchasable; archived data remains resolvable; OrderItem copies product, SKU, price, tax, and dimension snapshots.

### Inventory: Warehouse aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Warehouse | Physical/virtual fulfilment location. | id PK; code, name, addressSnapshot, status, fulfilmentPriority. | UQ immutable code; active only for allocation; 1--* StockItem/Reservation/Movement; index (status, fulfilmentPriority). |
| StockItem | Variant balance at warehouse. | id PK; warehouseId FK; variantId logical FK ProductVariant; onHandQuantity, reservedQuantity, safetyStockQuantity, reorderPoint, version. | UQ(warehouseId, variantId); all quantities >= 0 and reserved <= onHand; 1--* reservations/movements; index (variantId, warehouseId). |
| StockReservation | Timed checkout/order allocation. | id PK; stockItemId FK; referenceType, referenceId, quantity, status, expiresAt, confirmedAt, releasedAt. | Positive quantity; active reservation expires; belongs to 1 StockItem; UQ(stockItemId, referenceType, referenceId), (status, expiresAt). |
| InventoryMovement | Immutable stock ledger entry. | id PK; stockItemId FK; type, quantityDelta, referenceType, referenceId, occurredAt, performedBy, reason. | Non-zero signed delta matching type; append-only; belongs to 1 StockItem; indexes (stockItemId, occurredAt), (referenceType, referenceId). |

Inventory rules: only Inventory mutates stock; available-to-sell cannot be negative; carts reserve nothing; expired checkout reservations are released.

### Customer and Address: CustomerProfile aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| CustomerProfile | Commercial customer profile. | id PK; userAccountId logical FK nullable; firstName, lastName, phone, dateOfBirth, locale, status, marketingConsentAt. | UQ userAccountId when set; normalized phone; 1--* Address/Cart/Wishlist/Order/Review; indexes UQ(userAccountId), (status, createdAt). |
| Address | Reusable address-book record. | id PK; customerId FK; label, recipientName, address lines, district, city, region, postalCode, countryCode, phone, default flags, status. | Country validation; one active default shipping and billing/customer; belongs to 1 CustomerProfile; index (customerId, status, updatedAt). |

Customer rules: historic orders use AddressSnapshot; guest orders may lack a profile; marketing consent records source and legal text version.

### Cart: Cart aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Cart | Mutable customer or guest basket. | id PK; customerId logical FK nullable; guestTokenHash, market, currency, status, expiresAt, couponCode, version. | Exactly one owner type; one active customer cart/market/currency; 1--* CartItem, 0..1 CheckoutSession; UQ guestTokenHash, (status, expiresAt). |
| CartItem | Requested variant quantity. | id PK; cartId FK; variantId logical FK ProductVariant; quantity, selectedOptionsSnapshot, addedAt. | UQ(cartId, variantId); positive policy-bounded quantity; belongs to 1 Cart; index (cartId, addedAt). |

Cart rules: no price/stock guarantee; checkout recalculates commercial data; updates use optimistic concurrency.

### Wishlist: Wishlist aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Wishlist | Named saved-product list. | id PK; customerId logical FK; name, isDefault, visibility. | UQ(customerId, normalized name); one default; 1--* WishlistItem; index (customerId, isDefault). |
| WishlistItem | Saved product/variant. | id PK; wishlistId FK; productId logical FK; variantId logical FK nullable; note, addedAt. | UQ(wishlistId, productId, variantId); belongs to 1 Wishlist and references 1 Product/0..1 Variant; index (wishlistId, addedAt). |

Wishlist rules: it does not reserve inventory or freeze price; unavailable items remain visible as unavailable.

### Checkout: CheckoutSession aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| CheckoutSession | Idempotent cart-to-order orchestration. | id PK; cartId/customerId logical FK; idempotencyKey, status, currency, lineSnapshot, address snapshots, shippingOptionSnapshot, totalsSnapshot, couponSnapshot, expiresAt, orderId logical FK nullable. | UQ caller-scoped idempotencyKey; snapshots immutable after payment start; 0..1 resulting Order; indexes UQ(idempotencyKey), active UQ(cartId), (status, expiresAt). |

Checkout rules: one idempotency key gives one outcome; totals are server calculated; expiry releases checkout reservations.

### Order: Order aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Order | Commercial commitment. | id PK; orderNumber, customerId logical FK nullable, emailSnapshot, status, paymentStatus, fulfilmentStatus, currency, subtotal/discount/shipping/tax/grandTotal, placedAt, cancellation fields, version. | UQ immutable orderNumber; totals reconcile; 1--* OrderItem/Address/StatusHistory/Payment/Shipment; indexes (customerId, placedAt DESC), (status, placedAt), (paymentStatus, placedAt). |
| OrderItem | Immutable purchased-line snapshot. | id PK; orderId FK; variantId, SKU/title snapshots, quantityOrdered/cancelled/shipped, price/discount/tax/line totals, tax/weight snapshots. | Quantities non-negative and cancelled+shipped <= ordered; 1--* ShipmentItem; indexes (orderId), (variantId, createdAt). |
| OrderAddress | Immutable billing/shipping address. | id PK; orderId FK; type, AddressSnapshot fields, createdAt. | UQ(orderId, type); belongs to 1 Order; never altered after placement. |
| OrderStatusHistory | Append-only status transition. | id PK; orderId FK; fromStatus, toStatus, reason, actorType, actorId, occurredAt. | Must obey order state machine; belongs to 1 Order; index (orderId, occurredAt). |

Order rules: placement requires final validation and approved payment policy; cancellation is line-aware; snapshots are immutable.

### Payment: Payment aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Payment | Financial intent/settled balance. | id PK; orderId logical FK; provider, methodType, amountAuthorized/captured/refunded, currency, status, providerCustomerReference, version. | captured <= authorized and refunded <= captured; belongs to 1 Order; 1--* PaymentAttempt/Refund; indexes (orderId, status), (provider, status, createdAt). |
| PaymentAttempt | Provider interaction ledger. | id PK; paymentId FK; operation, idempotencyKey, providerTransactionId, status, requestedAmount, response/failure fields, initiatedAt, completedAt. | UQ provider transaction and payment/operation/key; belongs to 1 Payment; no PAN/CVV; index (paymentId, initiatedAt). |
| Refund | Monetary reversal. | id PK; paymentId FK; orderId logical FK; amount, currency, reason, status, providerRefundId, requestedAt, completedAt. | Positive amount; pending/completed total <= captured; belongs to 1 Payment; UQ providerRefundId, (paymentId, status). |

Payment rules: authenticated provider callbacks are idempotent; payment/order states are independent; only tokens and masked method details are stored.

### Shipment: Shipment aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Shipment | Fulfilment/carrier commitment. | id PK; orderId/warehouseId logical FK; shipmentNumber, carrierCode, serviceLevel, trackingNumber, status, shippingAddressSnapshot, estimate dates, shippedAt, deliveredAt. | UQ shipmentNumber and carrier/tracking when known; 1--* ShipmentItem/TrackingEvent; indexes (orderId, status), (warehouseId, status). |
| ShipmentItem | Order-line quantity in shipment. | id PK; shipmentId FK; orderItemId logical FK; quantity. | UQ(shipmentId, orderItemId); positive and total <= order item quantity; belongs to 1 Shipment; index (orderItemId). |
| TrackingEvent | Append-only progress event. | id PK; shipmentId FK; carrierEventCode, status, description, location, occurredAt, receivedAt, rawEventHash. | Deduplicated carrier input; belongs to 1 Shipment; UQ(shipmentId, carrierEventCode, occurredAt, rawEventHash), (shipmentId, occurredAt). |

Shipment rules: split shipments are supported; only order items ship; terminal delivery cannot regress without audited exception.

### Review: Review aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Review | Moderated product feedback. | id PK; customerId/productId/orderItemId logical FKs; rating, title, body, status, isVerifiedPurchase, helpfulCount, moderatedAt. | Rating 1--5; one review/customer/product/purchased line; 1--* ReviewMedia; indexes (productId, status, createdAt DESC), (customerId, createdAt DESC). |
| ReviewMedia | Review photo/video. | id PK; reviewId FK; mediaType, url, sortOrder, status, createdAt. | Policy-limited count/type; public only when approved; belongs to 1 Review; index (reviewId, sortOrder). |

Review rules: verified purchase requires a delivered owned line; edits retain history; catalog ratings are projections.

### Coupon: Coupon aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| Coupon | Code promotion. | id PK; code, name, discountType/value, currency, minimumOrderAmount, maximumDiscountAmount, validity range, usageLimit, perCustomerLimit, status, eligibilityRuleSnapshot. | UQ normalized code; percentage 0--100; fixed amount has currency; 1--* CouponRedemption; indexes UQ(code), (status, validFrom, validUntil). |
| CouponRedemption | Coupon reservation/consumption. | id PK; couponId FK; customerId/checkoutSessionId/orderId logical FKs; discountAmount, currency, status, reserved/redeemed/released times. | Checkout or order reference required while active; UQ coupon/checkout and coupon/order; indexes (couponId, status), (customerId, couponId, status). |

Coupon rules: server evaluates versioned eligibility; limits reserve atomically; failed checkout releases; refund does not automatically restore entitlement.

### Notification: NotificationPreference aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| NotificationPreference | Channel/topic consent. | id PK; customerId logical FK; channel, topic, status, source, legalTextVersion, changedAt. | UQ(customerId, channel, topic); belongs to 1 CustomerProfile; index (customerId, status). |
| Notification | Requested communication. | id PK; customerId logical FK nullable, recipient, channel, topic, templateCode/version, payloadReference, idempotencyKey, status, scheduledAt, sentAt. | UQ idempotencyKey; 1--* NotificationDelivery; indexes (status, scheduledAt), (customerId, createdAt DESC). |
| NotificationDelivery | Provider attempt/outcome. | id PK; notificationId FK; provider, providerMessageId, status, attemptNumber, failureReason, attemptedAt, deliveredAt. | UQ provider message and notification/attempt; belongs to 1 Notification; index (notificationId, attemptedAt). |

Notification rules: transactional messages bypass marketing consent; retry is bounded and callbacks are deduplicated.

### Audit: AuditLog aggregate

| Entity | Purpose | Fields and PK/FK | Constraints, relationships, and important indexes |
| --- | --- | --- | --- |
| AuditLog | Immutable security/business trace. | id PK; occurredAt, actorType/id, action, resourceType/id, correlationId, causationId, requestId, ipAddress, beforeHash, afterHash, metadata. | Append-only, redacted/hashed sensitive values; logical links to any aggregate; indexes (resourceType, resourceId, occurredAt DESC), (actorId, occurredAt DESC), (correlationId). |
| OutboxEvent | Reliable committed domain-event handoff. | id PK; aggregateType/id, eventType, payload, occurredAt, publishedAt, attemptCount, lastError. | Inserted atomically with owned aggregate change; idempotent consumer; index (publishedAt, occurredAt), optional UQ aggregate/event/time. |

## Global business rules

1. Catalog owns product truth, Inventory owns availability, and Order owns purchased snapshots; direct cross-context writes are forbidden.
2. Physical FKs apply within context; logical foreign keys must be application-validated and survive source archival/anonymization.
3. Do not delete financial, fulfilment, review, or audit history; use state transition, retention, and privacy anonymization.
4. Every retried command, webhook, and asynchronous consumer requires idempotency or deduplication.
5. All monetary totals reconcile atomically from lines, discount, shipping, tax, and grand total.
6. Order, payment, shipment, review, and notification changes use explicit state machines and append-only history where represented.

