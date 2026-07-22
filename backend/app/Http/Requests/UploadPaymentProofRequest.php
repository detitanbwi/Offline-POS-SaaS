<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class UploadPaymentProofRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'payment_proof' => 'required|file|mimes:jpg,jpeg,png,pdf|max:5120',
        ];
    }

    public function messages(): array
    {
        return [
            'payment_proof.required' => 'File bukti transfer wajib diunggah.',
            'payment_proof.file' => 'Bukti transfer harus berupa file.',
            'payment_proof.mimes' => 'Format bukti transfer harus berupa JPG, JPEG, PNG, atau PDF.',
            'payment_proof.max' => 'Ukuran maksimal file bukti transfer adalah 5MB.',
        ];
    }
}
