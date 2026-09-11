<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Kasir Pro Admin')</title>
    <link rel="icon" type="image/png" href="{{ asset('icon.png') }}">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #144683;
            --primary-active: #103969;
            --primary-container: #DCE9F8;
            --secondary: #FE7E00;
            --secondary-active: #E56F00;
            --secondary-container: #FFF1E3;
            --success: #16A34A;
            --warning: #F59E0B;
            --error: #DC2626;
            --background: #FFFFFF;
            --surface: #F8FAFC;
            --card: #FFFFFF;
            --divider: #E5E7EB;
            --text-primary: #111827;
            --text-secondary: #6B7280;
            --disabled: #9CA3AF;
        }

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--surface);
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }

        .wrapper { display: flex; min-height: 100vh; width: 100%; }

        .sidebar {
            width: 260px;
            background-color: var(--primary);
            color: white;
            display: flex;
            flex-direction: column;
            flex-shrink: 0;
            overflow-y: auto;
        }

        .sidebar-brand {
            height: 70px;
            display: flex;
            align-items: center;
            gap: 12px;
            padding: 0 20px;
            background-color: #FFFFFF;
            border-bottom: 1px solid var(--divider);
            border-right: 1px solid var(--divider);
            color: var(--primary);
            text-decoration: none;
            flex-shrink: 0;
            box-sizing: border-box;
            width: 100%;
        }
        .sidebar-brand img {
            width: 32px;
            height: 32px;
            object-fit: contain;
        }
        .sidebar-brand span {
            color: var(--primary);
            font-size: 18px;
            font-weight: 700;
            letter-spacing: -0.2px;
        }

        .sidebar-nav {
            padding: 20px 16px;
            display: flex;
            flex-direction: column;
            flex-grow: 1;
        }

        .sidebar-menu { list-style: none; display: flex; flex-direction: column; gap: 4px; flex-grow: 1; }

        .sidebar-menu-item a {
            display: flex; align-items: center; gap: 12px;
            padding: 10px 16px; color: rgba(255,255,255,0.85);
            text-decoration: none; font-size: 13px; font-weight: 500;
            border-radius: 12px; transition: all 0.2s ease;
        }
        .sidebar-menu-item a:hover { background-color: rgba(255,255,255,0.1); color: white; }
        .sidebar-menu-item.active a { background-color: var(--secondary); color: white; font-weight: 600; }

        .sidebar-section {
            font-size: 11px; font-weight: 600; color: rgba(255,255,255,0.5);
            text-transform: uppercase; letter-spacing: 0.5px;
            padding: 16px 16px 8px; margin-top: 4px;
        }

        .sidebar-footer { margin-top: auto; border-top: 1px solid rgba(255,255,255,0.1); padding-top: 16px; }

        .btn-logout {
            width: 100%; background: none; border: none;
            color: rgba(255,255,255,0.8); display: flex; align-items: center;
            gap: 12px; padding: 12px 16px; font-size: 14px; font-weight: 500;
            cursor: pointer; border-radius: 12px; text-align: left;
            transition: all 0.2s ease;
        }
        .btn-logout:hover { background-color: rgba(239,68,68,0.2); color: #FCA5A5; }

        .main-content { flex-grow: 1; display: flex; flex-direction: column; min-width: 0; }

        .main-header {
            height: 70px; background-color: var(--card);
            border-bottom: 1px solid var(--divider);
            display: flex; align-items: center; justify-content: space-between;
            padding: 0 32px; flex-shrink: 0;
        }
        .header-title { font-size: 18px; font-weight: 600; }
        .user-profile { display: flex; align-items: center; gap: 12px; }
        .user-avatar {
            width: 38px; height: 38px; border-radius: 50%;
            background-color: var(--primary-container); color: var(--primary);
            display: flex; align-items: center; justify-content: center;
            font-weight: 600; font-size: 14px;
        }

        .content-body { padding: 32px; flex-grow: 1; overflow-y: auto; }

        .card {
            background-color: var(--card); border-radius: 16px;
            border: 1px solid var(--divider); padding: 24px;
            margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.05);
        }
        .card-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .card-title { font-size: 16px; font-weight: 600; color: var(--text-primary); }

        .btn {
            display: inline-flex; align-items: center; gap: 8px;
            padding: 10px 20px; font-size: 14px; font-weight: 500;
            border-radius: 999px; cursor: pointer; border: none;
            transition: all 0.2s ease; text-decoration: none;
        }
        .btn-primary { background-color: var(--primary); color: white; }
        .btn-primary:hover { background-color: var(--primary-active); }
        .btn-secondary { background-color: var(--secondary); color: white; }
        .btn-secondary:hover { background-color: var(--secondary-active); }
        .btn-outline { background: none; border: 1.5px solid var(--primary); color: var(--primary); }
        .btn-outline:hover { background-color: var(--primary-container); }
        .btn-success { background-color: var(--success); color: white; }
        .btn-success:hover { filter: brightness(0.9); }
        .btn-danger { background-color: var(--error); color: white; }
        .btn-danger:hover { filter: brightness(0.9); }
        .btn-warning { background-color: var(--warning); color: white; }
        .btn-warning:hover { filter: brightness(0.9); }
        .btn-sm { padding: 6px 14px; font-size: 12px; }
        .btn-xs { padding: 4px 10px; font-size: 11px; }

        .alert { padding: 16px 20px; border-radius: 12px; margin-bottom: 24px; font-size: 14px; font-weight: 500; }
        .alert-success { background-color: #DEF7EC; color: #03543F; }
        .alert-danger { background-color: #FDE8E8; color: #9B1C1C; }

        .table-responsive { width: 100%; overflow-x: auto; }
        .table { width: 100%; border-collapse: collapse; text-align: left; }
        .table th {
            background-color: var(--surface); padding: 14px 16px;
            font-size: 13px; font-weight: 600; color: var(--text-secondary);
            border-bottom: 1px solid var(--divider);
        }
        .table td { padding: 14px 16px; font-size: 14px; border-bottom: 1px solid var(--divider); vertical-align: middle; }
        .table tr:last-child td { border-bottom: none; }
        .table tr:hover td { background-color: #F8FAFC; }

        .badge {
            display: inline-block; padding: 4px 10px; font-size: 11px;
            font-weight: 600; border-radius: 9999px; text-transform: uppercase;
        }
        .badge-success { background-color: #DEF7EC; color: #03543F; }
        .badge-warning { background-color: #FEF08A; color: #713F12; }
        .badge-danger { background-color: #FDE8E8; color: #9B1C1C; }
        .badge-info { background-color: #E0F2FE; color: #0369A1; }

        .form-group { margin-bottom: 20px; }
        .form-label { display: block; margin-bottom: 8px; font-size: 14px; font-weight: 500; color: var(--text-primary); }
        .form-control {
            width: 100%; padding: 12px 16px; border-radius: 12px;
            border: 1px solid var(--divider); background-color: var(--surface);
            font-family: inherit; font-size: 14px; color: var(--text-primary);
            transition: border-color 0.2s ease;
        }
        select, select.form-control {
            appearance: none;
            -webkit-appearance: none;
            -moz-appearance: none;
            background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 24 24' stroke='%236B7280' stroke-width='2'%3E%3Cpath stroke-linecap='round' stroke-linejoin='round' d='M19 9l-7 7-7-7'%3E%3C/path%3E%3C/svg%3E");
            background-repeat: no-repeat;
            background-position: right 14px center;
            background-size: 16px 16px;
            padding-right: 40px !important;
            cursor: pointer;
        }
        .form-control:focus { outline: none; border-color: var(--primary); box-shadow: 0 0 0 3px rgba(20,70,131,0.15); }
        .form-error { color: var(--error); font-size: 12px; margin-top: 4px; }

        .grid { display: grid; gap: 24px; }
        .grid-2 { grid-template-columns: repeat(2, 1fr); }
        .grid-3 { grid-template-columns: repeat(3, 1fr); }
        .grid-4 { grid-template-columns: repeat(4, 1fr); }
        .grid-5 { grid-template-columns: repeat(5, 1fr); }

        .stat-card { text-align: center; padding: 20px; }
        .stat-value { font-size: 28px; font-weight: 700; color: var(--primary); margin-bottom: 4px; }
        .stat-label { font-size: 13px; color: var(--text-secondary); font-weight: 500; }

        .search-bar {
            display: flex; gap: 12px; margin-bottom: 24px; align-items: center; flex-wrap: wrap;
        }
        .search-bar .form-control { max-width: 300px; }
        .search-bar select.form-control { max-width: 200px; }

        /* Pagination Styling */
        .pagination-wrapper, .pagination {
            display: block;
            width: 100%;
            margin-top: 24px;
        }
        .pagination-container {
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 16px;
            width: 100%;
            padding-top: 16px;
            border-top: 1px solid var(--divider);
        }
        .pagination-info {
            font-size: 13px;
            color: var(--text-secondary);
        }
        .pagination-info span {
            font-weight: 600;
            color: var(--text-primary);
        }
        .pagination-list, ul.pagination {
            display: flex;
            gap: 6px;
            align-items: center;
            list-style: none;
            margin: 0;
            padding: 0;
        }
        .page-item .page-link,
        .pagination-list li a,
        .pagination-list li span,
        .pagination li a,
        .pagination li span {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 36px;
            height: 36px;
            padding: 0 12px;
            border-radius: 8px;
            font-size: 13px;
            font-weight: 500;
            text-decoration: none;
            color: var(--text-primary);
            background-color: var(--card);
            border: 1px solid var(--divider);
            transition: all 0.2s ease;
        }
        .page-item .page-link:hover,
        .pagination-list li a:hover,
        .pagination li a:hover {
            background-color: var(--primary-container);
            color: var(--primary);
            border-color: var(--primary);
        }
        .page-item.active .page-link,
        .pagination-list li.active span,
        .pagination li.active span {
            background-color: var(--primary);
            color: #FFFFFF;
            border-color: var(--primary);
            font-weight: 600;
        }
        .page-item.disabled .page-link,
        .pagination-list li.disabled span,
        .pagination li.disabled span {
            opacity: 0.4;
            cursor: not-allowed;
            background-color: var(--surface);
            border-color: var(--divider);
            color: var(--disabled);
        }
        /* Fallback for standard/tailwind SVGs */
        .pagination svg, nav svg {
            width: 16px !important;
            height: 16px !important;
            max-width: 16px !important;
            max-height: 16px !important;
            display: inline-block;
            vertical-align: middle;
        }

        .text-muted { color: var(--text-secondary); }
        .text-sm { font-size: 13px; }
        .text-xs { font-size: 11px; }
        .font-mono { font-family: 'SF Mono', 'Fira Code', monospace; }
        .mt-2 { margin-top: 8px; }
        .mt-4 { margin-top: 16px; }
        .mb-4 { margin-bottom: 16px; }
        .flex { display: flex; }
        .flex-wrap { flex-wrap: wrap; }
        .gap-2 { gap: 8px; }
        .gap-3 { gap: 12px; }
        .items-center { align-items: center; }

        .detail-grid { display: grid; grid-template-columns: 160px 1fr; gap: 8px 16px; }
        .detail-label { font-size: 13px; font-weight: 500; color: var(--text-secondary); }
        .detail-value { font-size: 14px; color: var(--text-primary); }

        .token-display {
            font-family: 'SF Mono', 'Fira Code', monospace;
            font-size: 14px; font-weight: 600; letter-spacing: 1px;
            padding: 8px 14px; background-color: var(--surface);
            border-radius: 8px; border: 1px solid var(--divider);
            display: inline-block;
        }

        @media(max-width: 1200px) { .grid-5 { grid-template-columns: repeat(3, 1fr); } }
        @media(max-width: 992px) { .grid-3, .grid-4, .grid-5 { grid-template-columns: repeat(2, 1fr); } }
        @media(max-width: 768px) {
            .wrapper { flex-direction: column; }
            .sidebar { width: 100%; height: auto; }
            .grid-2, .grid-3, .grid-4, .grid-5 { grid-template-columns: 1fr; }
            .detail-grid { grid-template-columns: 1fr; }
            .search-bar .form-control { max-width: 100%; }
            .content-body { padding: 16px; }
            .pagination-container { justify-content: center; text-align: center; }
        }
    </style>
    @yield('styles')
</head>
<body>
    <div class="wrapper">
        <aside class="sidebar">
            <a href="{{ route('admin.dashboard') }}" class="sidebar-brand">
                <img src="{{ asset('icon.png') }}" alt="Kasir Pro">
                <span>App Kasir Pro</span>
            </a>

            <div class="sidebar-nav">
                <ul class="sidebar-menu">
                    @can('dashboard.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.dashboard') ? 'active' : '' }}">
                        <a href="{{ route('admin.dashboard') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2H6a2 2 0 01-2-2v-4zM14 16a2 2 0 012-2h2a2 2 0 012 2v4a2 2 0 01-2 2h-2a2 2 0 01-2-2v-4z"/></svg>
                            <span>Dashboard</span>
                        </a>
                    </li>
                    @endcan

                    @if(auth()->user()->can('tenants.view') || auth()->user()->can('packages.view'))
                    <div class="sidebar-section">Manajemen</div>

                    @can('tenants.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.tenants.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.tenants.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg>
                            <span>Tenant</span>
                        </a>
                    </li>
                    @endcan

                    @can('packages.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.packages.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.packages.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/></svg>
                            <span>Paket</span>
                        </a>
                    </li>
                    @endcan
                    @endif

                    @if(auth()->user()->can('invoices.view') || auth()->user()->can('invoices.report') || auth()->user()->can('subscriptions.view'))
                    <div class="sidebar-section">Transaksi</div>

                    @can('invoices.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.invoices.index') || Request::routeIs('admin.invoices.show') || Request::routeIs('admin.invoices.create') ? 'active' : '' }}">
                        <a href="{{ route('admin.invoices.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
                            <span>Daftar Invoice</span>
                        </a>
                    </li>
                    @endcan

                    @can('invoices.report')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.invoices.report*') ? 'active' : '' }}">
                        <a href="{{ route('admin.invoices.report') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
                            <span>Laporan Invoice</span>
                        </a>
                    </li>
                    @endcan

                    @can('subscriptions.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.subscriptions.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.subscriptions.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                            <span>Langganan</span>
                        </a>
                    </li>
                    @endcan
                    @endif

                    @if(auth()->user()->can('tokens.view') || auth()->user()->can('devices.view'))
                    <div class="sidebar-section">Lisensi & Perangkat</div>

                    <li class="sidebar-menu-item {{ Request::routeIs('admin.tokens.*') || Request::routeIs('admin.devices.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.tokens.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z"/></svg>
                            <span>Lisensi & Perangkat</span>
                        </a>
                    </li>
                    @endif

                    @if(auth()->user()->can('users.view') || auth()->user()->can('audit_logs.view') || auth()->user()->can('profile.edit'))
                    <div class="sidebar-section">Sistem & Pengguna</div>

                    @can('users.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.users.*') || Request::routeIs('admin.roles.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.users.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/></svg>
                            <span>Pengguna & Hak Akses</span>
                        </a>
                    </li>
                    @endcan

                    @can('audit_logs.view')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.audit-logs.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.audit-logs.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
                            <span>Audit Log</span>
                        </a>
                    </li>
                    @endcan

                    <li class="sidebar-menu-item {{ Request::routeIs('admin.trash.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.trash.index') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                            <span>Tempat Sampah</span>
                            @php
                                $trashedBadgeCount = \App\Models\Tenant::onlyTrashed()->count() + \App\Models\Invoice::onlyTrashed()->count();
                            @endphp
                            @if ($trashedBadgeCount > 0)
                                <span class="badge badge-warning" style="margin-left: auto; font-size: 10px; padding: 2px 7px; border-radius: 99px; font-weight: 700;">{{ $trashedBadgeCount }}</span>
                            @endif
                        </a>
                    </li>

                    @can('profile.edit')
                    <li class="sidebar-menu-item {{ Request::routeIs('admin.profile.*') ? 'active' : '' }}">
                        <a href="{{ route('admin.profile.edit') }}">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
                            <span>Profil & Pengaturan</span>
                        </a>
                    </li>
                    @endcan
                    @endif
                </ul>

                <div class="sidebar-footer">
                    <form action="{{ route('admin.logout') }}" method="POST">
                        @csrf
                        <button type="submit" class="btn-logout">
                            <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/></svg>
                            <span>Logout</span>
                        </button>
                    </form>
                </div>
            </div>
        </aside>

        <main class="main-content">
            <header class="main-header">
                <div class="header-title">@yield('header_title', 'SaaS Dashboard')</div>
                <a href="{{ route('admin.profile.edit') }}" class="user-profile" style="text-decoration: none; color: inherit; display: flex; align-items: center; gap: 10px;" title="Klik untuk edit data login">
                    <div class="user-avatar">
                        {{ strtoupper(substr(Auth::user()->name ?? 'A', 0, 1)) }}
                    </div>
                    <div style="display: flex; flex-direction: column; line-height: 1.2;">
                        <span style="font-size: 13px; font-weight: 600;">{{ Auth::user()->name ?? 'Administrator' }}</span>
                        <span style="font-size: 11px; color: var(--secondary); font-weight: 600;">
                            {{ Auth::user()->role?->name ?? (Auth::user()->isSuperAdmin() ? 'Super Admin' : 'Operator') }}
                        </span>
                    </div>
                </a>
            </header>

            <div class="content-body">
                @if (session('success'))
                    <div class="alert alert-success">{{ session('success') }}</div>
                @endif
                @if (session('error'))
                    <div class="alert alert-danger">{{ session('error') }}</div>
                @endif
                @yield('content')
            </div>
        </main>
    </div>
    <script>
        function togglePasswordVisibility(fieldId = 'password', iconId = 'eye_icon') {
            const input = document.getElementById(fieldId);
            const icon = document.getElementById(iconId);
            if (!input) return;

            if (input.type === 'password') {
                input.type = 'text';
                if (icon) {
                    icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21" />';
                }
            } else {
                input.type = 'password';
                if (icon) {
                    icon.innerHTML = '<path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />';
                }
            }
        }
    </script>
    @yield('scripts')
    @stack('scripts')
</body>
</html>
