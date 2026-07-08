<?php

namespace App\Http\Controllers;

use App\Models\Store;
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
            'name'              => 'sometimes|string|max:255',
            'phone'             => 'sometimes|string|max:20',
            'telegram_chat_id'  => 'sometimes|nullable|string|max:50',
            'address'           => 'sometimes|string|max:500',
            'photo_url'         => 'sometimes|url',
        ]);
        $request->user()->update($validated);
        return response()->json(['message' => 'Profil diperbarui', 'user' => $request->user()]);
    }
public function uploadPhoto(Request $request): JsonResponse
{
    $validated = $request->validate([
        'photo' => 'required|image|mimes:jpeg,png,jpg|max:5120',
    ]);

    $user = $request->user();

    // Hapus foto lama kalau ada, biar storage tidak numpuk file yatim
    if ($user->photo_url && \Illuminate\Support\Facades\Storage::disk('public')->exists($user->photo_url)) {
        \Illuminate\Support\Facades\Storage::disk('public')->delete($user->photo_url);
    }

    $path = $request->file('photo')->store('profile-photos', 'public');
    $user->update(['photo_url' => $path]);

    return response()->json([
        'message'   => 'Foto profil berhasil diperbarui',
        'photo_url' => $path,
        'user'      => $user->fresh(),
    ]);
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
            // Toko Penjual sekarang dibuat langsung oleh Admin saat akun
            // dibuat. Kalau belum ada, artinya data toko belum diisi Admin.
            return response()->json(['message' => 'Toko Anda belum diisi oleh Admin. Silakan hubungi Admin.'], 404);
        }

        return response()->json([
            'message' => 'Data toko',
            'data'    => $store,
        ]);
    }

    /**
     * Perbarui data toko milik Penjual yang sedang login.
     *
     * PENTING: Penjual TIDAK bisa lagi membuat toko baru lewat endpoint ini.
     * Toko/BUMDes sekarang dibuat langsung oleh Admin bersamaan dengan akun
     * Penjual (lihat AdminController@createUser) dan otomatis aktif. Endpoint
     * ini hanya untuk Penjual mengedit data toko miliknya sendiri yang sudah ada.
     */
    public function createOrUpdateStore(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user->isSeller()) {
            return response()->json(['message' => 'Hanya penjual yang dapat mengelola toko'], 403);
        }

        $store = $user->store;
        if (!$store) {
            return response()->json([
                'message' => 'Toko Anda belum dibuat oleh Admin. Silakan hubungi Admin untuk membuat akun toko Anda.',
            ], 404);
        }

        $validated = $request->validate([
            'store_name'          => 'sometimes|required|string|max:255',
            'description'         => 'nullable|string',
            'village'             => 'sometimes|required|string|max:100',
            'district'            => 'sometimes|required|string|max:100',
            'regency'             => 'sometimes|required|string|max:100',
            'contact_phone'       => 'sometimes|required|string|max:20',
            'bank_account_number' => 'sometimes|required|string|max:50',
            'bank_name'           => 'sometimes|required|string|max:100',
            'bank_account_holder' => 'sometimes|required|string|max:255',
            'store_photo'         => 'sometimes|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        $storePhotoUrl = null;
        if ($request->hasFile('store_photo')) {
            $storePhotoUrl = $request->file('store_photo')->store('store-photos', 'public');
        }

        try {
            DB::transaction(function () use ($store, $validated, $storePhotoUrl) {
                $store->fill($validated);
                if ($storePhotoUrl) {
                    $store->store_photo_url = $storePhotoUrl;
                }
                $store->save();
            });
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Gagal menyimpan data toko: ' . $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'message' => 'Toko berhasil diperbarui',
            'data'    => $store->fresh(),
        ]);
    }
}