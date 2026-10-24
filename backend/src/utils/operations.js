import mongoose from 'mongoose';
export const operationError = (res, error) => res.status(
  error.statusCode || (['CastError', 'ValidationError'].includes(error.name) ? 400 : error.code === 11000 ? 409 : 500)
).json({ success: false, message: error.message });
export const fail = (statusCode, message) => {
  throw Object.assign(new Error(message), { statusCode });
};
export const validateIds = (req, res, next) => {
  for (const source of [req.params, req.query, req.body]) {
    for (const key of ['id', 'businessId', 'branchId', 'tableId', 'bookingId', 'preOrderId']) {
      if (source?.[key] !== undefined && !mongoose.isObjectIdOrHexString(source[key])) {
        return res.status(400).json({ success: false, message: key + ' must be a valid ObjectId' });
      }
    }
  }
  next();
};
export const validDate = (value) => {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(value + 'T00:00:00Z');
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
};
export const validTime = (value) => typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
export const overlapFilter = (booking) => ({
  tableId: booking.tableId, bookingDate: booking.bookingDate,
  status: { $in: ['CONFIRMED', 'CHECKED_IN'] },
  startTime: { $lt: booking.endTime || '23:59' },
  $or: [{ endTime: { $gt: booking.startTime } }, { endTime: { $exists: false } }, { endTime: null }],
});
