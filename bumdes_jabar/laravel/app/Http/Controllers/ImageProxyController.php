<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ImageProxyController extends Controller
{
    /**
     * Proxy file dari storage/app/public lewat route Laravel,
     * supaya header CORS bisa kita set manual.
     */
    public function show(Request $request, string $path)
    {
        $path = ltrim($path, '/');
        if (str_contains($path, '..')) {
            abort(400, 'Invalid path');
        }

        if (! Storage::disk('public')->exists($path)) {
            abort(404, 'File not found');
        }

        $fullPath = Storage::disk('public')->path($path);
        $mimeType = Storage::disk('public')->mimeType($path) ?? 'application/octet-stream';

        return response()->file($fullPath, [
            'Content-Type' => $mimeType,
            'Access-Control-Allow-Origin' => '*',
            'Cache-Control' => 'public, max-age=31536000',
        ]);
    }
}