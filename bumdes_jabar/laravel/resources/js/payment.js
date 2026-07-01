import './bootstrap';

const apiBase = window.apiBase || window.location.origin + '/api';
let authToken = localStorage.getItem('auth_token') || null;

let paymentMessage;
let orderIdInput;
let paymentDetails;
let detailOrderNumber;
let detailTotalAmount;
let detailStatus;
let detailBankName;
let detailAccountNumber;
let detailAccountHolder;
let detailProof;
let proofImageInput;
let loadPaymentButton;
let uploadProofButton;

function initPaymentPage() {
    paymentMessage = document.getElementById('paymentMessage');
    orderIdInput = document.getElementById('orderId');
    paymentDetails = document.getElementById('paymentDetails');
    detailOrderNumber = document.getElementById('detailOrderNumber');
    detailTotalAmount = document.getElementById('detailTotalAmount');
    detailStatus = document.getElementById('detailStatus');
    detailBankName = document.getElementById('detailBankName');
    detailAccountNumber = document.getElementById('detailAccountNumber');
    detailAccountHolder = document.getElementById('detailAccountHolder');
    detailProof = document.getElementById('detailProof');
    proofImageInput = document.getElementById('proofImage');
    loadPaymentButton = document.getElementById('loadPaymentButton');
    uploadProofButton = document.getElementById('uploadProofButton');

    loadPaymentButton?.addEventListener('click', loadPaymentDetails);
    uploadProofButton?.addEventListener('click', uploadProof);

    const prefillOrderId = getQueryParam('order_id');
    if (prefillOrderId) {
        orderIdInput.value = prefillOrderId;
        loadPaymentDetails();
    }
}

document.addEventListener('DOMContentLoaded', initPaymentPage);

function getQueryParam(name) {
    const params = new URLSearchParams(window.location.search);
    return params.get(name);
}

function showMessage(message, type = 'success') {
    if (!paymentMessage) return;
    paymentMessage.innerHTML = `<div class="message ${type}">${message}</div>`;
}

function clearMessage() {
    if (!paymentMessage) return;
    paymentMessage.innerHTML = '';
}

function getHeaders(isForm = false) {
    const headers = {};

    if (!isForm) {
        headers['Content-Type'] = 'application/json';
    }

    if (authToken) {
        headers['Authorization'] = `Bearer ${authToken}`;
    }

    return headers;
}

function formatCurrency(value) {
    return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR' }).format(value);
}

async function loadPaymentDetails() {
    clearMessage();

    if (!authToken) {
        showMessage('Silakan login terlebih dahulu untuk melihat detail pembayaran.', 'error');
        return;
    }

    const orderId = orderIdInput?.value?.trim();
    if (!orderId) {
        showMessage('Masukkan ID pesanan terlebih dahulu.', 'error');
        return;
    }

    try {
        const response = await axios.get(`${apiBase}/payments/${orderId}`, {
            headers: getHeaders(),
            validateStatus: () => true,
        });

        if (response.status !== 200) {
            showMessage(response.data?.message || `Gagal memuat detail pesanan (${response.status})`, 'error');
            paymentDetails.style.display = 'none';
            return;
        }

        const data = response.data.data;
        paymentDetails.style.display = 'block';
        detailOrderNumber.textContent = data.order_number;
        detailTotalAmount.textContent = formatCurrency(data.total_amount);
        detailStatus.textContent = data.payment_status;
        detailBankName.textContent = data.bank_name;
        detailAccountNumber.textContent = data.bank_account_number;
        detailAccountHolder.textContent = data.bank_account_holder;
        detailProof.textContent = data.proof_image_url ? 'Sudah ada bukti transfer' : 'Belum ada bukti transfer';

        showMessage('Detail pembayaran berhasil dimuat.', 'success');
    } catch (error) {
        console.error(error);
        showMessage('Terjadi kesalahan saat memuat detail pembayaran.', 'error');
        paymentDetails.style.display = 'none';
    }
}

async function uploadProof() {
    clearMessage();

    if (!authToken) {
        showMessage('Silakan login terlebih dahulu untuk mengunggah bukti transfer.', 'error');
        return;
    }

    const orderId = orderIdInput?.value?.trim();
    const file = proofImageInput?.files?.[0];

    if (!orderId) {
        showMessage('Masukkan ID pesanan terlebih dahulu.', 'error');
        return;
    }

    if (!file) {
        showMessage('Pilih file bukti transfer terlebih dahulu.', 'error');
        return;
    }

    const formData = new FormData();
    formData.append('proof_image', file);

    try {
        const response = await axios.post(`${apiBase}/payments/${orderId}/upload-proof`, formData, {
            headers: getHeaders(true),
            validateStatus: () => true,
        });

        if (response.status !== 200) {
            showMessage(response.data?.message || `Gagal unggah bukti (${response.status})`, 'error');
            return;
        }

        showMessage('Bukti transfer berhasil diunggah. Tunggu konfirmasi penjual.', 'success');
        loadPaymentDetails();
    } catch (error) {
        console.error(error);
        showMessage('Terjadi kesalahan saat mengunggah bukti transfer.', 'error');
    }
}
