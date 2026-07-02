import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import PharmacySettlement from '@/models/PharmacySettlement';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// Remove a recorded settlement (undo a payment/adjustment).
export async function DELETE(
  _request: NextRequest,
  { params }: { params: { id: string; settlementId: string } },
) {
  try {
    await connectDB();
    const deleted = await PharmacySettlement.findByIdAndDelete(params.settlementId);
    if (!deleted) return errorResponse('Settlement not found', 404);
    return successResponse({ ok: true }, 'Settlement removed');
  } catch (error) {
    console.error('Delete settlement error:', error);
    return errorResponse('Failed to remove settlement', 500);
  }
}
