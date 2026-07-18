<?php

namespace App\Http\Controllers;

use App\Enums\TokenStatus;
use App\Repositories\LicenseTokenRepository;
use App\Services\LicenseService;

class AdminLicenseTokenController extends Controller
{
    public function __construct(
        protected LicenseTokenRepository $tokenRepository,
        protected LicenseService $licenseService,
    ) {}

    public function index()
    {
        $tokens = $this->tokenRepository->paginate(request()->only(['search', 'status']));
        $statuses = TokenStatus::cases();

        return view('admin.tokens.index', compact('tokens', 'statuses'));
    }

    public function show(string $id)
    {
        $token = $this->tokenRepository->findByIdWithRelations($id);

        return view('admin.tokens.show', compact('token'));
    }

    public function resetDevice(string $id)
    {
        $this->licenseService->resetDevice($id);

        return redirect()->back()
            ->with('success', 'Perangkat berhasil di-reset dari token ini!');
    }

    public function revoke(string $id)
    {
        $this->licenseService->revokeToken($id);

        return redirect()->back()
            ->with('success', 'Token berhasil dicabut!');
    }
}
