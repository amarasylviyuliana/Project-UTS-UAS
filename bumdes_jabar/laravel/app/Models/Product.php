<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'category_id',
        'name',
        'type',
        'price',
        'stock',
        'description',
        'photo_url',
        'is_active',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'is_active' => 'boolean',
    ];

    protected $appends = ['image_url'];

    /**
     * Accessor: image_url selalu full URL, dipakai otomatis setiap kali
     * Product di-serialize ke JSON (order, cart, product list, dll).
     * Ini menyatukan logic resolvePhotoUrl yang sebelumnya hanya ada
     * di ProductController sehingga endpoint lain (order) ikut benar.
     */
    public function getImageUrlAttribute(): ?string
    {
        $path = $this->photo_url;
        if (!$path) {
            return null;
        }
        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://project-uts-uas-production.up.railway.app';
        }
        $storagePath = str_starts_with($path, '/') ? $path : '/storage/' . $path;
        return $baseUrl . $storagePath;
    }

    // Relationships
    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function productApproval(): HasOne
    {
        return $this->hasOne(ProductApproval::class);
    }

    public function carts(): HasMany
    {
        return $this->hasMany(Cart::class);
    }

    public function orderItems(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(Review::class);
    }

    // Helper methods
    public function isApproved(): bool
    {
        return $this->productApproval?->status === 'Disetujui';
    }

    public function isPendingApproval(): bool
    {
        return $this->productApproval?->status === 'Menunggu Persetujuan';
    }

    public function isRejected(): bool
    {
        return $this->productApproval?->status === 'Ditolak';
    }
}