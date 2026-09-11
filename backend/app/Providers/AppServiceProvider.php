<?php

namespace App\Providers;

use App\Models\Permission;
use Illuminate\Pagination\Paginator;
use Illuminate\Support\Facades\Gate;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Paginator::defaultView('vendor.pagination.default');
        Paginator::defaultSimpleView('vendor.pagination.simple-default');

        // Super Admin bypasses all gate checks
        Gate::before(function ($user, $ability) {
            if (method_exists($user, 'isSuperAdmin') && $user->isSuperAdmin()) {
                return true;
            }

            return null;
        });

        // Dynamic Gate definition for registered permissions
        Gate::guessPolicyNamesUsing(function (string $modelClass) {
            return null;
        });

        if (! $this->app->runningInConsole() || $this->app->runningUnitTests()) {
            try {
                if (Schema::hasTable('permissions')) {
                    $permissions = Permission::all();
                    foreach ($permissions as $permission) {
                        Gate::define($permission->slug, function ($user) use ($permission) {
                            return $user->hasPermission($permission->slug);
                        });
                    }
                }
            } catch (\Throwable $e) {
                // Ignore during early migrations
            }
        }
    }
}
