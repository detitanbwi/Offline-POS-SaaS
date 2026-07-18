<?php

namespace App\Repositories;

use App\Models\Package;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Collection;

class PackageRepository
{
    public function __construct(
        protected Package $model,
    ) {}

    public function findById(string $id): ?Package
    {
        return $this->model->find($id);
    }

    public function findByIdOrFail(string $id): Package
    {
        return $this->model->findOrFail($id);
    }

    public function findBySlug(string $slug): ?Package
    {
        return $this->model->where('slug', $slug)->first();
    }

    public function paginate(array $filters = [], int $perPage = 10): LengthAwarePaginator
    {
        $query = $this->model->query();

        if (! empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('description', 'like', "%{$search}%");
            });
        }

        if (isset($filters['is_active'])) {
            $query->where('is_active', $filters['is_active']);
        }

        return $query->ordered()->paginate($perPage);
    }

    public function getActive(): Collection
    {
        return $this->model->active()->ordered()->get();
    }

    public function all(): Collection
    {
        return $this->model->ordered()->get();
    }

    public function create(array $data): Package
    {
        if (empty($data['slug'])) {
            $data['slug'] = Package::generateSlug($data['name']);
        }

        return $this->model->create($data);
    }

    public function update(Package $package, array $data): bool
    {
        return $package->update($data);
    }

    public function delete(Package $package): bool
    {
        return $package->delete();
    }
}
