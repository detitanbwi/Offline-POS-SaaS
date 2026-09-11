<?php

namespace App\Repositories;

use App\Enums\TenantStatus;
use App\Models\Tenant;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Collection;

class TenantRepository
{
    public function __construct(
        protected Tenant $model,
    ) {}

    public function findById(string $id): ?Tenant
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): Tenant
    {
        return $this->model->findOrFail($id);
    }

    public function findByEmail(string $email): ?Tenant
    {
        return $this->model->where('email', $email)->first();
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->query();

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('owner_name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('store_name', 'like', "%{$search}%");
            });
        }

        if (! empty($filters['status'])) {
            if ($filters['status'] === 'trashed') {
                $query->onlyTrashed();
            } else {
                $query->where('status', $filters['status']);
            }
        }

        return $query->orderBy('created_at', 'desc')->paginate($perPage);
    }

    public function create(array $data): Tenant
    {
        return $this->model->create($data);
    }

    public function update(Tenant $tenant, array $data): bool
    {
        return $tenant->update($data);
    }

    public function delete(Tenant $tenant): bool
    {
        return $tenant->delete();
    }

    public function restore(string $id): Tenant
    {
        $tenant = $this->model->onlyTrashed()->findOrFail($id);
        $tenant->restore();

        return $tenant;
    }

    public function getActive(): Collection
    {
        return $this->model->where('status', TenantStatus::ACTIVE)->get();
    }

    public function count(): int
    {
        return $this->model->count();
    }

    public function countByStatus(TenantStatus $status): int
    {
        return $this->model->where('status', $status)->count();
    }
}
