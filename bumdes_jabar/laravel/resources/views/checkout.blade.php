<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Checkout Demo</title>
    <script>window.apiBase = "{{ url('api') }}";</script>
    @vite(['resources/css/app.css', 'resources/js/checkout.js'])
    <style>
        body { font-family: Arial, sans-serif; background: #f2f6f0; margin: 0; padding: 0; }
        .container { max-width: 960px; margin: 32px auto; padding: 24px; background: white; border-radius: 16px; box-shadow: 0 10px 35px rgba(0,0,0,.08); }
        h1 { margin-top: 0; }
        .grid { display: grid; gap: 24px; grid-template-columns: 1fr 1fr; }
        .card { background: #fbfff7; padding: 20px; border-radius: 16px; border: 1px solid #e6eddc; }
        label { display: block; margin-bottom: 8px; font-weight: 600; }
        input, textarea, button { width: 100%; padding: 12px 14px; margin-bottom: 14px; border-radius: 10px; border: 1px solid #c9d2ba; font-size: 14px; }
        textarea { min-height: 100px; resize: vertical; }
        button { cursor: pointer; background: #4a7c3f; color: white; border: none; font-weight: 700; }
        button.secondary { background: #7d8f6a; }
        .message { padding: 14px 18px; border-radius: 12px; margin-bottom: 16px; }
        .message.error { background: #f8d7da; color: #842029; }
        .message.success { background: #d1e7dd; color: #0f5132; }
        .cart-list { list-style: none; padding: 0; margin: 0; }
        .cart-item { padding: 14px; border-bottom: 1px solid #dbe5d1; }
        .cart-item:last-child { border-bottom: none; }
        .full-width { grid-column: 1 / -1; }
        .full-width button { width: auto; display: inline-flex; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Checkout Demo</h1>
        <p>Gunakan halaman ini untuk mencoba login, tambah cart, lihat ringkasan, dan checkout.</p>

        <div class="grid">
            <div class="card">
                <h2>Login</h2>
                <div id="loginMessage"></div>
                <label for="loginEmail">Email</label>
                <input id="loginEmail" type="email" placeholder="email@example.com" value="buyer@example.com">
                <label for="loginPassword">Password</label>
                <input id="loginPassword" type="password" placeholder="password">
                <button id="loginButton">Login</button>
                <p>Token: <code id="tokenValue" style="word-break: break-all;"></code></p>
            </div>

            <div class="card">
                <h2>Tambah ke Keranjang</h2>
                <div id="cartMessage"></div>
                <label for="productSelect">Pilih Produk</label>
                <select id="productSelect" style="width:100%; padding:12px 14px; margin-bottom:14px; border-radius:10px; border:1px solid #c9d2ba; background:white;"></select>
                <label for="productQty">Quantity</label>
                <input id="productQty" type="number" value="1" min="1">
                <button class="secondary" id="addCartButton">Tambah ke Cart</button>
                <button id="refreshCartButton">Refresh Keranjang</button>
            </div>

            <div class="card full-width">
                <h2>Ringkasan Keranjang</h2>
                <div id="cartSummary"></div>
                <ul class="cart-list" id="cartList"></ul>
                <p><strong>Total:</strong> <span id="cartTotal">0</span></p>
            </div>

            <div class="card full-width">
                <h2>Checkout Sekarang</h2>
                <div id="checkoutMessage"></div>
                <label for="recipientName">Nama Penerima</label>
                <input id="recipientName" type="text" placeholder="Nama Penerima">
                <label for="recipientPhone">No. HP Penerima</label>
                <input id="recipientPhone" type="text" placeholder="0895...">
                <label for="recipientAddress">Alamat Pengiriman</label>
                <textarea id="recipientAddress" placeholder="Alamat lengkap"></textarea>
                <label for="notes">Catatan</label>
                <textarea id="notes" placeholder="Opsional"></textarea>
                <button id="checkoutButton">Checkout Sekarang</button>
                <p id="orderResult"></p>
            </div>
        </div>
    </div>
</body>
</html>