<?php

namespace App\Http\Controllers;

use App\Models\Role;
use App\Models\User;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class AdminUserController extends Controller
{
    public function __construct(
        protected AuditService $auditService
    ) {}

    public function index(Request $request)
    {
        $query = User::with('role')->where('is_admin', true);

        if ($request->filled('search')) {
            $search = trim($request->search);
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('email', 'like', "%{$search}%");
            });
        }

        if ($request->filled('role_id')) {
            $query->where('role_id', $request->role_id);
        }

        $users = $query->latest()->paginate(15)->withQueryString();
        $roles = Role::all();

        return view('admin.users.index', compact('users', 'roles'));
    }

    public function create()
    {
        $roles = Role::all();
        return view('admin.users.create', compact('roles'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'string', Password::defaults(), 'confirmed'],
            'role_id' => ['required', 'exists:roles,id'],
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => Hash::make($request->password),
            'role_id' => $request->role_id,
            'is_admin' => true,
        ]);

        $this->auditService->log(
            action: 'user.created',
            details: "Membuat akun admin baru: {$user->name} ({$user->email}) dengan Role: {$user->role?->name}",
            metadata: ['created_user_id' => $user->id, 'role_id' => $user->role_id]
        );

        return redirect()->route('admin.users.index')
            ->with('success', "Pengguna {$user->name} berhasil ditambahkan!");
    }

    public function edit(User $user)
    {
        $roles = Role::all();
        return view('admin.users.edit', compact('user', 'roles'));
    }

    public function update(Request $request, User $user)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', Rule::unique('users')->ignore($user->id)],
            'password' => ['nullable', 'string', Password::defaults(), 'confirmed'],
            'role_id' => ['required', 'exists:roles,id'],
        ]);

        $data = [
            'name' => $request->name,
            'email' => $request->email,
            'role_id' => $request->role_id,
        ];

        if ($request->filled('password')) {
            $data['password'] = Hash::make($request->password);
        }

        $oldRole = $user->role?->name;
        $user->update($data);
        $user->load('role');

        $this->auditService->log(
            action: 'user.updated',
            details: "Memperbarui akun admin: {$user->name} ({$user->email}), Role lama: {$oldRole} -> Role baru: {$user->role?->name}",
            metadata: ['target_user_id' => $user->id, 'role_id' => $user->role_id]
        );

        return redirect()->route('admin.users.index')
            ->with('success', "Data pengguna {$user->name} berhasil diperbarui!");
    }

    public function destroy(User $user)
    {
        // Prevent deleting own account
        if (auth()->id() === $user->id) {
            return redirect()->back()->with('error', 'Anda tidak dapat menghapus akun Anda sendiri.');
        }

        // Prevent deleting the last Super Admin
        $superAdminRole = Role::where('slug', 'super_admin')->first();
        if ($user->role_id === $superAdminRole?->id) {
            $superAdminCount = User::where('role_id', $superAdminRole->id)->count();
            if ($superAdminCount <= 1) {
                return redirect()->back()->with('error', 'Tidak dapat menghapus Super Admin terakhir dalam sistem.');
            }
        }

        $userName = $user->name;
        $userEmail = $user->email;
        $user->delete();

        $this->auditService->log(
            action: 'user.deleted',
            details: "Menghapus akun admin: {$userName} ({$userEmail})",
            metadata: ['deleted_user_email' => $userEmail]
        );

        return redirect()->route('admin.users.index')
            ->with('success', "Pengguna {$userName} berhasil dihapus!");
    }
}
