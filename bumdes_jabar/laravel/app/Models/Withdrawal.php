<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Withdrawal extends Model
{
    protected $fillable = [
        'store_id',
        'amount',
        'bank_name',
        'bank_account_number',
        'bank_account_name',
        'status',
    ];

    protected $casts = [
    'amount' => 'float',
];

    public function store(): BelongsTo
    {
        return $this->belongsTo(Store::class);
    }
}