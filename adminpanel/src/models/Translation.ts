import mongoose, { Schema, Document } from 'mongoose';

/**
 * Cache of machine-translated free text.
 *
 * Free text (a pharmacist's rejection reason, for example) is shown on every
 * list load, so without a cache the same sentence would be re-sent to the
 * translation provider on every request — slow, and billed per character.
 * Keyed by a hash of the source text plus the target language.
 */
export interface ITranslation extends Document {
  hash: string;
  sourceText: string;
  targetLang: string;
  translatedText: string;
  provider: string;
  createdAt: Date;
}

const TranslationSchema = new Schema<ITranslation>(
  {
    hash: {
      type: String,
      required: true,
    },
    sourceText: {
      type: String,
      required: true,
    },
    targetLang: {
      type: String,
      required: true,
    },
    translatedText: {
      type: String,
      required: true,
    },
    provider: {
      type: String,
      default: 'unknown',
    },
  },
  { timestamps: true }
);

TranslationSchema.index({ hash: 1 }, { unique: true });

export default mongoose.models.Translation ||
  mongoose.model<ITranslation>('Translation', TranslationSchema);
