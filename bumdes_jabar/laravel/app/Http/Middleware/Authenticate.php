<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;
use Illuminate\Http\Request;

class Authenticate extends Middleware
{
    /**
     * Get the path the user should be redirected to when they are not authenticated.
     */
    protected function redirectTo(Request $request): ?string
    {
        // Untuk request API, jangan redirect ke route web.
        // Frontend (Flutter web) mengirim XHR/fetch sehingga harus diperlakukan sebagai JSON.
        if ($request->expectsJson() || $request->is('api/*') || $request->is('*/api/*')) {
            return null;
        }


        return route('login');
    }
}
