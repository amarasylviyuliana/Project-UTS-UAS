<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Riwayat Pesanan - BUMDes Jabar</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; padding: 24px; }
        .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .header h1 { color: #333; font-size: 28px; }
        .header p { color: #666; margin-top: 8px; font-size: 14px; }
        .card { background: white; border-radius: 8px; padding: 20px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .order-item { border-bottom: 1px solid #eee; padding-bottom: 16px; margin-bottom: 16px; }
        .order-item:last-child { border-bottom: none; padding-bottom: 0; margin-bottom: 0; }
        .order-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
        .order-number { font-weight: bold; color: #333; font-size: 16px; }
        .order-status { padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; }
        .status-pending { background: #fff3cd; color: #856404; }
        .status-confirmed { background: #d1ecf1; color: #0c5460; }
        .status-shipped { background: #d4edda; color: #155724; }
        .status-completed { background: #d4edda; color: #155724; }
        .status-cancelled { background: #f8d7da; color: #721c24; }
        .order-meta { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-top: 12px; font-size: 14px; }
        .meta-item { display: flex; flex-direction: column; }
        .meta-label { color: #999; font-weight: 600; font-size: 12px; margin-bottom: 4px; }
        .meta-value { color: #333; }
        .products-list { margin-top: 12px; }
        .product-row { display: flex; justify-content: space-between; align-items: center; padding: 8px 0; border-top: 1px solid #f0f0f0; }
        .product-row:first-child { border-top: none; }
        .product-info { flex: 1; }
        .product-name { color: #333; font-weight: 500; font-size: 14px; }
        .product-qty { color: #999; font-size: 13px; }
        .product-total { color: #333; font-weight: 600; text-align: right; }
        .error-message { background: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; padding: 16px; border-radius: 8px; margin-bottom: 20px; }
        .loading { text-align: center; padding: 40px; color: #999; }
        .empty { text-align: center; padding: 40px; color: #999; }
        .btn-group { margin-top: 12px; display: flex; gap: 8px; }
        .btn { padding: 8px 16px; border: none; border-radius: 4px; font-size: 13px; cursor: pointer; background: #007bff; color: white; }
        .btn-secondary { background: #6c757d; }
        .debug-info { background: #f0f0f0; border: 1px solid #ddd; padding: 12px; border-radius: 4px; margin-bottom: 16px; font-family: monospace; font-size: 12px; color: #333; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Riwayat Pesanan</h1>
            <p>Lihat semua pesanan Anda di sini</p>
        </div>

        <div id="debugInfo" class="debug-info" style="display:none;"></div>
        <div id="errorMessage" class="error-message" style="display:none;"></div>
        <div id="loadingMessage" class="loading" style="display:none;">Memuat pesanan...</div>
        <div id="emptyMessage" class="empty" style="display:none;">Anda belum memiliki pesanan</div>
        <div id="ordersList"></div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/axios/dist/axios.min.js"></script>
    <script>
        const apiBase = "{{ url('api') }}";
        const authToken = localStorage.getItem('auth_token');
        const debugInfo = document.getElementById('debugInfo');
        const errorMessage = document.getElementById('errorMessage');
        const loadingMessage = document.getElementById('loadingMessage');
        const emptyMessage = document.getElementById('emptyMessage');
        const ordersList = document.getElementById('ordersList');

        function log(message) {
            console.log('[Orders Page]', message);
            debugInfo.textContent += (debugInfo.textContent ? '\n' : '') + '[' + new Date().toLocaleTimeString() + '] ' + message;
            debugInfo.style.display = 'block';
        }

        function showError(message) {
            errorMessage.textContent = '❌ ' + message;
            errorMessage.style.display = 'block';
            loadingMessage.style.display = 'none';
            log('ERROR: ' + message);
        }

        function getHeaders() {
            const headers = { 'Content-Type': 'application/json', 'Accept': 'application/json' };
            if (authToken) {
                headers['Authorization'] = `Bearer ${authToken}`;
                log('Auth Header: Bearer ' + authToken.substring(0, 20) + '...');
            } else {
                log('WARNING: No auth token found in localStorage');
            }
            return headers;
        }

        async function loadOrders() {
            try {
                log('Starting to load orders...');
                log('API Base: ' + apiBase);
                log('Auth Token: ' + (authToken ? 'Found' : 'NOT FOUND'));

                if (!authToken) {
                    showError('Token tidak ditemukan. Silakan login terlebih dahulu.');
                    return;
                }

                loadingMessage.style.display = 'block';
                log('Sending GET request to /api/orders');

                const response = await axios.get(`${apiBase}/orders`, { 
                    headers: getHeaders(),
                    validateStatus: () => true // Don't throw on any status code
                });

                log('Response Status: ' + response.status);
                log('Response Headers: ' + JSON.stringify(response.headers));
                log('Response Data: ' + JSON.stringify(response.data).substring(0, 200) + '...');

                if (response.status !== 200) {
                    showError(`HTTP ${response.status}: ${response.data?.message || 'Unknown error'}`);
                    return;
                }

                const data = response.data;
                const orders = data.data?.data || data.data || [];

                log('Orders Count: ' + (Array.isArray(orders) ? orders.length : 'Not array'));

                if (!Array.isArray(orders) || orders.length === 0) {
                    loadingMessage.style.display = 'none';
                    emptyMessage.style.display = 'block';
                    log('No orders found');
                    return;
                }

                loadingMessage.style.display = 'none';
                renderOrders(orders);
                log('Successfully rendered ' + orders.length + ' orders');

            } catch (error) {
                log('EXCEPTION: ' + error.message);
                if (error.response) {
                    log('Response Status: ' + error.response.status);
                    log('Response Data: ' + JSON.stringify(error.response.data));
                }
                showError(error.message || 'Gagal memuat riwayat pesanan');
            }
        }

        function renderOrders(orders) {
            ordersList.innerHTML = orders.map(order => {
                const statusClass = getStatusClass(order.status);
                const items = order.orderItems || order.order_items || [];
                const storeName = order.store?.store_name || 'Unknown Store';

                return `
                    <div class="card">
                        <div class="order-item">
                            <div class="order-header">
                                <div>
                                    <div class="order-number">Order #${order.order_number}</div>
                                </div>
                                <span class="order-status ${statusClass}">${order.status}</span>
                            </div>
                            <div class="order-meta">
                                <div class="meta-item">
                                    <div class="meta-label">Toko</div>
                                    <div class="meta-value">${storeName}</div>
                                </div>
                                <div class="meta-item">
                                    <div class="meta-label">Tanggal Pesan</div>
                                    <div class="meta-value">${new Date(order.created_at).toLocaleDateString('id-ID')}</div>
                                </div>
                                <div class="meta-item">
                                    <div class="meta-label">Total Harga</div>
                                    <div class="meta-value">Rp ${formatCurrency(order.total_price)}</div>
                                </div>
                            </div>
                            <div class="products-list">
                                <div style="color: #666; font-weight: 600; margin-bottom: 8px; font-size: 13px;">Produk:</div>
                                ${items.length > 0 ? items.map(item => `
                                    <div class="product-row">
                                        <div class="product-info">
                                            <div class="product-name">${item.product?.name || 'Unknown Product'}</div>
                                            <div class="product-qty">Qty: ${item.quantity} × Rp ${formatCurrency(item.unit_price)}</div>
                                        </div>
                                        <div class="product-total">Rp ${formatCurrency(item.subtotal)}</div>
                                    </div>
                                `).join('') : '<div style="color: #999; font-size: 13px;">Tidak ada produk</div>'}
                            </div>
                            <div class="btn-group">
                                <button class="btn" onclick="alert('Detail Pesanan ID: ' + ${order.id})">Detail</button>
                                ${order.status === 'Menunggu Pembayaran' ? `<button class="btn" style="background:#0d6efd;color:white;" onclick="window.location.href='/payment?order_id=${order.id}'">Bayar</button>` : ''}
                                <button class="btn btn-secondary" onclick="alert('Hubungi toko untuk bantuan')">Hubungi Toko</button>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
        }

        function getStatusClass(status) {
            const statusMap = {
                'Menunggu Pembayaran': 'status-pending',
                'Menunggu Konfirmasi': 'status-pending',
                'Dikonfirmasi': 'status-confirmed',
                'Diproses': 'status-confirmed',
                'Dikirim': 'status-shipped',
                'Selesai': 'status-completed',
                'Dibatalkan': 'status-cancelled'
            };
            return statusMap[status] || 'status-pending';
        }

        function formatCurrency(value) {
            return new Intl.NumberFormat('id-ID').format(value);
        }

        // Load orders on page load
        document.addEventListener('DOMContentLoaded', loadOrders);
    </script>
</body>
</html>
