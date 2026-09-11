<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreLicenseOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'customer_mode' => $this->input('customer_mode', $this->filled('customer_id') ? 'existing' : 'new'),
            'customer_type' => $this->input('customer_type', 'individual'),
            'quantity' => (int) $this->input('quantity', 1),
            'payment_status' => $this->input('payment_status', 'paid'),
        ]);
    }

    public function rules(): array
    {
        $isNew = $this->input('customer_mode') === 'new';

        $rules = [
            'customer_mode' => 'required|in:existing,new',
            'package_id' => 'required|exists:packages,id',
            'quantity' => 'required|integer|min:1|max:100',
            'payment_status' => 'required|in:paid,unpaid',
            'client_note' => 'nullable|string|max:255',
        ];

        if ($isNew) {
            $rules['customer_type'] = 'required|in:individual,company';
            $rules['name'] = 'required|string|max:255';
            $rules['owner_name'] = 'required|string|max:255';
            $rules['email'] = 'required|email|max:255|unique:tenants,email|unique:users,email';
            $rules['password'] = 'required|string|min:6';
            $rules['phone'] = 'nullable|string|regex:/^[0-9]+$/|max:20';
            $rules['tax_number'] = 'nullable|string|max:50';
            $rules['store_name'] = 'nullable|string|max:255';
            $rules['store_address'] = 'nullable|string|max:500';
            $rules['city'] = 'nullable|string|max:100';
            $rules['postal_code'] = 'nullable|string|max:20';
        } else {
            $rules['customer_id'] = 'required|exists:tenants,id';
        }

        return $rules;
    }

    public function messages(): array
    {
        return [
            'customer_mode.required' => 'Pilih mode pelanggan (Pelanggan Lama atau Baru).',
            'customer_id.required' => 'Silakan pilih data pelanggan yang sudah terdaftar.',
            'customer_id.exists' => 'Data pelanggan yang dipilih tidak valid.',
            'customer_type.required' => 'Pilih tipe pelanggan (Pribadi / Perusahaan).',
            'name.required' => 'Nama bisnis / perusahaan wajib diisi.',
            'owner_name.required' => 'Nama pemilik / PIC wajib diisi.',
            'email.required' => 'Email kredensial login wajib diisi.',
            'email.unique' => 'Email ini sudah terdaftar di sistem.',
            'password.required' => 'Password wajib diisi (minimal 6 karakter).',
            'phone.regex' => 'Nomor WhatsApp / telepon hanya boleh berupa angka.',
            'package_id.required' => 'Silakan pilih paket lisensi SaaS.',
            'quantity.required' => 'Jumlah lisensi wajib diisi.',
            'quantity.min' => 'Jumlah lisensi minimal 1 unit.',
            'quantity.max' => 'Jumlah lisensi maksimal 100 unit per transaksi.',
            'payment_status.required' => 'Silakan pilih status pembayaran lisensi.',
        ];
    }
}
