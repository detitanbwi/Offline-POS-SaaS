<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ActivateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'license_key' => 'required|string',
            'fingerprint_hash' => 'required|string|size:64',
            'device_name' => 'nullable|string',
            'device_model' => 'nullable|string',
            'device_brand' => 'nullable|string',
        ];
    }
}
