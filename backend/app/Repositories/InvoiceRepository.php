<?php

namespace App\Repositories;

use App\Enums\InvoiceStatus;
use App\Models\Invoice;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class InvoiceRepository
{
    public function __construct(
        protected Invoice $model,
    ) {}

    public function findById(string $id): ?Invoice
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): Invoice
    {
        return $this->model->findOrFail($id);
    }

    public function findByIdWithRelations(string $id): Invoice
    {
        return $this->model
            ->with(['tenant', 'items.package', 'subscriptions.licenseTokens'])
            ->findOrFail($id);
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->with('tenant');

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('invoice_number', 'like', "%{$search}%")
                    ->orWhereHas('tenant', function ($tq) use ($search) {
                        $tq->where('name', 'like', "%{$search}%")
                            ->orWhere('email', 'like', "%{$search}%");
                    });
            });
        }

        if (! empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (! empty($filters['tenant_id'])) {
            $query->where('tenant_id', $filters['tenant_id']);
        }

        return $query->orderBy('created_at', 'desc')->paginate($perPage);
    }

    public function create(array $data): Invoice
    {
        return $this->model->create($data);
    }

    public function update(Invoice $invoice, array $data): bool
    {
        return $invoice->update($data);
    }

    public function count(): int
    {
        return $this->model->count();
    }

    public function countByStatus(InvoiceStatus $status): int
    {
        return $this->model->where('status', $status)->count();
    }
}
