<?php

namespace App\Services\Payment;

use App\Models\MembershipPaymentMethod;

class MembershipPaymentMethodService
{
    public function resolveActive(string $requestedCode, PakasirService $pakasir): ?MembershipPaymentMethod
    {
        $providerCode = $pakasir->normalizeMethod($requestedCode);
        if ($providerCode === null) {
            return null;
        }

        return MembershipPaymentMethod::query()
            ->where('provider', 'pakasir')
            ->where('provider_code', $providerCode)
            ->where('is_active', true)
            ->first();
    }
}
