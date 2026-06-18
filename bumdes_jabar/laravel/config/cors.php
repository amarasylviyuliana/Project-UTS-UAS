<?php

return [

    'paths' => ['api/*', 'sanctum/csrf-cookie'],

    'allowed_methods' => ['*'],

    'allowed_origins' => ['http://localhost:51601', 'http://127.0.0.1:51601', '*'],

    'allowed_origins_patterns' => [
        '#^http?://.*$#'
    ],

    'allowed_headers' => ['*'],

    'exposed_headers' => [],

    'max_age' => 7200,

    'supports_credentials' => false,

];