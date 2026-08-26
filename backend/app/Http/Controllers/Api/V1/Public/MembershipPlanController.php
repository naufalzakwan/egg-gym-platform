<?php

namespace App\Http\Controllers\Api\V1\Public;

use App\Http\Controllers\Controller;
use App\Http\Resources\Api\V1\Public\MembershipPlanResource;
use App\Models\MembershipPlan;
use App\Services\Membership\MembershipPlanPopularityService;
use Illuminate\Http\JsonResponse;

class MembershipPlanController extends Controller
{
    public function __construct(
        private readonly MembershipPlanPopularityService $popularity,
    ) {}

    /**
     * Display a listing of active membership plans.
     */
    public function index(): JsonResponse
    {
        $plans = MembershipPlan::query()
            ->availableForPurchase()
            ->orderBy('price')
            ->get();
        $bestSellerPlanId = $this->popularity->bestSellerPlanId(
            fn ($query) => $query
                ->whereNull('membership_plans.deleted_at')
                ->availableForPurchase()
        );
        $plans->each->setAttribute('is_best_seller', false);
        if ($bestSellerPlanId !== null) {
            $plans->firstWhere('id', $bestSellerPlanId)?->setAttribute('is_best_seller', true);
        }

        return response()->json([
            'success' => true,
            'message' => 'Daftar paket membership berhasil diambil.',
            'data' => MembershipPlanResource::collection($plans),
            'meta' => null,
        ]);
    }
}
