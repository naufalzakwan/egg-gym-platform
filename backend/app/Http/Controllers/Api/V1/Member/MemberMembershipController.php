<?php

namespace App\Http\Controllers\Api\V1\Member;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Member\MemberMembershipResource;
use App\Models\MemberMembership;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MemberMembershipController extends Controller
{
    /**
     * Display the authenticated member memberships.
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $memberships = MemberMembership::query()
            ->with('membershipPlan')
            ->whereHas('memberProfile', function ($query) use ($user) {
                $query->where('user_id', $user->id);
            })
            ->latest('end_date')
            ->get();

        // Paket yang aktif HARI INI (untuk kartu active_membership).
        $activeMembership = $memberships
            ->filter(fn ($m) => $m->isCurrentlyActive())
            ->sortByDesc(fn ($m) => $m->end_date->getTimestamp())
            ->first();

        // Sisa hari & tanggal akhir dari UJUNG rantai membership kontigu
        // (mencakup pembelian yang di-stack ke depan), konsisten dgn dashboard.
        $chainEndDate = MemberMembership::activeChainEndDate($memberships);
        $chainRemainingDays = MemberMembership::remainingDaysForMember($memberships);

        $activeMembershipResource = null;
        if ($activeMembership) {
            $activeMembershipResource = new MemberMembershipResource($activeMembership);
            $activeMembershipResource->chainRemainingDaysOverride = $chainRemainingDays;
            $activeMembershipResource->chainEndDateOverride = $chainEndDate;
        }

        return response()->json([
            'success' => true,
            'message' => 'Data membership member berhasil diambil.',
            'data' => [
                'active_membership' => $activeMembershipResource,
                'history' => MemberMembershipResource::collection($memberships),
                'summary' => [
                    'total_memberships' => $memberships->count(),
                    'has_active_membership' => $activeMembership !== null,
                ],
            ],
            'meta' => null,
        ]);
    }
}
