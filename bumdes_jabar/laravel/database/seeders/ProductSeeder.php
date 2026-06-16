<?php

namespace Database\Seeders;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Seeder;

class ProductSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $store = \App\Models\Store::where('store_name', 'BUMDes Garut')->first();

        if (! $store) {
            $store = \App\Models\Store::first();
        }

        if (! $store) {
            return;
        }

        $stores = Store::all();
        if ($stores->isEmpty()) {
            return;
        }

        $products = [
            ['store_name' => 'BUMDes Garut', 'category_id' => 3, 'name' => 'Kerupuk Kulit dari BUMDes Garut', 'type' => 'produk', 'price' => 25000, 'stock' => 15, 'description' => 'Kerupuk kulit khas Garut dengan cita rasa gurih, renyah, dan siap dipasarkan.', 'photo_url' => 'https://picsum.photos/seed/kerupuk/400/300'],
            ['store_name' => 'BUMDes Ciwidey', 'category_id' => 1, 'name' => 'Sayuran Segar dari BUMDes Ciwidey', 'type' => 'produk', 'price' => 18000, 'stock' => 25, 'description' => 'Sayuran segar hasil panen lokal dari BUMDes Ciwidey untuk kebutuhan harian.', 'photo_url' => 'https://picsum.photos/seed/sayur/400/300'],
            ['store_name' => 'BUMDes Pangalengan', 'category_id' => 3, 'name' => 'Sus Lezat dari BUMDes Pangalengan', 'type' => 'produk', 'price' => 30000, 'stock' => 12, 'description' => 'Sus lembut dan nikmat khas Pangalengan, cocok untuk camilan keluarga.', 'photo_url' => 'https://picsum.photos/seed/sus/400/300'],
        ];

        foreach ($products as $productData) {
            $store = $stores->firstWhere('store_name', $productData['store_name']);
            if (! $store) {
                continue;
            }

            Product::updateOrCreate(
                ['name' => $productData['name'], 'store_id' => $store->id],
                [
                    'store_id' => $store->id,
                    'category_id' => $productData['category_id'],
                    'name' => $productData['name'],
                    'type' => $productData['type'],
                    'price' => $productData['price'],
                    'stock' => $productData['stock'],
                    'description' => $productData['description'],
                    'photo_url' => $productData['photo_url'],
                    'is_active' => true,
                ]
            );
        }

        $buyers = User::where('role', 'Pembeli')->get();
        $demoProducts = Product::all();

        foreach ($buyers as $index => $buyer) {
            $demoProduct = $demoProducts->get($index) ?: $demoProducts->first();
            if (! $demoProduct) {
                continue;
            }

            $order = Order::firstOrCreate(
                ['order_number' => 'ORD-DEMO-' . ($index + 1)],
                [
                    'buyer_id' => $buyer->id,
                    'store_id' => $demoProduct->store_id,
                    'status' => 'Menunggu Konfirmasi',
                    'recipient_name' => $buyer->name,
                    'recipient_phone' => $buyer->phone ?? '081000000000',
                    'delivery_address' => $buyer->address ?? 'Bandung',
                    'notes' => 'Demo order untuk sinkronisasi data buyer, penjual, dan admin.',
                    'total_price' => $demoProduct->price * 2,
                ]
            );

            OrderItem::firstOrCreate(
                ['order_id' => $order->id, 'product_id' => $demoProduct->id],
                [
                    'quantity' => 2,
                    'unit_price' => $demoProduct->price,
                    'subtotal' => $demoProduct->price * 2,
                ]
            );

            Payment::firstOrCreate(
                ['order_id' => $order->id],
                ['status' => 'Pending']
            );
        }
    }
}
