<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        // Buyer account
        User::updateOrCreate([
            'email' => 'buyer@example.com',
        ], [
            'name' => 'Buyer User',
            'password' => Hash::make('password'),
            'role' => 'Pembeli',
            'email_verified_at' => now(),
        ]);

        // Seller account
        User::updateOrCreate([
            'email' => 'seller@example.com',
        ], [
            'name' => 'Seller User',
            'password' => Hash::make('password'),
            'role' => 'Penjual',
            'email_verified_at' => now(),
        ]);

        // Admin account
        User::updateOrCreate([
            'email' => 'admin@example.com',
        ], [
            'name' => 'Admin User',
            'password' => Hash::make('password'),
            'role' => 'Admin',
            'email_verified_at' => now(),
        ]);

        // Legacy test user
        User::updateOrCreate([
            'email' => 'test@example.com',
        ], [
            'name' => 'Test User',
            'password' => Hash::make('password123'),
            'role' => 'Pembeli',
            'email_verified_at' => now(),
        ]);
    }
}
