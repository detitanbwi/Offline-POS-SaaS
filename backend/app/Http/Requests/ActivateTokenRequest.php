<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ActivateTokenRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if (!$this->has('token_key') && $this->has('license_key')) {
            $this->merge([
                'token_key' => $this->input('license_key'),
            ]);
        }
    }

    public function rules(): array
    {
        return [
            'token_key' => 'required|string|max:50',
            'fingerprint_hash' => 'required|string|size:64',
            'android_id_hash' => 'nullable|string|size:64',
            'manufacturer' => 'nullable|string|max:255',
            'brand' => 'nullable|string|max:255',
            'model' => 'nullable|string|max:255',
            'installation_uuid_hash' => 'nullable|string|size:64',
        ];
    }

    public function messages(): array
    {
        return [
            'token_key.required' => 'Token lisensi wajib diisi.',
            'fingerprint_hash.required' => 'Fingerprint hash wajib diisi.',
            'fingerprint_hash.size' => 'Fingerprint hash harus 64 karakter SHA-256.',
        ];
    }
}
