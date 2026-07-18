<?php

namespace App\Http\Controllers;

use App\Http\Requests\CreatePackageRequest;
use App\Models\Package;
use App\Repositories\PackageRepository;

class AdminPackageController extends Controller
{
    public function __construct(
        protected PackageRepository $packageRepository,
    ) {}

    public function index()
    {
        $packages = $this->packageRepository->paginate(request()->only(['search', 'is_active']));

        return view('admin.packages.index', compact('packages'));
    }

    public function create()
    {
        return view('admin.packages.create');
    }

    public function store(CreatePackageRequest $request)
    {
        $data = $request->validated();
        if (empty($data['slug'])) {
            $data['slug'] = Package::generateSlug($data['name']);
        }

        $this->packageRepository->create($data);

        return redirect()->route('admin.packages.index')
            ->with('success', 'Paket berhasil dibuat!');
    }

    public function edit(Package $package)
    {
        return view('admin.packages.edit', compact('package'));
    }

    public function update(CreatePackageRequest $request, Package $package)
    {
        $this->packageRepository->update($package, $request->validated());

        return redirect()->route('admin.packages.index')
            ->with('success', 'Paket berhasil diperbarui!');
    }

    public function destroy(Package $package)
    {
        $this->packageRepository->delete($package);

        return redirect()->route('admin.packages.index')
            ->with('success', 'Paket berhasil dihapus!');
    }
}
