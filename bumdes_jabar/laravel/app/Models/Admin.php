<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Admin extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'department',
        'job_title',
        'phone_internal',
        'is_super_admin',
        'permissions',
        'is_active',
    ];

    protected $casts = [
        'is_super_admin' => 'boolean',
        'is_active' => 'boolean',
        'permissions' => 'json',
    ];

    // Relationships
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function productApprovals(): HasMany
    {
        return $this->hasMany(ProductApproval::class, 'admin_id');
    }

    public function auditLogs(): HasMany
    {
        return $this->hasMany(AuditLog::class, 'admin_id');
    }
}
