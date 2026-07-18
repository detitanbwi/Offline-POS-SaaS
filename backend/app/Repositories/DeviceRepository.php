<?php

namespace App\Repositories;

use App\Enums\DeviceStatus;
use App\Models\Device;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class DeviceRepository
{
    public function __construct(
        protected Device $model,
    ) {}

    public function findById(string $id): ?Device
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): Device
    {
        return $this->model->findOrFail($id);
    }

    public function findByTokenAndFingerprint(string $licenseTokenId, string $fingerprintHash): ?Device
    {
        return $this->model
            ->where('license_token_id', $licenseTokenId)
            ->where('fingerprint_hash', $fingerprintHash)
            ->first();
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->with(['licenseToken', 'tenant']);

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('brand', 'like', "%{$search}%")
                    ->orWhere('model', 'like', "%{$search}%")
                    ->orWhere('manufacturer', 'like', "%{$search}%")
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

    public function create(array $data): Device
    {
        return $this->model->create($data);
    }

    public function update(Device $device, array $data): bool
    {
        return $device->update($data);
    }

    public function count(): int
    {
        return $this->model->count();
    }

    public function countByStatus(DeviceStatus $status): int
    {
        return $this->model->where('status', $status)->count();
    }
}
