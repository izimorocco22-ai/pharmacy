import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import { successResponse, unauthorizedResponse, errorResponse } from '@/lib/response';
import { processTimedOutPrescriptions } from '@/services/reassignment';

export const dynamic = 'force-dynamic';

// Called on a schedule so requests move to the next pharmacy even when no
// app is open. Requires `Authorization: Bearer <CRON_SECRET>` (Vercel Cron
// sends this automatically when CRON_SECRET is set).
export async function GET(request: NextRequest) {
  const secret = process.env.CRON_SECRET;
  if (!secret || request.headers.get('authorization') !== `Bearer ${secret}`) {
    return unauthorizedResponse();
  }
  try {
    await connectDB();
    const handled = await processTimedOutPrescriptions();
    return successResponse({ handled }, `Processed ${handled} timed-out request(s)`);
  } catch (error) {
    console.error('Reassign cron error:', error);
    return errorResponse('Failed to process timed-out requests', 500);
  }
}
