<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Store extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'store_name',
        'description',
        'village',
        'district',
        'regency',
        'contact_phone',
        'bank_account_number',
        'bank_name',
        'bank_account_holder',
        'store_photo_url',
        'is_active',
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function storeApproval(): HasOne
    {
        return $this->hasOne(StoreApproval::class);
    }

    public function sellerVerification(): HasOne
    {
        return $this->hasOne(SellerVerification::class);
    }

    public function products(): HasMany
    {
        return $this->hasMany(Product::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    // Helper methods
    public function isApproved(): bool
    {
        return $this->storeApproval?->status === 'Disetujui';
    }

    public function isPendingApproval(): bool
    {
        return $this->storeApproval?->status === 'Menunggu Persetujuan';
    }

    public function isVerified(): bool
    {
        return $this->sellerVerification?->status === 'Terverifikasi';
    }
}
