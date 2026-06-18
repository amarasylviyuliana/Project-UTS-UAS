<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Http\JsonResponse;

class ProfileController extends Controller
{
    /**
     * Get user profile
     * REQ-07
     */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user()->load('store');
        return response()->json($user);
    }

    /**
     * Update user profile
     * REQ-08
     */
    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'phone' => 'sometimes|string|max:20',
            'address' => 'sometimes|string|max:500',
            'photo_url' => 'sometimes|url',
        ]);

        $request->user()->update($validated);

        return response()->json([
            'message' => 'Profil diperbarui berhasil',
            'user' => $request->user(),
        ], 200);
    }

    /**
     * Update password
     * REQ-10
     */
    public function updatePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => 'required',
            'password' => ['required', 'confirmed', Password::min(8)],
        ]);

        if (!Hash::check($validated['current_password'], $request->user()->password)) {
            return response()->json([
                'message' => 'Password saat ini tidak valid',
            ], 422);
        }

        $request->user()->update([
            'password' => $validated['password'],
        ]);

        return response()->json([
            'message' => 'Password diperbarui berhasil',
        ], 200);
    }

    /**
     * Get store profile
     * REQ-09
     */
    public function getStore(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Anda tidak memiliki toko',
            ], 403);
        }

        $store = $user->store;

        if (!$store) {
            return response()->json([
                'message' => 'Toko belum didaftarkan',
            ], 404);
        }

        return response()->json($store);
    }

    /**
     * Create or update store profile
     * REQ-09
     */
    public function createOrUpdateStore(Request $request): JsonResponse
    {
        $user = $request->user();

        if (! $user->isSeller()) {
            return response()->json([
                'message' => 'Hanya penjual yang dapat mendaftarkan toko',
            ], 403);
        }

        $validated = $request->validate([
            'store_name' => 'required|string|max:255',
            'description' => 'sometimes|string',
            'village' => 'required|string|max:100',
            'district' => 'required|string|max:100',
            'regency' => 'required|string|max:100',
            'contact_phone' => 'required|string|max:20',
            'bank_account_number' => 'required|string|max:50',
            'bank_name' => 'required|string|max:100',
            'bank_account_holder' => 'required|string|max:255',
            'store_photo' => 'sometimes|image|mimes:jpeg,png,jpg|max:5120', // 5MB
        ]);

        $storePhotoUrl = null;
        if ($request->hasFile('store_photo')) {
            $storePhotoUrl = $request->file('store_photo')->store('store-photos', 'public');
        }

        $store = $user->store ?: new Store();
        $store->user_id = $user->id;
        $store->fill($validated);
        $store->store_photo_url = $storePhotoUrl ?: $store->store_photo_url;
        $store->save();

        return response()->json([
            'message' => 'Toko berhasil disimpan',
            'store' => $store,
        ], $store->wasRecentlyCreated ? 201 : 200);
    }
}
