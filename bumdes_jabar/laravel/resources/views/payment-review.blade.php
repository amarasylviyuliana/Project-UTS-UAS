<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Review Pembayaran Seller - BUMDes Jabar</title>
    <script>window.apiBase = "{{ url('api') }}";</script>
    @vite(['resources/css/app.css', 'resources/js/payment-review.js'])
    <style>
        body { font-family: Arial, sans-serif; background: #f4f7f2; margin: 0; padding: 0; }
        .container { max-width: 1024px; margin: 32px auto; padding: 24px; background: white; border-radius: 18px; box-shadow: 0 18px 40px rgba(0,0,0,.08); }
        .heading { margin-bottom: 18px; }
        .heading h1 { margin: 0; font-size: 28px; color: #26432b; }
        .heading p { margin: 8px 0 0; color: #556a50; }
        .grid { display: grid; grid-template-columns: minmax(320px, 1fr) 1.4fr; gap: 24px; }
        .card { background: #fcfff8; border: 1px solid #d9e3d0; border-radius: 16px; padding: 20px; }
        label { display: block; margin-bottom: 8px; font-weight: 600; color: #3f4f3d; }
        input, textarea, button { width: 100%; padding: 12px 14px; margin-bottom: 14px; border: 1px solid #c4d0ba; border-radius: 12px; font-size: 14px; }
        textarea { min-height: 120px; resize: vertical; }
        button { cursor: pointer; border: none; border-radius: 12px; font-weight: 700; transition: background .2s ease; }
        button.primary { background: #3d7d3f; color: white; }
        button.primary:hover { background: #2f5930; }
        button.danger { background: #b34040; color: white; }
        button.danger:hover { background: #8f3232; }
        .message { border-radius: 12px; padding: 14px 18px; margin-bottom: 18px; }
        .message.success { background: #d5edda; color: #1c5f2a; }
        .message.error { background: #fde2e1; color: #801f1d; }
        .info-box { display: grid; gap: 12px; }
        .info-row { display: flex; justify-content: space-between; background: #f8fbf5; padding: 12px 14px; border-radius: 12px; }
        .info-label { color: #586a52; font-weight: 600; }
        .info-value { color: #1e2f1c; }
        .proof-image { width: 100%; max-height: 420px; object-fit: contain; border-radius: 12px; border: 1px solid #dce6d4; background: #fafcf8; }
        .full-width { grid-column: 1 / -1; }
        .action-group { display: flex; gap: 12px; flex-wrap: wrap; }
        .note { background: #eef6e7; border-left: 4px solid #72a05d; padding: 12px 16px; color: #425937; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="heading">
            <h1>Review Pembayaran Seller</h1>
            <p>Lihat bukti transfer pembeli dan konfirmasi atau tolak pembayaran pesanan.</p>
        </div>

        <div id="pageMessage"></div>

        <div class="grid">
            <div class="card">
                <h2>Cari Pesanan</h2>
                <label for="orderId">ID Pesanan</label>
                <input id="orderId" type="text" placeholder="Masukkan ID pesanan" />
                <button id="loadButton" class="primary">Cek Bukti Pembayaran</button>
                <div class="note">
                    Masukkan ID pesanan untuk melihat bukti transfer yang diunggah oleh pembeli. Pastikan seller sudah login.
                </div>
            </div>

            <div class="card">
                <h2>Detail Pesanan</h2>
                <div id="paymentInfo" class="info-box"></div>
                <div id="proofContainer" style="display:none;">
                    <label>Bukti Transfer</label>
                    <img id="proofImage" class="proof-image" alt="Bukti transfer" />
                </div>
                <div class="action-group full-width">
                    <button id="confirmButton" class="primary">Konfirmasi Pembayaran</button>
                    <button id="rejectButton" class="danger">Tolak Pembayaran</button>
                </div>
                <label for="rejectReason">Alasan Tolak (opsional)</label>
                <textarea id="rejectReason" placeholder="Isi alasan jika pembayaran ditolak"></textarea>
            </div>
        </div>
    </div>
</body>
</html>
