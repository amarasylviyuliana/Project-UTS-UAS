<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@bumdes.id'],
            [
                'name' => 'Admin BUMDes Jabar',
                'password' => Hash::make('password123'),
                'role' => 'Admin',
                'phone' => '081111111111',
                'address' => 'Bandung',
            ]
        );

        $sellers = [
            ['email' => 'seller.garut@bumdes.id', 'name' => 'Penjual BUMDes Garut', 'phone' => '082111111111', 'address' => 'Garut'],
            ['email' => 'seller.ciwidey@bumdes.id', 'name' => 'Penjual BUMDes Ciwidey', 'phone' => '082222222222', 'address' => 'Ciwidey'],
            ['email' => 'seller.pangalengan@bumdes.id', 'name' => 'Penjual BUMDes Pangalengan', 'phone' => '082333333333', 'address' => 'Pangalengan'],
        ];

        foreach ($sellers as $seller) {
            User::updateOrCreate(
                ['email' => $seller['email']],
                [
                    'name' => $seller['name'],
                    'password' => Hash::make('password123'),
                    'role' => 'Penjual',
                    'phone' => $seller['phone'],
                    'address' => $seller['address'],
                ]
            );
        }

        $buyers = [
            ['email' => 'buyer.garut@bumdes.id', 'name' => 'Pembeli Garut', 'phone' => '083111111111', 'address' => 'Garut'],
            ['email' => 'buyer.ciwidey@bumdes.id', 'name' => 'Pembeli Ciwidey', 'phone' => '083222222222', 'address' => 'Ciwidey'],
            ['email' => 'buyer.pangalengan@bumdes.id', 'name' => 'Pembeli Pangalengan', 'phone' => '083333333333', 'address' => 'Pangalengan'],
        ];

        foreach ($buyers as $buyer) {
            User::updateOrCreate(
                ['email' => $buyer['email']],
                [
                    'name' => $buyer['name'],
                    'password' => Hash::make('password123'),
                    'role' => 'Pembeli',
                    'phone' => $buyer['phone'],
                    'address' => $buyer['address'],
                ]
            );
        }
    }
}
