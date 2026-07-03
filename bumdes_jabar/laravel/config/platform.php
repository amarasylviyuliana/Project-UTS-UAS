<?php

return [
    // Persentase biaya admin/pajak yang dipotong dari tiap transaksi
    // yang berstatus "Selesai". Bisa diubah tanpa deploy ulang lewat
    // environment variable PLATFORM_TAX_PERCENTAGE di Railway.
    'tax_percentage' => (float) env('PLATFORM_TAX_PERCENTAGE', 5),
];