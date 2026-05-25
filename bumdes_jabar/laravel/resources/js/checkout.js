import './bootstrap';

const apiBase = window.apiBase || window.location.origin + '/api';
let authToken = localStorage.getItem('auth_token') || null;

let loginMessage;
let cartMessage;
let checkoutMessage;
let cartList;
let cartTotal;
let tokenValue;
let loginButton;
let addCartButton;
let refreshCartButton;
let checkoutButton;
let productSelect;

function initCheckoutPage() {
    loginMessage = document.getElementById('loginMessage');
    cartMessage = document.getElementById('cartMessage');
    checkoutMessage = document.getElementById('checkoutMessage');
    cartList = document.getElementById('cartList');
    cartTotal = document.getElementById('cartTotal');
    tokenValue = document.getElementById('tokenValue');
    loginButton = document.getElementById('loginButton');
    addCartButton = document.getElementById('addCartButton');
    refreshCartButton = document.getElementById('refreshCartButton');
    checkoutButton = document.getElementById('checkoutButton');
    productSelect = document.getElementById('productSelect');

    if (authToken && tokenValue) {
        tokenValue.textContent = authToken;
    }

    loginButton?.addEventListener('click', login);
    addCartButton?.addEventListener('click', addCart);
    refreshCartButton?.addEventListener('click', refreshCart);
    checkoutButton?.addEventListener('click', checkout);

    refreshCart();
    loadProducts();
}

document.addEventListener('DOMContentLoaded', initCheckoutPage);

function showMessage(container, message, type = 'success') {
    if (!container) {
        console.warn('Unable to show message, container missing:', message);
        return;
    }
    container.innerHTML = `<div class="message ${type}">${message}</div>`;
}

function clearMessages() {
    loginMessage.innerHTML = '';
    cartMessage.innerHTML = '';
    checkoutMessage.innerHTML = '';
}

function getHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }
    return headers;
}

async function login() {
    clearMessages();
    const email = document.getElementById('loginEmail').value.trim();
    const password = document.getElementById('loginPassword').value;

    if (!email || !password) {
        showMessage(loginMessage, 'Email dan password harus diisi', 'error');
        return;
    }

    try {
        const response = await axios.post(`${apiBase}/auth/login`, { email, password }, { headers: getHeaders() });
        authToken = response.data.token;
        localStorage.setItem('auth_token', authToken);
        tokenValue.textContent = authToken;
        showMessage(loginMessage, 'Login berhasil', 'success');
        refreshCart();
    } catch (error) {
        showMessage(loginMessage, error.response?.data?.message || 'Login gagal', 'error');
    }
}

async function addCart() {
    clearMessages();
    const productId = parseInt((productSelect && productSelect.value) ? productSelect.value : document.getElementById('productId')?.value, 10);
    const quantity = parseInt(document.getElementById('productQty').value, 10);

    if (!authToken) {
        showMessage(cartMessage, 'Login terlebih dahulu sebelum menambah ke keranjang', 'error');
        return;
    }
    if (!productId || quantity < 1) {
        showMessage(cartMessage, 'Product ID dan quantity harus valid', 'error');
        return;
    }

    try {
        await axios.post(`${apiBase}/cart/add`, { product_id: productId, quantity }, { headers: getHeaders() });
        showMessage(cartMessage, 'Produk berhasil ditambahkan ke keranjang', 'success');
        refreshCart();
    } catch (error) {
        showMessage(cartMessage, error.response?.data?.message || 'Gagal menambah produk ke keranjang', 'error');
    }
}

async function refreshCart() {
    clearMessages();
    if (!authToken) {
        cartList.innerHTML = '<li class="cart-item">Silakan login dulu untuk melihat keranjang</li>';
        cartTotal.textContent = '0';
        return;
    }

    try {
        const response = await axios.get(`${apiBase}/cart`, { headers: getHeaders() });
        const items = response.data.items || [];
        cartList.innerHTML = items.length ? items.map(item => `
            <li class="cart-item">
                <strong>${item.product.name}</strong> &times; ${item.quantity}<br>
                Harga: Rp ${item.product.price} | Subtotal: Rp ${item.product.price * item.quantity}
            </li>
        `).join('') : '<li class="cart-item">Keranjang kosong</li>';
        cartTotal.textContent = `Rp ${response.data.total ?? 0}`;
    } catch (error) {
        cartList.innerHTML = '<li class="cart-item">Tidak dapat memuat keranjang</li>';
        cartTotal.textContent = '0';
        showMessage(cartMessage, error.response?.data?.message || 'Gagal memuat keranjang', 'error');
    }
}

async function checkout() {
    clearMessages();
    if (!authToken) {
        showMessage(checkoutMessage, 'Login terlebih dahulu sebelum checkout', 'error');
        return;
    }

    const payload = {
        recipient_name: document.getElementById('recipientName').value.trim(),
        recipient_phone: document.getElementById('recipientPhone').value.trim(),
        recipient_address: document.getElementById('recipientAddress').value.trim(),
        notes: document.getElementById('notes').value.trim(),
    };

    if (!payload.recipient_name || !payload.recipient_address) {
        showMessage(checkoutMessage, 'Nama penerima dan alamat pengiriman wajib diisi', 'error');
        return;
    }

    try {
        const response = await axios.post(`${apiBase}/orders`, payload, { headers: getHeaders() });
        showMessage(checkoutMessage, 'Checkout berhasil! Pesanan dibuat.', 'success');
        document.getElementById('orderResult').innerHTML = `Order ID: ${response.data.data.id}, nomor: ${response.data.data.order_number} <br /><a href="/payment?order_id=${response.data.data.id}" style="display:inline-block;margin-top:10px;padding:8px 12px;border-radius:10px;background:#3d7d3f;color:#fff;text-decoration:none;">Bayar Sekarang</a>`;
        refreshCart();
    } catch (error) {
        showMessage(checkoutMessage, error.response?.data?.message || 'Checkout gagal', 'error');
        document.getElementById('orderResult').textContent = '';
    }
}

// Fetch products for dropdown
async function loadProducts() {
    try {
        const res = await axios.get(`${apiBase}/debug/products`);
        const products = res.data.data || [];
        if (productSelect) {
            productSelect.innerHTML = products.length ? products.map(p => `
                <option value="${p.id}">${p.id} — ${p.name} (${p.is_active ? 'Aktif' : 'Nonaktif'}) — Rp ${p.price}</option>
            `).join('') : '<option value="">Tidak ada produk</option>';
        }
    } catch (err) {
        if (productSelect) {
            productSelect.innerHTML = '<option value="">Gagal memuat produk</option>';
        }
    }
}
