<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateInvoiceRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'tenant_id' => 'required|uuid|exists:tenants,id',
            'items' => 'required|array|min:1',
            'items.*.package_id' => 'required|uuid|exists:packages,id',
            'items.*.quantity' => 'required|integer|min:1|max:20',
            'items.*.duration_days' => 'nullable|integer|min:1',
            'notes' => 'nullable|string|max:1000',
        ];
    }

    public function messages(): array
    {
        return [
            'tenant_id.required' => 'Tenant wajib dipilih.',
            'items.required' => 'Minimal satu paket harus dipilih.',
            'items.*.package_id.required' => 'Paket wajib dipilih.',
            'items.*.quantity.min' => 'Kuantitas minimal 1.',
            'items.*.quantity.max' => 'Kuantitas maksimal 20.',
        ];
    }
}
