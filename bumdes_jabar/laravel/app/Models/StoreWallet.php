<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class StoreWallet extends Model
{
    use HasFactory;

    protected $fillable = [
        'store_id',
        'balance',
    ];

   protected $casts = [
    'balance' => 'float',
];

    public function store()
    {
        return $this->belongsTo(Store::class);
    }
}