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
            'customer_type' => 'required|in:individual,company',
            'tax_number' => 'nullable|string|max:50',
            'owner_name' => 'required|string|max:255',
            'email' => 'required|email|unique:tenants,email,'.$tenantId,
            'phone' => 'nullable|string|regex:/^[0-9]+$/|max:20',
            'store_name' => 'nullable|string|max:255',
            'store_address' => 'nullable|string|max:500',
            'city' => 'nullable|string|max:100',
            'postal_code' => 'nullable|string|max:20',
            'password' => 'nullable|string|min:6|confirmed',
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex' => 'Nomor telepon/WhatsApp hanya boleh berupa angka.',
            'password.min' => 'Password baru minimal harus 6 karakter.',
            'password.confirmed' => 'Konfirmasi password baru tidak cocok.',
        ];
    }
}
