import mongoose from 'mongoose';

let connectionPromise;

export const connectDB = async () => {
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }

  if (connectionPromise) {
    return connectionPromise;
  }

  const uri = process.env.MONGODB_URI
    || (process.env.NODE_ENV === 'production' ? '' : 'mongodb://localhost:27017/fconnect');
  if (!uri) {
    throw new Error('MONGODB_URI must be configured in production');
  }

  connectionPromise = mongoose.connect(uri)
    .then((conn) => {
      console.log(`✅ MongoDB Connected: ${conn.connection.host}`);
      return conn;
    })
    .catch((error) => {
      connectionPromise = undefined;
      console.error(`❌ MongoDB Connection Error: ${error.message}`);
      throw error;
    });

  return connectionPromise;
};
