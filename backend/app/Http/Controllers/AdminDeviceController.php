<?php

namespace App\Http\Controllers;

use App\Enums\DeviceStatus;
use App\Repositories\DeviceRepository;

class AdminDeviceController extends Controller
{
    public function __construct(
        protected DeviceRepository $deviceRepository,
    ) {}

    public function index()
    {
        $devices = $this->deviceRepository->paginate(request()->only(['search', 'status']));
        $statuses = DeviceStatus::cases();

        return view('admin.devices.index', compact('devices', 'statuses'));
    }

    public function show(string $id)
    {
        $device = $this->deviceRepository->findByIdOrFail($id);
        $device->load(['licenseToken.subscription', 'tenant']);

        return view('admin.devices.show', compact('device'));
    }
}
