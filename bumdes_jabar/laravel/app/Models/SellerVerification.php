<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SellerVerification extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'store_id',
        'status',
        'verified_by',
        'verification_date',
        'rejection_reason',
        'document_url',
        'notes',
    ];

    protected $casts = [
        'verification_date' => 'datetime',
    ];

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }

    public function verifiedBy(): BelongsTo
    {
        return $this->belongsTo(Admin::class, 'verified_by');
    }
}
