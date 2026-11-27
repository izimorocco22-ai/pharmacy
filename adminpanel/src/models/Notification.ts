import mongoose, { Schema, Document } from 'mongoose';

export interface INotification extends Document {
  userId: mongoose.Types.ObjectId;
  title: string;
  body: string;
  // Granular event type, e.g. 'quote_received', 'rider_assigned', 'order_delivered'.
  // Kept as a free-form string so new event types don't need a schema change.
  type: string;
  data?: Record<string, any>;
  // Translation key + params this notification was built from. Stored so the
  // in-app list can be re-rendered in the user's CURRENT language: title/body
  // below are only a snapshot of the language they used when it was sent.
  // Absent on notifications created before localization existed.
  key?: string;
  params?: Record<string, any>;
  isRead: boolean;
  createdAt: Date;
}

const NotificationSchema = new Schema<INotification>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
    body: {
      type: String,
      required: true,
    },
    type: {
      type: String,
      default: 'general',
    },
    data: {
      type: Schema.Types.Mixed,
    },
    key: {
      type: String,
    },
    params: {
      type: Schema.Types.Mixed,
    },
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

NotificationSchema.index({ userId: 1, createdAt: -1 });
NotificationSchema.index({ isRead: 1 });

export default mongoose.models.Notification || mongoose.model<INotification>('Notification', NotificationSchema);
