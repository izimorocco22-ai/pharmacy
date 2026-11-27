import Rider from '@/models/Rider';

/** How many riders one delivery is announced to. */
const MAX_RIDERS_NOTIFIED = 20;

/** Riders within this radius of the pharmacy are preferred. */
const NEARBY_RADIUS_METRES = 50000;

/**
 * The riders to announce a new delivery to.
 *
 * Deliberately does NOT filter on `isOnline`. A push notification exists to
 * reach a rider who does not currently have the app open — filtering those out
 * meant an offline rider only ever discovered work by opening the app and
 * looking, which is exactly the complaint from the field. Riders already on a
 * delivery are still skipped via `isAvailable`, and unapproved riders never get
 * work announced to them.
 *
 * Riders with a known location are preferred; if the geo query matches nobody
 * (a rider whose `currentLocation` was never set cannot match `$near`), it
 * falls back to any approved, free rider so a delivery is never left
 * unannounced.
 */
export async function findRidersToNotify(
  pharmacyLocation?: { type: string; coordinates: number[] } | null
): Promise<any[]> {
  const base = { isAvailable: true, approvalStatus: 'approved' as const };

  if (pharmacyLocation) {
    try {
      const nearby = await Rider.find({
        ...base,
        currentLocation: {
          $near: {
            $geometry: pharmacyLocation,
            $maxDistance: NEARBY_RADIUS_METRES,
          },
        },
      }).limit(MAX_RIDERS_NOTIFIED);
      if (nearby.length > 0) return nearby;
    } catch (_) {
      // A missing 2dsphere index or an unset location throws here; fall through.
    }
  }

  return Rider.find(base).limit(MAX_RIDERS_NOTIFIED);
}
