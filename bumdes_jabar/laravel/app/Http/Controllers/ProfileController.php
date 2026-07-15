<?php

namespace App\Http\Controllers;

use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rules\Password;
use Illuminate\Http\JsonResponse;

class ProfileController extends Controller
{
    // FIX UTAMA: sebelumnya formatUser()/formatStore() memakai
    // Storage::disk('public')->url($path) langsung, menghasilkan URL
    // "/storage/..." yang TERBUKTI gagal dimuat Image.network() di Flutter
    // (CORS blocked + 404 — kemungkinan symlink storage tidak aktif di
    // Railway). Sekarang disamakan persis dengan ProductController@resolvePhotoUrl
    // dan AdminController@formatPhotoUrl: semua path diarahkan lewat proxy
    // "/api/image/{path}", supaya konsisten dan benar-benar bisa dimuat.
    private function resolvePhotoUrl(?string $path): ?string
    {
        if (!$path) {
            return null;
        }

        $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://bumdes-api-production.up.railway.app';
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                return $baseUrl . '/api/image/' . $m[1];
            }
            // Sudah berupa URL lengkap non-storage (mis. sudah proxy /api/image/),
            // biarkan apa adanya.
            return $path;
        }

        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

    public function show(Request $request): JsonResponse
    {
        $user = $request->user()->load('store');
        return response()->json($this->formatUser($user));
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
        return response()->json([
            'message' => 'Profil diperbarui',
            'user'    => $this->formatUser($request->user()->fresh()),
        ]);
    }

    public function updateTelegram(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'telegram_chat_id' => 'required|string|max:50',
        ]);

        $request->user()->update($validated);

        return response()->json([
            'message' => 'Telegram chat ID berhasil disimpan',
            'user'    => $this->formatUser($request->user()->fresh()),
        ]);
    }

    public function uploadPhoto(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'photo' => 'required|image|mimes:jpeg,png,jpg|max:5120',
        ]);

        $user = $request->user();

        // Hapus foto lama kalau ada, biar storage tidak numpuk file yatim
        if ($user->photo_url && Storage::disk('public')->exists($user->photo_url)) {
            Storage::disk('public')->delete($user->photo_url);
        }

        $path = $request->file('photo')->store('profile-photos', 'public');
        // Simpan PATH RELATIF di database (jangan URL penuh),
        // supaya kalau domain berubah, data lama tidak ikut rusak.
        $user->update(['photo_url' => $path]);

        return response()->json([
            'message'   => 'Foto profil berhasil diperbarui',
            // FIX: dulu Storage::disk('public')->url($path) → URL "/storage/..."
            // yang gagal dimuat Flutter. Sekarang lewat proxy /api/image/.
            'photo_url' => $this->resolvePhotoUrl($path),
            'user'      => $this->formatUser($user->fresh()),
        ]);
    }

    // ── TAMBAHAN: hapus foto profil ─────────────────────────────────────────
    // DELETE /profile/photo
    // Menghapus file fisik dari storage (kalau ada) dan mengosongkan kolom
    // photo_url di database. Setelah ini, frontend akan otomatis fallback
    // ke icon default karena photo_url jadi null.
    public function deletePhoto(Request $request): JsonResponse
    {
        $user = $request->user();

        if (!$user->photo_url) {
            return response()->json([
                'message' => 'Tidak ada foto profil untuk dihapus',
            ], 404);
        }

        if (Storage::disk('public')->exists($user->photo_url)) {
            Storage::disk('public')->delete($user->photo_url);
        }

        $user->update(['photo_url' => null]);

        return response()->json([
            'message' => 'Foto profil berhasil dihapus',
            'user'    => $this->formatUser($user->fresh()),
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
            return response()->json(['message' => 'Toko Anda belum diisi oleh Admin. Silakan hubungi Admin.'], 404);
        }

        return response()->json([
            'message' => 'Data toko',
            'data'    => $this->formatStore($store),
        ]);
    }

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

        $storePhotoPath = null;
        if ($request->hasFile('store_photo')) {
            $storePhotoPath = $request->file('store_photo')->store('store-photos', 'public');
        }

        try {
            DB::transaction(function () use ($store, $validated, $storePhotoPath) {
                $store->fill($validated);
                if ($storePhotoPath) {
                    $store->store_photo_url = $storePhotoPath; // tetap simpan path relatif
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
            'data'    => $this->formatStore($store->fresh()),
        ]);
    }

    /**
     * Ubah path relatif di kolom photo_url jadi URL proxy (/api/image/...)
     * sebelum dikirim ke Flutter, sama seperti ProductController & AdminController.
     */
    private function formatUser($user): array
    {
        $data = $user->toArray();
        if (!empty($data['photo_url'])) {
            $data['photo_url'] = $this->resolvePhotoUrl($data['photo_url']);
        }
        if (!empty($data['store'])) {
            $data['store'] = $this->formatStore($user->store);
        }
        return $data;
    }

    private function formatStore($store): array
    {
        $data = $store->toArray();
        if (!empty($data['store_photo_url'])) {
            $data['store_photo_url'] = $this->resolvePhotoUrl($data['store_photo_url']);
        }
        return $data;
    }
}