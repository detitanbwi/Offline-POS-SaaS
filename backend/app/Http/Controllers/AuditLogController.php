<?php

namespace App\Http\Controllers;

use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    public function index(Request $request)
    {
        $query = AuditLog::with(['tenant', 'license', 'user']);

        if ($request->filled('action')) {
            $query->where('action', $request->action);
        }

        if ($request->filled('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('action', 'like', "%$search%")
                  ->orWhere('details', 'like', "%$search%");
            });
        }

        $logs = $query->orderBy('created_at', 'desc')->paginate(20);

        return view('admin.audit-logs.index', compact('logs'));
    }
}
