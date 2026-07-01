import { defineConfig } from 'vite';
import laravel from 'laravel-vite-plugin';

export default defineConfig({
    plugins: [
        laravel({
            input: ['resources/css/app.css', 'resources/js/app.js', 'resources/js/checkout.js', 'resources/js/payment.js', 'resources/js/payment-review.js'],
            refresh: true,
        }),
    ],
});
