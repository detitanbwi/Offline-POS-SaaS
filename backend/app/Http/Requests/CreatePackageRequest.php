<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreatePackageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $packageId = $this->route('package')?->id ?? $this->route('package');

        return [
            'name' => 'required|string|max:255',
            'slug' => 'nullable|string|max:255|unique:packages,slug,'.$packageId,
            'price' => 'required|numeric|min:0',
            'validity_type' => 'required|string|in:duration,date_range,fixed_date',
            'default_duration_days' => 'required_if:validity_type,duration|nullable|integer|min:1',
            'start_date' => 'required_if:validity_type,date_range|nullable|date',
            'end_date' => 'required_if:validity_type,date_range,fixed_date|nullable|date',
            'device_limit_per_token' => 'required|integer|min:1',
            'description' => 'nullable|string|max:1000',
            'is_active' => 'boolean',
        ];
    }
}
