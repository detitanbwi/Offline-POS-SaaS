<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class CreateTenantRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => 'required|string|max:255',
            'owner_name' => 'required|string|max:255',
            'email' => 'required|email|unique:tenants,email',
            'phone' => 'nullable|string|regex:/^[0-9]+$/|max:20',
            'store_name' => 'nullable|string|max:255',
            'store_address' => 'nullable|string|max:500',
            'password' => 'required|string|min:6',
            'package_id' => 'required|exists:packages,id',
        ];
    }

    public function messages(): array
    {
        return [
            'phone.regex' => 'Nomor telepon/WhatsApp hanya boleh berupa angka.',
            'package_id.required' => 'Silakan pilih paket untuk tenant.',
        ];
    }
}
