<?php

namespace App\Http\Controllers;

use App\Models\Permission;
use App\Models\Role;
use App\Services\AuditService;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class AdminRoleController extends Controller
{
    public function __construct(
        protected AuditService $auditService
    ) {}

    public function index()
    {
        $roles = Role::withCount(['users', 'permissions'])->with('permissions')->get();
        $permissions = Permission::all()->groupBy('module');

        return view('admin.roles.index', compact('roles', 'permissions'));
    }

    public function create()
    {
        $permissionsByModule = Permission::all()->groupBy('module');
        return view('admin.roles.create', compact('permissionsByModule'));
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:roles,name'],
            'description' => ['nullable', 'string', 'max:500'],
            'permissions' => ['required', 'array', 'min:1'],
            'permissions.*' => ['exists:permissions,id'],
        ]);

        $slug = Str::slug($request->name, '_');
        $role = Role::create([
            'name' => $request->name,
            'slug' => $slug,
            'description' => $request->description ?? 'Role kustom dengan hak akses spesifik',
        ]);

        $role->permissions()->sync($request->permissions);

        $this->auditService->log(
            action: 'role.created',
            details: "Membuat Role RBAC baru: {$role->name} dengan " . count($request->permissions) . " hak akses granular",
            metadata: ['role_id' => $role->id, 'permission_count' => count($request->permissions)]
        );

        return redirect()->route('admin.roles.index')
            ->with('success', "Role '{$role->name}' dengan hak akses granular berhasil dibuat!");
    }

    public function edit(Role $role)
    {
        $role->load('permissions');
        $permissionsByModule = Permission::all()->groupBy('module');
        $rolePermissionIds = $role->permissions->pluck('id')->toArray();

        return view('admin.roles.edit', compact('role', 'permissionsByModule', 'rolePermissionIds'));
    }

    public function update(Request $request, Role $role)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255', Rule::unique('roles', 'name')->ignore($role->id)],
            'description' => ['nullable', 'string', 'max:500'],
            'permissions' => ['required', 'array', 'min:1'],
            'permissions.*' => ['exists:permissions,id'],
        ]);

        $data = ['name' => $request->name, 'description' => $request->description];
        if (!in_array($role->slug, ['super_admin', 'operator'])) {
            $data['slug'] = Str::slug($request->name, '_');
        }

        $role->update($data);

        // If Super Admin, ensure all permissions always stay attached
        if ($role->slug === 'super_admin') {
            $allPermIds = Permission::pluck('id')->toArray();
            $role->permissions()->sync($allPermIds);
        } else {
            $role->permissions()->sync($request->permissions);
        }

        $this->auditService->log(
            action: 'role.updated',
            details: "Memperbarui wewenang hak akses Role: {$role->name} (" . count($request->permissions) . " hak akses aktif)",
            metadata: ['role_id' => $role->id, 'permission_count' => count($request->permissions)]
        );

        return redirect()->route('admin.roles.index')
            ->with('success', "Hak akses granular untuk role '{$role->name}' berhasil diperbarui!");
    }

    public function destroy(Role $role)
    {
        if (in_array($role->slug, ['super_admin', 'operator'])) {
            return redirect()->back()->with('error', "Role bawaan sistem ({$role->name}) tidak dapat dihapus.");
        }

        if ($role->users()->count() > 0) {
            return redirect()->back()->with('error', "Tidak dapat menghapus role '{$role->name}' karena masih digunakan oleh {$role->users()->count()} pengguna admin.");
        }

        $roleName = $role->name;
        $role->permissions()->detach();
        $role->delete();

        $this->auditService->log(
            action: 'role.deleted',
            details: "Menghapus role kustom: {$roleName}",
            metadata: ['deleted_role' => $roleName]
        );

        return redirect()->route('admin.roles.index')
            ->with('success', "Role '{$roleName}' berhasil dihapus.");
    }
}
