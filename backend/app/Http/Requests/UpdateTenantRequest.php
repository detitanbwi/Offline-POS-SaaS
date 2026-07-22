<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UpdateTenantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $tenantId = $this->route('tenant')?->id ?? $this->route('tenant');

        return [
            'name' => 'required|string|max:255',
            'owner_name' => 'required|string|max:255',
            'email' => 'required|email|unique:tenants,email,'.$tenantId,
            'phone' => 'nullable|string|regex:/^[0-9]+$/|max:20',
            'store_name' => 'nullable|string|max:255',
            'store_address' => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex' => 'Nomor telepon/WhatsApp hanya boleh berupa angka.',
        ];
    }
}
