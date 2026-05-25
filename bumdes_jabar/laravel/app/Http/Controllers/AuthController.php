<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Models\Store;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\URL;
use Illuminate\Validation\Rules\Password;
use Illuminate\Http\JsonResponse;

class AuthController extends Controller
{
    /**
     * Register a new user
     * REQ-01, REQ-02, REQ-03
     */
    public function register(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => ['required', 'confirmed', Password::min(8)],
            'role' => 'required|in:Pembeli,Penjual,Admin',
        ]);

        try {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => Hash::make($validated['password']),
                'role' => $validated['role'],
                'email_verified_at' => now(), // Auto-verify saat registrasi
            ]);

            try {
                $user->sendEmailVerificationNotification();
            } catch (\Exception $e) {
                // Jika email tidak dapat dikirim, tetap simpan user.
            }

            $response = [
                'message' => 'User registered successfully. Please verify your email.',
                'user' => $user,
            ];

            if (app()->environment('local')) {
                $response['verification_url'] = URL::temporarySignedRoute(
                    'verification.verify',
                    now()->addMinutes(60),
                    ['id' => $user->id, 'hash' => sha1($user->getEmailForVerification())]
                );
            }

            return response()->json($response, 201);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Registration failed',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Login user
     * REQ-04, REQ-05
     */
    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $credentials['email'])->first();

        if (!$user) {
            return response()->json([
                'message' => 'Email atau password tidak valid',
            ], 401);
        }

        if (! Hash::check($credentials['password'], $user->password)) {
            // Fallback untuk user lama dengan password tidak ter-hash
            if (hash_equals($user->password, $credentials['password'])) {
                $user->password = Hash::make($credentials['password']);
                $user->save();
            } else {
                return response()->json([
                    'message' => 'Email atau password tidak valid',
                ], 401);
            }
        }

        if (!$user->email_verified_at) {
            if (app()->environment('local')) {
                $token = $user->createToken('auth_token')->plainTextToken;

                return response()->json([
                    'message' => 'Login berhasil. Email belum diverifikasi, tetapi login diizinkan karena mode pengembangan.',
                    'token' => $token,
                    'access_token' => $token,
                    'token_type' => 'Bearer',
                    'email_verified' => false,
                    'user' => $user,
                ], 200);
            }

            return response()->json([
                'message' => 'Akun belum dikonfirmasi. Silakan verifikasi email Anda.',
            ], 401);
        }

        // Create token using Sanctum
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'message' => 'Login berhasil',
            'token' => $token,
            'access_token' => $token,
            'token_type' => 'Bearer',
            'email_verified' => true,
            'user' => $user,
        ], 200);
    }

    /**
     * Logout user
     * REQ-06
     */
    public function resendVerificationEmail(Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user->hasVerifiedEmail()) {
            return response()->json([
                'message' => 'Email sudah terverifikasi.',
            ], 200);
        }

        try {
            $user->sendEmailVerificationNotification();
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Gagal mengirim ulang email verifikasi.',
                'error' => $e->getMessage(),
            ], 500);
        }

        return response()->json([
            'message' => 'Email verifikasi berhasil dikirim ulang. Cek inbox atau maildev/mailpit Anda.',
        ], 200);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logout berhasil',
        ], 200);
    }

    /**
     * Get authenticated user
     */
    public function me(Request $request): JsonResponse
    {
        return response()->json($request->user());
    }

    /**
     * Verify email
     * REQ-03
     */
    public function verifyEmail(Request $request, $id, $hash): JsonResponse
    {
        $user = User::findOrFail($id);

        if (! hash_equals((string) $hash, sha1($user->getEmailForVerification()))) {
            return response()->json([
                'message' => 'Link verifikasi tidak valid.',
            ], 403);
        }

        if ($user->hasVerifiedEmail()) {
            return response()->json([
                'message' => 'Email sudah diverifikasi.',
            ], 200);
        }

        $user->markEmailAsVerified();

        return response()->json([
            'message' => 'Email berhasil diverifikasi.',
        ], 200);
    }
}
