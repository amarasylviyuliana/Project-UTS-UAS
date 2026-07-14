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
        'tags',
    ];

    protected $casts = [
        'price' => 'decimal:2',
        'is_active' => 'boolean',
        // 'tags' = atribut produk yang mungkin tidak tertulis di judul,
        // mis. ["pedas", "gurih", "khas garut"]. Disimpan JSON, dibaca
        // sebagai array PHP biasa.
        'tags' => 'array',
    ];

    protected $appends = ['image_url'];

    /**
     * Setiap kali produk dibuat/diubah/dihapus, sinkronkan otomatis ke
     * index Algolia supaya fitur pencarian AI selalu up-to-date tanpa
     * perlu reindex manual. Dibungkus try/catch di dalam AlgoliaService
     * sendiri supaya kegagalan Algolia (mis. saat development lokal
     * tanpa API key) tidak sampai menggagalkan proses simpan produk.
     */
    protected static function booted(): void
    {
        static::saved(function (Product $product) {
            $fresh = $product->fresh(['category', 'store']);
            if ($fresh) {
                app(\App\Services\AlgoliaService::class)->saveProduct($fresh);
            }
        });

        static::deleted(function (Product $product) {
            app(\App\Services\AlgoliaService::class)->deleteProduct($product->id);
        });
    }

    public function getImageUrlAttribute(): ?string
    {
        $path = $this->photo_url;
        if (!$path) {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
                if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
                    $baseUrl = 'https://bumdes-api-production.up.railway.app';
                }
                return $baseUrl . '/api/image/' . $m[1];
            }
            return $path;
        }

        $baseUrl = rtrim(env('APP_URL', 'https://bumdes-api-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://bumdes-api-production.up.railway.app';
        }
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
    }

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