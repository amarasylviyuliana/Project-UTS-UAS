<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bayar Pesanan - BUMDes Jabar</title>
    <script>window.apiBase = "{{ url('api') }}";</script>
    @vite(['resources/css/app.css', 'resources/js/payment.js'])
    <style>
        body { font-family: Arial, sans-serif; background: #f3f7f2; margin: 0; padding: 0; }
        .container { max-width: 980px; margin: 32px auto; padding: 24px; background: white; border-radius: 20px; box-shadow: 0 14px 35px rgba(0,0,0,.08); }
        h1 { margin-top: 0; }
        .grid { display: grid; gap: 24px; grid-template-columns: 1fr 1fr; }
        .card { background: #fbfff7; padding: 20px; border-radius: 18px; border: 1px solid #e5edd9; }
        input, select, textarea, button { width: 100%; padding: 12px 14px; margin-bottom: 14px; border-radius: 10px; border: 1px solid #ccd3c3; font-size: 14px; }
        button { cursor: pointer; background: #3d7d3f; color: white; border: none; font-weight: 700; }
        button.secondary { background: #7d8f6a; }
        .message { padding: 14px 18px; border-radius: 12px; margin-bottom: 16px; }
        .message.error { background: #f8d7da; color: #842029; }
        .message.success { background: #d1e7dd; color: #0f5132; }
        .info-box { background: #ffffff; border: 1px solid #d7dfcf; border-radius: 14px; padding: 16px; }
        .info-row { display: grid; grid-template-columns: 1fr 2fr; gap: 12px; margin-bottom: 10px; }
        .info-label { color: #5f6b53; font-weight: 600; }
        .info-value { color: #2c3c29; }
        .full-width { grid-column: 1 / -1; }
        .note { background: #eef6e9; border-left: 4px solid #6a8f5b; padding: 14px 18px; border-radius: 10px; color: #3c522f; margin-bottom: 18px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Pembayaran Pesanan</h1>
        <p>Unggah bukti transfer manual agar penjual dapat mengonfirmasi pesanan Anda.</p>

        <div class="grid">
            <div class="card">
                <h2>Informasi Pesanan</h2>
                <div id="paymentMessage"></div>
                <label for="orderId">ID Pesanan</label>
                <input id="orderId" type="text" placeholder="Masukkan ID pesanan" />
                <button id="loadPaymentButton">Cek Detail Pembayaran</button>

                <div id="paymentDetails" class="info-box" style="display:none;">
                    <div class="info-row"><div class="info-label">Nomor Pesanan</div><div id="detailOrderNumber" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">Total Bayar</div><div id="detailTotalAmount" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">Status Pembayaran</div><div id="detailStatus" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">Bank</div><div id="detailBankName" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">No. Rekening</div><div id="detailAccountNumber" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">Pemilik Rekening</div><div id="detailAccountHolder" class="info-value"></div></div>
                    <div class="info-row"><div class="info-label">Bukti Saat Ini</div><div id="detailProof" class="info-value"></div></div>
                </div>
            </div>

            <div class="card">
                <h2>Upload Bukti Transfer</h2>
                <div class="note">Pastikan Anda sudah login, lalu masukkan ID pesanan yang ingin dibayar. Setelah itu unggah file bukti transfer (jpg/png) dan kirim.</div>

                <label for="proofImage">Foto Bukti Transfer</label>
                <input id="proofImage" type="file" accept="image/jpeg,image/png" />
                <button id="uploadProofButton">Unggah Bukti Transfer</button>
            </div>

            <div class="card full-width">
                <h2>Petunjuk Pembayaran</h2>
                <div class="note">
                    1. Pilih pesanan dengan status <strong>Menunggu Pembayaran</strong>.<br>
                    2. Lakukan transfer ke rekening yang ditampilkan pada detail pesanan.<br>
                    3. Unggah foto bukti transfer di sini.<br>
                    4. Penjual akan memeriksa dan mengonfirmasi pembayaran.
                </div>
                <p>Jika status berubah menjadi <strong>Menunggu Konfirmasi</strong>, berarti bukti sudah terkirim dan menunggu persetujuan penjual.</p>
                <p>Jika bukti ditolak, Anda akan diminta mengunggah ulang dengan bukti yang benar.</p>
            </div>
        </div>
    </div>
</body>
</html>
