<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Order;
use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class ReportController extends Controller
{
    public function buyerReport(Request $request): JsonResponse
    {
        $user = $request->user();
        $startDate = $request->query('start_date');
        $endDate = $request->query('end_date');

        $query = $user->orders();

        if ($startDate) {
            $query->where('created_at', '>=', $startDate);
        }

        if ($endDate) {
            $query->where('created_at', '<=', $endDate);
        }

        $orders = $query->with(['store', 'orderItems'])->get();

        $summary = [
            'total_orders' => $orders->count(),
            'completed_orders' => $orders->where('status', 'Selesai')->count(),
            'pending_orders' => $orders->where('status', 'Menunggu Pembayaran')->count(),
            'total_spent' => $orders->sum('total_price'),
        ];

        return response()->json([
            'message' => 'Laporan transaksi pembeli',
            'summary' => $summary,
            'data' => $orders,
        ]);
    }

    public function storeReport(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat melihat laporan toko',
            ], 403);
        }

        $store = $user->store;
        if (!$store) {
            return response()->json([
                'message' => 'Toko tidak ditemukan',
            ], 404);
        }

        $startDate = $request->query('start_date');
        $endDate = $request->query('end_date');

        $query = $store->orders();

        if ($startDate) {
            $query->where('created_at', '>=', $startDate);
        }

        if ($endDate) {
            $query->where('created_at', '<=', $endDate);
        }

        $orders = $query->get();

        $summary = [
            'total_incoming_orders' => $orders->count(),
            'completed_orders' => $orders->where('status', 'Selesai')->count(),
            'cancelled_orders' => $orders->where('status', 'Dibatalkan')->count(),
            'processing_orders' => $orders->whereIn('status', ['Dikonfirmasi', 'Diproses', 'Dikirim'])->count(),
            'total_revenue' => $orders->where('status', 'Selesai')->sum('total_price'),
            'estimated_revenue' => $orders->whereIn('status', ['Dikonfirmasi', 'Diproses', 'Dikirim', 'Selesai'])->sum('total_price'),
        ];

        // FIX: null-safe completed_at, fallback ke created_at supaya endpoint
        // tidak 500 kalau ada order Selesai dengan completed_at kosong.
        $monthlyRevenue = $orders
            ->where('status', 'Selesai')
            ->groupBy(function ($order) {
                $date = $order->completed_at ?? $order->created_at;
                return $date->format('Y-m');
            })
            ->map(function ($group) {
                $firstDate = $group->first()->completed_at ?? $group->first()->created_at;
                return [
                    'month' => $firstDate->format('Y-m'),
                    'revenue' => $group->sum('total_price'),
                    'orders' => $group->count(),
                ];
            });

        $completedOrderIds = $orders->where('status', 'Selesai')->pluck('id');
        $totalExpense = (float) \App\Models\WalletTransaction::whereNull('store_id')
            ->where('category', 'tax')
            ->whereIn('order_id', $completedOrderIds)
            ->sum('amount');
        $totalRevenue = (float) $summary['total_revenue'];
        $netProfit = $totalRevenue - $totalExpense;

        $transactions = $orders->where('status', 'Selesai')->map(function ($order) {
            $date = $order->completed_at ?? $order->created_at;
            return [
                'id' => $order->id,
                'type' => 'income',
                'description' => "Penjualan - {$order->order_number}",
                'amount' => (float) $order->total_price,
                'date' => optional($date)->toIso8601String(),
                'category' => 'Penjualan',
                'order_id' => (string) $order->id,
            ];
        })->values();

        return response()->json([
            'message' => 'Laporan toko',
            'store_name' => $store->store_name,
            'summary' => $summary,
            'monthly_breakdown' => $monthlyRevenue->values(),
            'recent_orders' => $orders->take(10)->load('buyer', 'orderItems'),
            'data' => [
                'total_revenue' => $totalRevenue,
                'total_expense' => $totalExpense,
                'net_profit' => $netProfit,
                'total_orders' => $orders->count(),
                'completed_orders' => $summary['completed_orders'],
                'transactions' => $transactions,
                'period' => 'Custom',
                'start_date' => $startDate ?? now()->subDays(30)->toIso8601String(),
                'end_date' => $endDate ?? now()->toIso8601String(),
            ],
        ]);
    }

    public function platformReport(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isAdmin()) {
            return response()->json([
                'message' => 'Hanya admin yang dapat melihat laporan platform',
            ], 403);
        }

        $startDate = $request->query('start_date');
        $endDate = $request->query('end_date');

        $totalUsers = User::count();
        $buyers = User::where('role', 'Pembeli')->count();
        $sellers = User::where('role', 'Penjual')->count();

        $totalStores = Store::count();
        $activeStores = Store::where('is_active', true)->count();

        $orderQuery = Order::query();

        if ($startDate) {
            $orderQuery->where('created_at', '>=', $startDate);
        }

        if ($endDate) {
            $orderQuery->where('created_at', '<=', $endDate);
        }

        $orders = $orderQuery->get();
        $completedOrders = $orders->where('status', 'Selesai');
        $activeSales = $orders->whereNotIn('status', ['Menunggu Pembayaran', 'Dibatalkan']);

        $summary = [
            'total_users' => $totalUsers,
            'total_buyers' => $buyers,
            'total_sellers' => $sellers,
            'total_stores' => $totalStores,
            'active_stores' => $activeStores,
            'total_transactions' => $orders->count(),
            'completed_transactions' => $completedOrders->count(),
            'total_value' => $completedOrders->sum('total_price'),
            'current_balance' => $activeSales->sum('total_price'),
        ];

        $dailyTransactions = $orders
            ->groupBy(function ($order) {
                return $order->created_at->format('Y-m-d');
            })
            ->map(function ($group) {
                $completed = $group->where('status', 'Selesai');
                return [
                    'date' => $group->first()->created_at->format('Y-m-d'),
                    'transactions' => $group->count(),
                    'completed' => $completed->count(),
                    'value' => $completed->sum('total_price'),
                ];
            });

        $topStores = DB::table('stores')
            ->leftJoin('orders', 'stores.id', '=', 'orders.store_id')
            ->select('stores.id', 'stores.store_name', DB::raw('COUNT(orders.id) as order_count'), DB::raw('SUM(orders.total_price) as total_value'))
            ->where('orders.status', 'Selesai')
            ->groupBy('stores.id')
            ->orderByDesc('total_value')
            ->limit(10)
            ->get();

        return response()->json([
            'message' => 'Laporan platform BUMDes Jabar',
            'summary' => $summary,
            'daily_breakdown' => $dailyTransactions->values(),
            'top_stores' => $topStores,
        ]);
    }
}