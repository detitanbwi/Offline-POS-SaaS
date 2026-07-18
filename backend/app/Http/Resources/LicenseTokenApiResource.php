<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LicenseTokenApiResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'token_key' => $this->token_key,
            'status' => $this->status->value ?? $this->status,
            'activated_at' => $this->activated_at?->toIso8601String(),
            'last_validated_at' => $this->last_validated_at?->toIso8601String(),
            'subscription' => [
                'package_name' => $this->subscription?->package_name,
                'expiry_date' => $this->subscription?->expiry_date?->toDateString(),
            ],
        ];
    }
}
