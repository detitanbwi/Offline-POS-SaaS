<?php

namespace App\Repositories;

use App\Enums\SubscriptionStatus;
use App\Models\Subscription;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Collection;

class SubscriptionRepository
{
    public function __construct(
        protected Subscription $model,
    ) {}

    public function findById(string $id): ?Subscription
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): Subscription
    {
        return $this->model->findOrFail($id);
    }

    public function findByIdWithRelations(string $id): Subscription
    {
        return $this->model
            ->with(['tenant', 'package', 'invoiceItem.invoice', 'licenseTokens.device'])
            ->findOrFail($id);
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->with(['tenant', 'package']);

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('package_name', 'like', "%{$search}%")
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

    public function create(array $data): Subscription
    {
        return $this->model->create($data);
    }

    public function update(Subscription $subscription, array $data): bool
    {
        return $subscription->update($data);
    }

    /**
     * Dapatkan subscription yang sudah melewati expiry_date tapi masih ACTIVE.
     */
    public function getExpiredButActive(): Collection
    {
        return $this->model
            ->where('status', SubscriptionStatus::ACTIVE)
            ->where('expiry_date', '<', now()->toDateString())
            ->get();
    }

    public function count(): int
    {
        return $this->model->count();
    }

    public function countByStatus(SubscriptionStatus $status): int
    {
        return $this->model->where('status', $status)->count();
    }
}
