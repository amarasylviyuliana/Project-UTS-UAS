Direct Telegram fallback
------------------------

Service `N8nNotificationService` sekarang mencoba fallback: jika n8n unreachable atau menolak request, backend akan mencoba mengirim pesan langsung ke Telegram Bot API bila variabel `TELEGRAM_BOT_TOKEN` tersedia di `.env`.

Steps to enable fallback:

1. Add `TELEGRAM_BOT_TOKEN` to `bumdes_jabar/laravel/.env` (optional, only needed if you want Laravel to send directly when n8n fails). Keep this secret.

2. Ensure `N8N_TELEGRAM_GROUP_CHAT_ID` is set so fallback can at least post to group when buyer/seller chat id is null.

3. Restart Laravel config cache as above.

Notes:
- Fallback message is a simple HTML-formatted summary. Customize `buildTelegramText()` in `app/Services/N8nNotificationService.php` if needed.
- Prefer putting bot token in n8n credentials and not in Laravel. Fallback is provided for higher reliability but is optional.
Panduan konfigurasi n8n untuk menerima payload dari Laravel dan mengirim pesan ke Telegram group

Ringkas:
1) Tambahkan bot Telegram ke grup target.
2) Siapkan kredensial bot di n8n (atau set environment variable `N8N_TELEGRAM_BOT_TOKEN`).
3) Impor workflow template `n8n/workflows/bumdes_notify_workflow_template.json` ke n8n.
4) Pastikan Laravel `N8N_WEBHOOK_URL` mengarah ke webhook n8n yang sesuai (mis. https://n8n.example.com/webhook/bumdes-notify).
5) Set environment `N8N_TELEGRAM_GROUP_CHAT_ID` di Laravel `.env`.

Detail langkah:

A. Tambah bot ke grup
- Buka Telegram group, tambahkan bot (username) sebagai member. Kirim pesan tes di grup.

B. Dapatkan/Nyatakan bot token ke n8n
- Di n8n, buat credential baru berjenis "HTTP Header Auth" atau simpan token sebagai credential/environment variable bernama `N8N_TELEGRAM_BOT_TOKEN`.
- Atau di Settings -> Credentials, buat credential `TelegramBot` (opsional) dan masukkan token.

C. Impor workflow
- Import file `n8n/workflows/bumdes_notify_workflow_template.json`.
- Pada node `Send To Buyer` dan `Send To Group`, pastikan URL memiliki token yang benar. Anda bisa mengganti bagian `{{ $env["N8N_TELEGRAM_BOT_TOKEN"] }}` dengan credential atau environment variable.

D. Set Laravel
- Di project Laravel (`bumdes_jabar/laravel/.env`):
  - N8N_WEBHOOK_URL=https://your-n8n.example.com/webhook/bumdes-notify
  - N8N_TELEGRAM_GROUP_CHAT_ID=-1001234567890
- Jalankan:
  php artisan config:clear
  php artisan cache:clear

E. Tes end-to-end
1) Pastikan n8n berjalan dan webhook aktif. Di n8n, kirim test ke webhook dari UI (Execute Workflow -> Run) atau gunakan curl dari backend.
2) Dari server Laravel gunakan debug endpoint (sudah dibuat):
   POST /api/debug/n8n/test
   Payload contoh:
   {
     "event":"order_created",
     "order_number":"ORD-TEST-1",
     "pembeli_telegram_chat_id":null,
     "seller_telegram_chat_id":null,
     "item":"Test Item",
     "total":10000
   }
3) Periksa eksekusi workflow di n8n dan apakah pesan berhasil dikirim ke grup.

F. Troubleshooting singkat
- Jika n8n tidak menerima payload: periksa `N8N_WEBHOOK_URL` dan akses network (firewall/SSL).
- Jika Telegram menolak: pastikan bot ada di grup dan `chat_id` benar. Gunakan `getUpdates` untuk melihat chat.id.
- Jika pesan tidak terkirim dari n8n: cek node `HTTP Request` response body di execution log.

Jika mau, saya bisa bantu:
- Memformat output `getUpdates` jika Anda paste di chat. Saya akan ambil `chat.id`.
- Membuat curl yang memanggil debug endpoint dari lingkungan Anda jika Anda jalankan server Laravel.

