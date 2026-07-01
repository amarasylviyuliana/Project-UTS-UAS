<?php

namespace App\Http\Controllers;

use App\Models\Store;
use App\Models\StoreApproval;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Http\JsonResponse;

class ProfileController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user()->load('store');
        return response()->json($user);
    }

    public function update(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'      => 'sometimes|string|max:255',
            'phone'     => 'sometimes|string|max:20',
            'address'   => 'sometimes|string|max:500',
            'photo_url' => 'sometimes|url',
        ]);
        $request->user()->update($validated);
        return response()->json(['message' => 'Profil diperbarui', 'user' => $request->user()]);
    }

    public function updatePassword(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'current_password' => 'required',
            'password'         => ['required', 'confirmed', Password::min(8)],
        ]);
        if (!Hash::check($validated['current_password'], $request->user()->password)) {
            return response()->json(['message' => 'Password saat ini tidak valid'], 422);
        }
        $request->user()->update(['password' => $validated['password']]);
        return response()->json(['message' => 'Password diperbarui']);
    }

    public function getStore(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user->isSeller()) {
            return response()->json(['message' => 'Anda tidak memiliki toko'], 403);
        }
        $store = $user->store;
        if (!$store) {
            return response()->json(['message' => 'Toko belum didaftarkan'], 404);
        }

        $store->load('storeApproval');

        return response()->json([
            'message' => 'Data toko',
            'data'    => array_merge($store->toArray(), [
                'store_approval' => $store->storeApproval?->toArray(),
            ]),
        ]);
    }

    public function createOrUpdateStore(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user->isSeller()) {
            return response()->json(['message' => 'Hanya penjual yang dapat mendaftarkan toko'], 403);
        }

        $validated = $request->validate([
            'store_name'          => 'required|string|max:255',
            'description'         => 'nullable|string',
            'village'             => 'required|string|max:100',
            'district'            => 'required|string|max:100',
            'regency'             => 'required|string|max:100',
            'contact_phone'       => 'required|string|max:20',
            'bank_account_number' => 'required|string|max:50',
            'bank_name'           => 'required|string|max:100',
            'bank_account_holder' => 'required|string|max:255',
            'store_photo'         => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        $existingStore = $user->store;
        $isNew = !$existingStore;

        $storePhotoUrl = null;
        if ($request->hasFile('store_photo')) {
            $storePhotoUrl = $request->file('store_photo')->store('store-photos', 'public');
        }

        try {
            $store = DB::transaction(function () use ($user, $existingStore, $isNew, $validated, $storePhotoUrl) {
                $store = $existingStore ?: new Store();
                $store->user_id = $user->id;
                $store->fill($validated);

                if ($storePhotoUrl) {
                    $store->store_photo_url = $storePhotoUrl;
                }

                if ($isNew) {
                    $store->is_active = false;
                }

                $store->save();

                // Pakai updateOrCreate agar tidak duplicate error
                // kalau approval sudah ada, update status-nya saja
                // kalau belum ada, buat baru
                StoreApproval::updateOrCreate(
                    ['store_id' => $store->id],
                    ['status'   => 'Menunggu Persetujuan']
                );

                return $store;
            });
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Gagal menyimpan data toko: ' . $e->getMessage(),
            ], 500);
        }

        $store->load('storeApproval');

        return response()->json([
            'message' => $isNew
                ? 'Toko berhasil didaftarkan, menunggu persetujuan admin'
                : 'Toko berhasil diperbarui',
            'data' => array_merge($store->toArray(), [
                'store_approval' => $store->storeApproval?->toArray(),
            ]),
        ], $isNew ? 201 : 200);
    }
}