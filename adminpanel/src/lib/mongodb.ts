import mongoose from 'mongoose';

const MONGODB_URI = process.env.MONGODB_URI || '';

interface MongooseCache {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
}

declare global {
  var mongoose: MongooseCache | undefined;
}

let cached: MongooseCache = global.mongoose || { conn: null, promise: null };

if (!global.mongoose) {
  global.mongoose = cached;
}

async function connectDB() {
  if (!MONGODB_URI) {
    throw new Error('Please define MONGODB_URI in .env file');
  }

  if (cached.conn) {
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false,
    };

    cached.promise = mongoose.connect(MONGODB_URI, opts).then(async (m) => {
      // Drop old email unique index if it exists — allows same email across different roles
      try {
        await m.connection.collection('users').dropIndex('email_1');
        console.log('Dropped old email_1 index');
      } catch (_) {}
      try {
        await m.connection.collection('users').dropIndex('email_1_role_1');
        console.log('Dropped old email_1_role_1 index');
      } catch (_) {}
      try {
        await m.connection.collection('users').dropIndex('phone_1');
        console.log('Dropped old phone_1 index');
      } catch (_) {}
      // Drop old non-sparse 2dsphere indexes
      try {
        await m.connection.collection('prescriptions').dropIndex('deliveryAddress.location_2dsphere');
      } catch (_) {}
      try {
        await m.connection.collection('riders').dropIndex('currentLocation_2dsphere');
      } catch (_) {}
      return m;
    });
  }

  try {
    cached.conn = await cached.promise;
  } catch (e) {
    cached.promise = null;
    throw e;
  }

  return cached.conn;
}

export default connectDB;
export { connectDB };
