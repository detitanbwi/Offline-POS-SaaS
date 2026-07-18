<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class ValidateTokenRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'token_key' => 'required|string|max:30',
            'fingerprint_hash' => 'required|string|size:64',
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
