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
     *
     * FIX: sebelumnya method ini membangun URL lewat "/storage/{path}"
     * langsung, BEDA dengan ProductController::resolvePhotoUrl() yang
     * dipakai di endpoint produk (index/search/show) yang membangun URL
     * lewat proxy "/api/image/{path}". Akibatnya, tiap kali Product
     * di-serialize di konteks lain (mis. Order->orderItems->product di
     * Riwayat Pesanan), field 'image_url' yang dikirim jadi URL yang
     * beda skema dan seringkali gagal dimuat (foto blank), padahal di
     * halaman daftar produk (yang lewat ProductController) foto yang
     * sama tampil normal.
     *
     * Sekarang logic-nya disamakan persis dengan resolvePhotoUrl() di
     * ProductController, supaya field 'image_url' SELALU konsisten di
     * mana pun Product di-serialize.
     */
    public function getImageUrlAttribute(): ?string
    {
        $path = $this->photo_url;
        if (!$path) {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            if (preg_match('#/storage/(.+)$#', $path, $m)) {
                $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
                if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
                    $baseUrl = 'https://project-uts-uas-production.up.railway.app';
                }
                return $baseUrl . '/api/image/' . $m[1];
            }
            return $path;
        }

        $baseUrl = rtrim(env('APP_URL', 'https://project-uts-uas-production.up.railway.app'), '/');
        if (str_contains($baseUrl, 'localhost') || str_contains($baseUrl, '127.0.0.1')) {
            $baseUrl = 'https://project-uts-uas-production.up.railway.app';
        }
        $cleanPath = preg_replace('#^/?storage/#', '', $path);
        return $baseUrl . '/api/image/' . ltrim($cleanPath, '/');
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