import './bootstrap';

const apiBase = window.apiBase || window.location.origin + '/api';
let authToken = localStorage.getItem('auth_token') || null;

let pageMessage;
let orderIdInput;
let loadButton;
let confirmButton;
let rejectButton;
let rejectReasonInput;
let paymentInfo;
let proofContainer;
let proofImage;

let currentOrderId = null;

function initPaymentReviewPage() {
    pageMessage = document.getElementById('pageMessage');
    orderIdInput = document.getElementById('orderId');
    loadButton = document.getElementById('loadButton');
    confirmButton = document.getElementById('confirmButton');
    rejectButton = document.getElementById('rejectButton');
    rejectReasonInput = document.getElementById('rejectReason');
    paymentInfo = document.getElementById('paymentInfo');
    proofContainer = document.getElementById('proofContainer');
    proofImage = document.getElementById('proofImage');

    loadButton?.addEventListener('click', loadPaymentProof);
    confirmButton?.addEventListener('click', confirmPayment);
    rejectButton?.addEventListener('click', rejectPayment);
}

document.addEventListener('DOMContentLoaded', initPaymentReviewPage);

function showMessage(message, type = 'success') {
    if (!pageMessage) return;
    pageMessage.innerHTML = `<div class="message ${type}">${message}</div>`;
}

function clearMessage() {
    if (!pageMessage) return;
    pageMessage.innerHTML = '';
}

function getHeaders() {
    const headers = { 'Content-Type': 'application/json' };
    if (authToken) headers['Authorization'] = `Bearer ${authToken}`;
    return headers;
}

function displayPaymentData(data) {
    const rows = [
        { label: 'Nomor Pesanan', value: data.order_number },
        { label: 'Status Pembayaran', value: data.payment_status },
        { label: 'Jumlah', value: formatCurrency(data.total_amount) },
        { label: 'Bank', value: data.bank_name },
        { label: 'No. Rekening', value: data.bank_account_number },
        { label: 'Pemilik Rekening', value: data.bank_account_holder },
    ];

    paymentInfo.innerHTML = rows.map(row => `
        <div class="info-row">
            <div class="info-label">${row.label}</div>
            <div class="info-value">${row.value || '-'}</div>
        </div>
    `).join('');

    if (data.proof_image_url) {
        proofContainer.style.display = 'block';
        proofImage.src = data.proof_image_url;
    } else {
        proofContainer.style.display = 'none';
    }
}

function formatCurrency(amount) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' }).format(amount);
}

async function loadPaymentProof() {
    clearMessage();

    if (!authToken) {
        showMessage('Silakan login terlebih dahulu sebagai seller.', 'error');
        return;
    }

    const orderId = orderIdInput?.value?.trim();
    if (!orderId) {
        showMessage('Masukkan ID pesanan terlebih dahulu.', 'error');
        return;
    }

    try {
        const response = await axios.get(`${apiBase}/payments/${orderId}/proof`, {
            headers: getHeaders(),
            validateStatus: () => true,
        });

        if (response.status !== 200) {
            showMessage(response.data?.message || `Gagal muat bukti (${response.status})`, 'error');
            paymentInfo.innerHTML = '';
            proofContainer.style.display = 'none';
            currentOrderId = null;
            return;
        }

        currentOrderId = orderId;
        displayPaymentData(response.data.data);
        showMessage('Bukti pembayaran berhasil dimuat.', 'success');
    } catch (error) {
        console.error(error);
        showMessage('Terjadi kesalahan saat memuat bukti pembayaran.', 'error');
    }
}

async function confirmPayment() {
    clearMessage();

    if (!authToken) {
        showMessage('Silakan login sebagai seller terlebih dahulu.', 'error');
        return;
    }

    if (!currentOrderId) {
        showMessage('Muat pesanan terlebih dahulu sebelum mengonfirmasi.', 'error');
        return;
    }

    try {
        const response = await axios.post(`${apiBase}/payments/${currentOrderId}/confirm`, {}, {
            headers: getHeaders(),
            validateStatus: () => true,
        });

        if (response.status !== 200) {
            showMessage(response.data?.message || `Gagal konfirmasi (${response.status})`, 'error');
            return;
        }

        showMessage('Pembayaran berhasil dikonfirmasi.', 'success');
        loadPaymentProof();
    } catch (error) {
        console.error(error);
        showMessage('Terjadi kesalahan saat mengonfirmasi pembayaran.', 'error');
    }
}

async function rejectPayment() {
    clearMessage();

    if (!authToken) {
        showMessage('Silakan login sebagai seller terlebih dahulu.', 'error');
        return;
    }

    if (!currentOrderId) {
        showMessage('Muat pesanan terlebih dahulu sebelum menolak pembayaran.', 'error');
        return;
    }

    const reason = rejectReasonInput?.value?.trim();
    if (!reason) {
        showMessage('Masukkan alasan penolakan pembayaran.', 'error');
        return;
    }

    try {
        const response = await axios.post(`${apiBase}/payments/${currentOrderId}/reject`, { reason }, {
            headers: getHeaders(),
            validateStatus: () => true,
        });

        if (response.status !== 200) {
            showMessage(response.data?.message || `Gagal tolak pembayaran (${response.status})`, 'error');
            return;
        }

        showMessage('Pembayaran berhasil ditolak dan status kembali ke Menunggu Pembayaran.', 'success');
        loadPaymentProof();
    } catch (error) {
        console.error(error);
        showMessage('Terjadi kesalahan saat menolak pembayaran.', 'error');
    }
}
