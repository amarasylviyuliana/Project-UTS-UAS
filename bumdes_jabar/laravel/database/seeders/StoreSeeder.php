<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Store;
use App\Models\User;

class StoreSeeder extends Seeder
{
    public function run(): void
    {
        // Ensure there's at least one user and use its id for the demo store
        $user = User::first();
        if (! $user) {
            $user = User::create([
                'name' => 'Demo Store Owner',
                'email' => 'owner@example.com',
                'password' => bcrypt('password123'),
            ]);
        }

        Store::updateOrCreate([
            'id' => 1,
        ], [
            'user_id' => $user->id,
            'store_name' => 'Toko Demo BUMDes',
            'description' => 'Toko contoh untuk keperluan seeder',
            'village' => 'Demo Village',
            'district' => 'Demo District',
            'regency' => 'Demo Regency',
            'contact_phone' => '081234567890',
            'bank_account_number' => null,
            'bank_name' => null,
            'bank_account_holder' => null,
            'store_photo_url' => null,
            'is_active' => true,
        ]);
    }
}
