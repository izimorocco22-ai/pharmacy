import crypto from 'crypto';
import connectDB from '@/lib/mongodb';
import Translation from '@/models/Translation';
import { type Lang } from '@/services/notification-i18n';

/**
 * Machine translation for FREE TEXT a human typed — a pharmacist's rejection
 * reason, for example. Everything the backend itself writes is translated from
 * the hand-written catalogue in notification-i18n.ts instead; this is only for
 * text we could not know in advance.
 *
 * Disabled by default (TRANSLATE_PROVIDER unset) and returns the original text
 * untouched. That is deliberate: turning it on sends text a pharmacist typed —
 * which can describe a patient's prescription — to a third-party service, so
 * it should be switched on knowingly rather than by default.
 *
 * To enable, set in the environment:
 *   TRANSLATE_PROVIDER = azure | google | deepl | libre
 *   TRANSLATE_API_KEY  = <key from that provider>          (not needed for libre)
 *   TRANSLATE_REGION   = <azure region, e.g. westeurope>   (azure only)
 *   TRANSLATE_URL      = <libre instance url>              (libre only)
 */

type Provider = 'none' | 'azure' | 'google' | 'deepl' | 'libre';

function provider(): Provider {
  const p = (process.env.TRANSLATE_PROVIDER || 'none').toLowerCase();
  return (['azure', 'google', 'deepl', 'libre'] as string[]).includes(p)
    ? (p as Provider)
    : 'none';
}

function cacheKey(text: string, target: string): string {
  return crypto.createHash('sha256').update(`${target}:${text}`).digest('hex');
}

/** Network calls are capped so a slow provider can never hang an API route. */
async function fetchWithTimeout(url: string, init: RequestInit, ms = 5000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

async function callProvider(text: string, target: Lang): Promise<string | null> {
  const key = process.env.TRANSLATE_API_KEY || '';

  switch (provider()) {
    case 'azure': {
      const region = process.env.TRANSLATE_REGION || 'global';
      const res = await fetchWithTimeout(
        `https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&to=${target}`,
        {
          method: 'POST',
          headers: {
            'Ocp-Apim-Subscription-Key': key,
            'Ocp-Apim-Subscription-Region': region,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify([{ Text: text }]),
        }
      );
      if (!res.ok) throw new Error(`azure ${res.status}`);
      const json = await res.json();
      return json?.[0]?.translations?.[0]?.text ?? null;
    }

    case 'google': {
      const res = await fetchWithTimeout(
        `https://translation.googleapis.com/language/translate/v2?key=${key}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ q: text, target, format: 'text' }),
        }
      );
      if (!res.ok) throw new Error(`google ${res.status}`);
      const json = await res.json();
      return json?.data?.translations?.[0]?.translatedText ?? null;
    }

    case 'deepl': {
      // Free keys end in ":fx" and must go to the free-tier host.
      const host = key.endsWith(':fx')
        ? 'https://api-free.deepl.com'
        : 'https://api.deepl.com';
      const res = await fetchWithTimeout(`${host}/v2/translate`, {
        method: 'POST',
        headers: {
          Authorization: `DeepL-Auth-Key ${key}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text: [text], target_lang: target.toUpperCase() }),
      });
      if (!res.ok) throw new Error(`deepl ${res.status}`);
      const json = await res.json();
      return json?.translations?.[0]?.text ?? null;
    }

    case 'libre': {
      const url = process.env.TRANSLATE_URL || 'https://libretranslate.com';
      const res = await fetchWithTimeout(`${url}/translate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          q: text,
          source: 'auto',
          target,
          format: 'text',
          ...(key ? { api_key: key } : {}),
        }),
      });
      if (!res.ok) throw new Error(`libre ${res.status}`);
      const json = await res.json();
      return json?.translatedText ?? null;
    }

    default:
      return null;
  }
}

/**
 * Translates one piece of free text, cached forever by (text, target).
 * Returns the original text unchanged if translation is disabled or fails —
 * showing the untranslated original is always better than showing nothing.
 */
export async function translateFreeText(
  text: string | undefined | null,
  target: Lang
): Promise<string> {
  const source = (text || '').trim();
  if (!source) return '';
  if (provider() === 'none') return source;

  const hash = cacheKey(source, target);

  try {
    await connectDB();
    const cached = await Translation.findOne({ hash }).lean() as any;
    if (cached?.translatedText) return cached.translatedText;
  } catch (e) {
    console.error('[translate] cache read failed:', e);
  }

  let translated: string | null = null;
  try {
    translated = await callProvider(source, target);
  } catch (e) {
    console.error('[translate] provider call failed:', e);
  }
  if (!translated) return source;

  try {
    // upsert, because two concurrent requests can race on the same text.
    await Translation.updateOne(
      { hash },
      {
        $setOnInsert: {
          hash,
          sourceText: source,
          targetLang: target,
          translatedText: translated,
          provider: provider(),
        },
      },
      { upsert: true }
    );
  } catch (e) {
    console.error('[translate] cache write failed:', e);
  }

  return translated;
}

/**
 * Translates several pieces of free text at once, de-duplicating first so a
 * reason repeated across twenty rows costs one call rather than twenty.
 */
export async function translateFreeTextBatch(
  texts: (string | undefined | null)[],
  target: Lang
): Promise<Map<string, string>> {
  const out = new Map<string, string>();
  if (provider() === 'none') {
    for (const t of texts) if (t) out.set(t, t);
    return out;
  }
  const unique = [...new Set(texts.filter((t): t is string => !!t && !!t.trim()))];
  await Promise.all(
    unique.map(async (t) => {
      out.set(t, await translateFreeText(t, target));
    })
  );
  return out;
}

/** True when a provider is configured — handy for surfacing status in admin. */
export function isTranslationEnabled(): boolean {
  return provider() !== 'none';
}
