<?php

namespace App\Http\Controllers;

use App\Models\LicenseCheckLog;
use App\Models\LicenseToken;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LicenseLogController extends Controller
{
    /**
     * Menerima sinkronisasi batch log aktivitas lisensi dari perangkat (Frontend)
     */
    public function sync(Request $request)
    {
        $request->validate([
            'logs' => 'required|array',
            'logs.*.token_key' => 'required|string',
            'logs.*.status' => 'required|string',
            'logs.*.trigger_type' => 'required|string',
            'logs.*.remaining_time_seconds' => 'required|integer',
            'logs.*.created_at' => 'required|date',
        ]);

        $user = $request->user();
        $tenantId = $user->tenant_id;

        DB::beginTransaction();
        try {
            foreach ($request->logs as $logData) {
                $token = LicenseToken::where('token_key', $logData['token_key'])
                    ->where('tenant_id', $tenantId)
                    ->first();

                LicenseCheckLog::create([
                    'tenant_id' => $tenantId,
                    'license_token_id' => $token ? $token->id : null,
                    'status' => $logData['status'],
                    'trigger_type' => $logData['trigger_type'],
                    'remaining_time_seconds' => $logData['remaining_time_seconds'],
                    'created_at' => $logData['created_at'],
                ]);
            }
            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'License logs synced successfully.',
            ]);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to sync logs.',
            ], 500);
        }
    }
}
