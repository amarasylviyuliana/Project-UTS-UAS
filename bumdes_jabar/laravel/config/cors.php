<?php

return [

    'paths' => ['api/*', 'storage/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    // FIX: Hapus wildcard '*' saja tidak cukup jika supports_credentials = false
    // Untuk Vercel + Railway, izinkan semua origin (aman untuk public API)
    'allowed_origins' => ['*'],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 7200,

    // FIX: Harus FALSE jika allowed_origins = ['*']
    // Jika TRUE, allowed_origins tidak boleh '*' (browser akan block)
    'supports_credentials' => false,

];