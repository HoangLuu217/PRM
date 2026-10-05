# FConnect PRM393: Booking, Table, Order

Flutter uses CUSTOMER / BUSINESS_OWNER; legacy USER / MERCHANT accounts remain compatible.
Owner operations require actual ownership. Admin remains supported for the EXE Web Admin.

## Customer API
- POST /api/bookings: businessId, branchId, optional tableId, bookingDate (YYYY-MM-DD),
  startTime/endTime (HH:mm), guestCount, optional note/preOrderId.
  endTime defaults to 23:59. Bookings must be in the future, Asia/Ho_Chi_Minh.
- GET /api/bookings/me; GET /api/bookings/:id.
- PUT /api/bookings/:id with status CANCELLED: own PENDING/CONFIRMED bookings only.
- GET /api/tables?branchId=...&bookingDate=2026-12-01&startTime=18:00&endTime=20:00&guestCount=4
  filters by capacity and overlapping confirmed bookings.
  Availability is advisory; confirmation rechecks inside a transaction.
- POST /api/orders: businessId, branchId, orderType, items, optional bookingId/tableId/note.
  Items: productId, quantity, optional selectedSize {name}, selectedOptions [{name,value}].
  Prices come from the active menu. Client discounts are not accepted.
- GET /api/orders/me; GET /api/orders/:id (poll to track status).

## Owner API
- POST /api/tables; PUT /api/tables/:id; DELETE /api/tables/:id.
  Active bookings prevent deletion, status overrides and incompatible capacity reduction.
- GET /api/owner/bookings; GET /api/owner/orders.
  Optional branchId must belong to owner; otherwise lists all owned branches.
  Bookings accept status/bookingDate; orders accept status/orderType.
- PUT /api/owner/bookings/:id with status and optional tableId for confirmation.
- PUT /api/owner/orders/:id/status with status.
- Legacy branch list routes and POST /api/bookings/:id/checkin remain supported.

Booking: PENDING -> CONFIRMED / REJECTED / CANCELLED;
CONFIRMED -> CHECKED_IN / CANCELLED; CHECKED_IN -> COMPLETED.
Order: PENDING -> CONFIRMED -> PREPARING -> READY -> SERVED -> COMPLETED.
Owner may cancel PENDING/CONFIRMED orders. Closed states cannot reopen.

RESERVED denotes confirmed reservations, potentially on different dates.
UNAVAILABLE denotes occupied/unavailable tables.
Nonoverlapping reservations may share a table.
Legacy bookings without endTime conservatively block until end of day.
Overnight booking windows are not supported; use a same-day endTime.

Responses: {success,data}; lists include count.
400 invalid input/transition; 401 login required; 403 unauthorized;
404 missing resource; 409 conflict.

## Runtime and verification
Booking transitions and table updates/deletions require MongoDB Atlas or a replica set.
Standalone MongoDB does not support transactions.
Development x-user-id auth requires NODE_ENV=development and ALLOW_DEV_AUTH=true.
Socket.IO now requires handshake auth: {token: JWT}; owner joins join:business
only for owned businesses. Customers automatically join their own user room.
Booking payloads are no longer broadcast globally. Existing EXE socket clients
must provide the JWT when connecting.
Run npm test for offline regression tests with mocked database operations.
Live MongoDB rollback/concurrency testing is still required.

## Wider brief
Staff, AI, review/rating inherited from EXE still exist; Flutter PRM393 should not use them.
Chat, dashboard, menu management and admin integration are outside this Member 4 audit.
