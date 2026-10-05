import test, { afterEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import mongoose from 'mongoose';
import http from 'node:http';
import { Booking, Branch, Business, Table, Order, Product, Menu, Cart, Notification, UserInteraction, User } from '../src/models/index.js';
import { branchOwnerOnly, protect } from '../src/middlewares/auth.js';
import { validateIds } from '../src/utils/operations.js';
import { createBooking, getBranchBookings, updateBookingStatus, checkInBooking } from '../src/controllers/bookingController.js';
import { createOrder, getBranchOrders, updateOrderStatus } from '../src/controllers/orderController.js';
import { getTables, deleteTable, updateTable } from '../src/controllers/tableController.js';
import { initSocket, emitBookingUpdate } from '../src/socket.js';

const id = (n) => String(n).padStart(24, '0');
const query = (value) => {
  const promise = Promise.resolve(value);
  for (const key of ['session', 'select', 'populate', 'sort', 'distinct']) promise[key] = () => promise;
  return promise;
};
const res = () => ({
  code: 200, status(code) { this.code = code; return this; },
  json(body) { this.body = body; return this; },
});
const req = (body = {}) => ({
  user: { _id: id(1), role: 'BUSINESS_OWNER' },
  params: { id: id(2) }, body, query: {}, baseUrl: '/api/owner', path: '/orders/' + id(2) + '/status',
});
afterEach(() => mock.restoreAll());
function bookingFixture(status = 'CONFIRMED') {
  const booking = {
    _id: id(2), userId: id(3), businessId: id(4), branchId: id(5), tableId: id(6),
    status, guestCount: 4, bookingDate: '2099-12-01', startTime: '18:00', endTime: '20:00',
    bookingCode: 'TEST', save: mock.fn(async () => {}), populate: async () => {},
  };
  mock.method(mongoose.connection, 'transaction', async (callback) => callback({}));
  mock.method(Booking, 'findById', () => query(booking));
  mock.method(Business, 'exists', () => query({ _id: id(4) }));
  mock.method(Notification, 'create', async () => ({}));
  return booking;
}
test('owner cannot spoof branchId when updating another owner table', async () => {
  mock.method(Table, 'findById', () => query({ branchId: id(8) }));
  mock.method(Branch, 'findById', (branchId) => {
    assert.equal(branchId, id(8)); return query({ businessId: id(9) });
  });
  mock.method(Business, 'findById', () => query({ ownerId: id(10) }));
  const request = req({ branchId: id(5) }); request.baseUrl = '/api/tables';
  const response = res(); let next = false;
  await branchOwnerOnly(request, response, () => { next = true; });
  assert.equal(response.code, 403); assert.equal(next, false);
});
test('owner middleware derives booking ownership from target on owner route', async () => {
  mock.method(Booking, 'findById', () => query({ branchId: id(8) }));
  mock.method(Branch, 'findById', (branchId) => {
    assert.equal(branchId, id(8)); return query({ businessId: id(9) });
  });
  mock.method(Business, 'findById', () => query({ ownerId: id(10) }));
  const request = req({ branchId: id(5) }); request.path = '/bookings/' + id(2);
  const response = res();
  await branchOwnerOnly(request, response, () => assert.fail('must not authorize'));
  assert.equal(response.code, 403);
});
for (const [name, controller, model] of [
  ['bookings', getBranchBookings, Booking], ['orders', getBranchOrders, Order],
]) {
  test('legacy branch ' + name + ' accepts a legitimate owner', async () => {
    mock.method(Branch, 'findById', () => query({ businessId: id(4) }));
    mock.method(Business, 'findById', () => query({ ownerId: id(1) }));
    mock.method(Branch, 'exists', (filter) => {
      assert.deepEqual(filter.businessId.$in, [id(4)]); return query({});
    });
    mock.method(model, 'find', () => query([]));
    const request = req(); request.params = { branchId: id(5) }; request.baseUrl = '/api/' + name;
    const response = res(); let authorized = false;
    await branchOwnerOnly(request, response, () => { authorized = true; });
    assert.equal(authorized, true);
    await controller(request, response);
    assert.equal(response.code, 200); assert.deepEqual(response.body.data, []);
  });
  test('owner ' + name + ' listing rejects a foreign query branch', async () => {
    mock.method(Branch, 'exists', () => query(null));
    const request = req(); request.params = {}; request.query.branchId = id(8); request.ownerBusinessIds = [id(4)];
    const response = res(); await controller(request, response); assert.equal(response.code, 403);
  });
}
test('x-user-id cannot authenticate in production', async () => {
  const old = process.env.NODE_ENV; process.env.NODE_ENV = 'production';
  try {
    const response = res();
    await protect({ headers: { 'x-user-id': id(1) } }, response, () => assert.fail('must not authenticate'));
    assert.equal(response.code, 401);
  } finally { if (old === undefined) delete process.env.NODE_ENV; else process.env.NODE_ENV = old; }
});
test('invalid resource id fails before database access', () => {
  const response = res();
  validateIds({ params: { id: 'bad' }, body: {}, query: {} }, response, () => assert.fail('must reject'));
  assert.equal(response.code, 400);
});
test('booking date and time reject malformed values before database access', async () => {
  const response = res();
  await createBooking({ user: { role: 'CUSTOMER' }, body: {
    businessId: id(4), branchId: id(5), bookingDate: '2099-02-30', startTime: 1800,
  } }, response);
  assert.equal(response.code, 400);
});
test('customer cannot confirm own booking', async () => {
  bookingFixture('PENDING');
  mock.method(Business, 'exists', () => query(null));
  const request = req({ status: 'CONFIRMED' }); request.user = { _id: id(3), role: 'CUSTOMER' };
  const response = res(); await updateBookingStatus(request, response); assert.equal(response.code, 403);
});
test('cancelling pending booking never releases another reservation', async () => {
  const booking = bookingFixture('PENDING');
  mock.method(Business, 'exists', () => query(null));
  mock.method(Table, 'findByIdAndUpdate', () => assert.fail('must not release a table'));
  const request = req({ status: 'CANCELLED' }); request.user = { _id: id(3), role: 'CUSTOMER' };
  const response = res(); await updateBookingStatus(request, response);
  assert.equal(response.code, 200); assert.equal(booking.status, 'CANCELLED');
});
test('check-in conflict occurs before saving booking', async () => {
  const booking = bookingFixture();
  mock.method(Table, 'findOneAndUpdate', async () => null);
  const response = res(); await checkInBooking(req(), response);
  assert.equal(response.code, 409); assert.equal(booking.status, 'CONFIRMED');
  assert.equal(booking.save.mock.calls.length, 0);
});
test('check-in updates table and booking in the same session', async () => {
  const booking = bookingFixture();
  mock.method(Table, 'findOneAndUpdate', async (filter, update, options) => {
    assert.equal(filter.status, 'RESERVED'); assert.equal(update.status, 'UNAVAILABLE'); assert.ok(options.session);
    return {};
  });
  const response = res(); await checkInBooking(req(), response);
  assert.equal(response.code, 200); assert.equal(booking.status, 'CHECKED_IN'); assert.ok(booking.checkedInAt);
});
test('overlapping table reservation cannot be confirmed', async () => {
  const booking = bookingFixture('PENDING');
  mock.method(Table, 'findOne', () => query({ _id: id(6), capacity: 4, status: 'RESERVED' }));
  mock.method(Booking, 'exists', () => query({}));
  const response = res(); await updateBookingStatus(req({ status: 'CONFIRMED' }), response);
  assert.equal(response.code, 409); assert.equal(booking.save.mock.calls.length, 0);
});
test('nonoverlapping reservation may use an already reserved table', async () => {
  bookingFixture('PENDING');
  const table = { _id: id(6), capacity: 4, status: 'RESERVED', markModified() {}, save: async () => {} };
  mock.method(Table, 'findOne', () => query(table));
  mock.method(Booking, 'exists', (filter) => {
    assert.equal(filter.bookingDate, '2099-12-01');
    assert.equal(filter.startTime.$lt, '20:00');
    assert.equal(filter.$or[0].endTime.$gt, '18:00');
    return query(null);
  });
  const response = res(); await updateBookingStatus(req({ status: 'CONFIRMED' }), response);
  assert.equal(response.code, 200);
});
test('completed booking cannot be reopened', async () => {
  bookingFixture('COMPLETED');
  const response = res(); await updateBookingStatus(req({ status: 'CONFIRMED' }), response);
  assert.equal(response.code, 400);
});
test('table availability excludes overlapping reservations and filters capacity', async () => {
  mock.method(Booking, 'find', () => query([id(6)]));
  mock.method(Table, 'find', (filter) => {
    assert.deepEqual(filter._id.$nin, [id(6)]); assert.equal(filter.capacity.$gte, 4);
    assert.deepEqual(filter.status.$in, ['AVAILABLE', 'RESERVED']); return query([]);
  });
  const response = res();
  await getTables({ query: { branchId: id(5), bookingDate: '2099-12-01', startTime: '18:00', endTime: '20:00', guestCount: '4' } }, response);
  assert.equal(response.code, 200);
});
test('cannot delete a table referenced by an active pending booking', async () => {
  mock.method(mongoose.connection, 'transaction', async (callback) => callback({}));
  mock.method(Table, 'findById', () => query({ _id: id(6), status: 'AVAILABLE' }));
  mock.method(Booking, 'exists', () => query({}));
  mock.method(Table, 'deleteOne', () => assert.fail('must not delete'));
  const response = res(); await deleteTable(req(), response); assert.equal(response.code, 409);
});
test('cannot reduce capacity below active booking guest count', async () => {
  mock.method(mongoose.connection, 'transaction', async (callback) => callback({}));
  mock.method(Table, 'findById', () => query({ _id: id(6), status: 'RESERVED' }));
  mock.method(Booking, 'find', () => query([{ guestCount: 6 }]));
  const response = res(); await updateTable(req({ capacity: 4 }), response); assert.equal(response.code, 409);
});
function orderFixture(status = 'PENDING') {
  const order = { _id: id(2), businessId: id(4), userId: id(3), orderCode: 'TEST', status };
  mock.method(Order, 'findById', async () => order);
  mock.method(Business, 'exists', async () => ({}));
  mock.method(Notification, 'create', async () => ({}));
  return order;
}
for (const [from, to] of [
  ['PENDING', 'CONFIRMED'], ['CONFIRMED', 'PREPARING'], ['PREPARING', 'READY'],
  ['READY', 'SERVED'], ['SERVED', 'COMPLETED'], ['PENDING', 'CANCELLED'],
]) {
  test('order transition ' + from + ' -> ' + to, async () => {
    orderFixture(from);
    mock.method(Order, 'findOneAndUpdate', async (filter, update) => {
      assert.equal(filter.status, from); assert.equal(update.status, to); return { status: to };
    });
    const response = res(); await updateOrderStatus(req({ status: to }), response);
    assert.equal(response.code, 200); assert.equal(response.body.data.status, to);
  });
}
test('concurrent order status change returns conflict', async () => {
  orderFixture(); mock.method(Order, 'findOneAndUpdate', async () => null);
  const response = res(); await updateOrderStatus(req({ status: 'CONFIRMED' }), response);
  assert.equal(response.code, 409);
});
test('cannot skip order preparation steps', async () => {
  orderFixture(); const response = res(); await updateOrderStatus(req({ status: 'COMPLETED' }), response);
  assert.equal(response.code, 400);
});
function checkoutFixture(menuOverrides = {}) {
  mock.method(Branch, 'findById', async () => ({ businessId: id(4), status: 'ACTIVE' }));
  mock.method(Business, 'findById', async () => ({ status: 'APPROVED' }));
  mock.method(Product, 'findById', async () => ({
    _id: id(7), menuId: id(8), branchId: id(5), name: 'Tea', price: 100, isAvailable: true,
    sizes: [{ name: 'L', price: 150 }],
    options: [{ name: 'Topping', isMultiple: false, required: true, values: [{ name: 'Pearl', price: 20 }] }],
  }));
  mock.method(Menu, 'findById', () => query({ businessId: id(4), status: 'ACTIVE', ...menuOverrides }));
  mock.method(Cart, 'findOneAndDelete', async () => null);
  mock.method(UserInteraction, 'create', async () => ({}));
}
const checkoutReq = (items) => ({ user: { _id: id(3), role: 'CUSTOMER' }, body: { businessId: id(4), branchId: id(5), items } });
test('checkout ignores forged prices and computes selected size/options', async () => {
  checkoutFixture();
  mock.method(Order, 'create', async (data) => {
    assert.equal(data.total, 340); assert.equal(data.items[0].unitPrice, 150); return data;
  });
  const response = res();
  await createOrder(checkoutReq([{ productId: id(7), quantity: 2, unitPrice: 1, selectedSize: { name: 'L', price: 1 },
    selectedOptions: [{ name: 'Topping', value: 'Pearl', additionalPrice: 0 }] }]), response);
  assert.equal(response.code, 201); assert.equal(response.body.data.total, 340);
});
test('inactive menu cannot sell products even with matching product branch', async () => {
  checkoutFixture({ status: 'INACTIVE' });
  const response = res(); await createOrder(checkoutReq([{ productId: id(7), quantity: 1 }]), response);
  assert.equal(response.code, 400);
});
test('foreign business menu cannot sell products even with matching product branch', async () => {
  checkoutFixture({ businessId: id(9) });
  const response = res(); await createOrder(checkoutReq([{ productId: id(7), quantity: 1 }]), response);
  assert.equal(response.code, 400);
});
test('duplicate product options cannot alter price', async () => {
  checkoutFixture(); const response = res();
  await createOrder(checkoutReq([{ productId: id(7), quantity: 1, selectedOptions: [
    { name: 'Topping', value: 'Pearl' }, { name: 'Topping', value: 'Pearl' },
  ] }]), response);
  assert.equal(response.code, 400);
});
test('private booking event reaches only owner and customer rooms', async () => {
  const server = http.createServer(); const io = initSocket(server);
  try {
    const rooms = [];
    mock.method(io, 'to', (room) => { rooms.push(room); return { emit() {} }; });
    mock.method(io, 'emit', () => assert.fail('must not broadcast private booking globally'));
    emitBookingUpdate(id(4), { userId: id(3) }, 'updated');
    assert.deepEqual(rooms, ['business:' + id(4), 'user:' + id(3)]);
  } finally { await new Promise((resolve) => io.close(resolve)); }
});
