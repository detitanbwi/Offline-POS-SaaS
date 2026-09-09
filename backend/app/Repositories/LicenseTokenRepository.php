<?php

namespace App\Repositories;

use App\Enums\TokenStatus;
use App\Models\LicenseToken;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class LicenseTokenRepository
{
    public function __construct(
        protected LicenseToken $model,
    ) {}

    public function findById(string $id): ?LicenseToken
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): LicenseToken
    {
        return $this->model->findOrFail($id);
    }

    public function findByTokenKey(string $tokenKey): ?LicenseToken
    {
        return $this->model->where('token_key', $tokenKey)->first();
    }

    public function findByTokenKeyWithRelations(string $tokenKey): ?LicenseToken
    {
        return $this->model
            ->with(['subscription.package', 'subscription.invoiceItem.invoice', 'tenant', 'device'])
            ->where('token_key', $tokenKey)
            ->first();
    }

    public function findByIdWithRelations(string $id): LicenseToken
    {
        return $this->model
            ->with(['subscription.package', 'subscription.invoiceItem.invoice', 'tenant', 'device'])
            ->findOrFail($id);
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->with(['subscription', 'tenant', 'device']);

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('token_key', 'like', "%{$search}%")
                    ->orWhereHas('tenant', function ($tq) use ($search) {
                        $tq->where('name', 'like', "%{$search}%");
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

    public function create(array $data): LicenseToken
    {
        return $this->model->create($data);
    }

    public function update(LicenseToken $token, array $data): bool
    {
        return $token->update($data);
    }

    public function count(): int
    {
        return $this->model->count();
    }

    public function countByStatus(TokenStatus $status): int
    {
        return $this->model->where('status', $status)->count();
    }
}
