<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Auth\MustVerifyEmail;
use Laravel\Sanctum\HasApiTokens;
use Illuminate\Contracts\Auth\MustVerifyEmail as MustVerifyEmailContract;

class User extends Authenticatable implements MustVerifyEmailContract
{
    use HasApiTokens, HasFactory, Notifiable, MustVerifyEmail;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'phone',
        'address',
        'photo_url',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'email_verified_at' => 'datetime',
        'password' => 'hashed',
    ];

    public function normalizeRole(): string
    {
        $role = strtolower($this->role ?? '');

        if (str_contains($role, 'penjual') || str_contains($role, 'seller')) {
            return 'penjual';
        }

        if (str_contains($role, 'pembeli') || str_contains($role, 'buyer')) {
            return 'pembeli';
        }

        if (str_contains($role, 'admin')) {
            return 'admin';
        }

        return $role;
    }

    public function isSeller(): bool
    {
        return $this->normalizeRole() === 'penjual';
    }

    public function isBuyer(): bool
    {
        return $this->normalizeRole() === 'pembeli';
    }

    public function isAdmin(): bool
    {
        return $this->normalizeRole() === 'admin';
    }

    // Relationships
    public function store(): HasOne
    {
        return $this->hasOne(Store::class);
    }

    public function admin(): HasOne
    {
        return $this->hasOne(Admin::class);
    }

    public function sellerVerification(): HasOne
    {
        return $this->hasOne(SellerVerification::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'buyer_id');
    }

    public function carts(): HasMany
    {
        return $this->hasMany(Cart::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class, 'buyer_id');
    }

    // Helper methods
    public function isVerifiedSeller(): bool
    {
        if (!$this->isSeller()) return false;
        return $this->sellerVerification?->status === 'Terverifikasi';
    }
}

