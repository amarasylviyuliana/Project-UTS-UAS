<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // User test bawaan, tetap dipertahankan
        User::updateOrCreate([
            'email' => 'amarasylvi@gmail.com',
        ], [
            'name' => 'Test User',
            'password' => Hash::make('12345678'),
            'role' => 'Pembeli',
        ]);

        // Seller (dibutuhkan oleh StoreSeeder)
        $sellers = [
            ['email' => 'seller.garut@bumdes.id', 'name' => 'Admin BUMDes Garut', 'phone' => '081234567890', 'address' => 'Garut Kota, Garut'],
            ['email' => 'seller.ciwidey@bumdes.id', 'name' => 'Admin BUMDes Ciwidey', 'phone' => '081234567891', 'address' => 'Ciwidey, Bandung'],
            ['email' => 'seller.pangalengan@bumdes.id', 'name' => 'Admin BUMDes Pangalengan', 'phone' => '081234567892', 'address' => 'Pangalengan, Bandung'],
        ];

        foreach ($sellers as $sellerData) {
            User::updateOrCreate([
                'email' => $sellerData['email'],
            ], [
                'name' => $sellerData['name'],
                'password' => Hash::make('12345678'),
                'role' => 'Penjual',
                'phone' => $sellerData['phone'],
                'address' => $sellerData['address'],
            ]);
        }

        // Pembeli demo (dibutuhkan oleh ProductSeeder untuk membuat order demo)
        $buyers = [
            ['email' => 'buyer1@bumdes.id', 'name' => 'Amara Sylvi', 'phone' => '081000000001', 'address' => 'Bandung'],
            ['email' => 'buyer2@bumdes.id', 'name' => 'Budi Santoso', 'phone' => '081000000002', 'address' => 'Garut'],
            ['email' => 'buyer3@bumdes.id', 'name' => 'Citra Dewi', 'phone' => '081000000003', 'address' => 'Ciwidey'],
        ];

        foreach ($buyers as $buyerData) {
            User::updateOrCreate([
                'email' => $buyerData['email'],
            ], [
                'name' => $buyerData['name'],
                'password' => Hash::make('password123'),
                'role' => 'Pembeli',
                'phone' => $buyerData['phone'],
                'address' => $buyerData['address'],
            ]);
        }
    }
}