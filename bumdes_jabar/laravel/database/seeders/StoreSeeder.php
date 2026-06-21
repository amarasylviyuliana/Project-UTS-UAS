<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Store;
use App\Models\User;

class StoreSeeder extends Seeder
{
    public function run(): void
    {
        $stores = [
            ['email' => 'seller.garut@bumdes.id', 'store_name' => 'BUMDes Garut', 'village' => 'Garut Kota', 'district' => 'Garut', 'regency' => 'Garut', 'contact_phone' => '081234567890'],
            ['email' => 'seller.ciwidey@bumdes.id', 'store_name' => 'BUMDes Ciwidey', 'village' => 'Ciwidey', 'district' => 'Ciwidey', 'regency' => 'Bandung', 'contact_phone' => '081234567891'],
            ['email' => 'seller.pangalengan@bumdes.id', 'store_name' => 'BUMDes Pangalengan', 'village' => 'Pangalengan', 'district' => 'Pangalengan', 'regency' => 'Bandung', 'contact_phone' => '081234567892'],
        ];

        foreach ($stores as $storeData) {
            $seller = User::where('email', $storeData['email'])->first();
            if (! $seller) {
                continue;
            }

            Store::updateOrCreate(
                ['user_id' => $seller->id],
                [
                    'store_name' => $storeData['store_name'],
                    'description' => 'Toko demo BUMDes untuk produk lokal yang saling terkait dengan pembeli dan admin.',
                    'village' => $storeData['village'],
                    'district' => $storeData['district'],
                    'regency' => $storeData['regency'],
                    'contact_phone' => $storeData['contact_phone'],
                    'bank_account_number' => '1234567890',
                    'bank_name' => 'Bank BUMDes',
                    'bank_account_holder' => $seller->name,
                    'store_photo_url' => null,
                    'is_active' => true,
                ]
            );
        }
    }
}
