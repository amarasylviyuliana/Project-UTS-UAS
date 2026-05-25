import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config.dart';
import '../models/order_model.dart';

class PaymentScreen extends StatefulWidget {
  static const routeName = '/payment';
  final OrderModel order;

  const PaymentScreen({super.key, required this.order});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isUploading = false;
  bool _proofUploaded = false;
  String? _uploadedFileName;
  Uint8List? _pickedFileBytes;

  void _uploadPaymentProof() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Sumber Bukti Pembayaran'),
        content: const Text('Ambil foto dari mana?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Text('Galeri Foto'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Text('Kamera'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isUploading = true;
      });

final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (picked == null) {
        setState(() => _isUploading = false);
        return;
      }
      _pickedFileBytes = await picked.readAsBytes();
      _uploadedFileName = picked.name.isNotEmpty ? picked.name : picked.path.split('/').last;

        // Upload to backend
        await _uploadProofToServer();
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memilih file: $e')));
      }
    }
  }

  Future<void> _uploadProofToServer() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated || auth.token == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silakan login terlebih dahulu')));
      return;
    }

    if (_pickedFileBytes == null) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada file yang dipilih')));
      return;
    }

    try {
      final uri = Uri.parse(apiUrl('/orders/${widget.order.id}/payment-proof'));
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${auth.token}';
      request.files.add(http.MultipartFile.fromBytes('proof', _pickedFileBytes!, filename: _uploadedFileName ?? 'proof.jpg'));

      final streamed = await request.send();
      final respStr = await streamed.stream.bytesToString();
      setState(() => _isUploading = false);
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        // success
        setState(() {
          _proofUploaded = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti pembayaran berhasil diunggah')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunggah bukti: $respStr')));
        }
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengunggah: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pembayaran'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informasi Pembayaran
              Card(
                elevation: 2,
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('No. Pesanan:'),
                          Text(
                            widget.order.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Pembayaran:'),
                          Text(
                            'Rp ${widget.order.total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Rekening Tujuan
              const Text(
                'Rekening Tujuan Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Bank:'),
                          Text('BCA', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('No. Rekening:'),
                          GestureDetector(
                            onLongPress: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nomor rekening disalin')),
                              );
                            },
                            child: const Text('1234567890', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Atas Nama:'),
                          Text('BUMDes Sukamaju', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          border: Border.all(color: Colors.yellow[700]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info, color: Colors.yellow[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pastikan nominal transfer sesuai: Rp ${widget.order.total.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: Colors.yellow[900]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Upload Bukti Pembayaran
              const Text(
                'Unggah Bukti Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (!_proofUploaded)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _uploadPaymentProof,
                    icon: _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isUploading ? 'Mengunggah...' : 'Pilih & Unggah Bukti Pembayaran'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    border: Border.all(color: Colors.green),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bukti pembayaran berhasil diunggah',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _uploadedFileName ?? 'File uploaded',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _proofUploaded = false;
                            _uploadedFileName = null;
                          });
                        },
                        child: Icon(Icons.close, color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // Info Validasi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Persyaratan Bukti Pembayaran:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Format: JPG atau PNG\n• Ukuran maks: 5 MB\n• Foto harus jelas menampilkan bukti transfer\n• Terdapat bukti nominal dan tanggal transfer',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Konfirmasi
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _proofUploaded
                      ? () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Konfirmasi Pembayaran'),
                              content: const Text('Bukti pembayaran telah diunggah. Status pesanan akan berubah menjadi "Menunggu Konfirmasi Penjual". Penjual akan mengkonfirmasi pembayaran Anda dalam waktu 1x24 jam.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Tutup'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Bukti pembayaran berhasil dikirim. Tunggu konfirmasi penjual.'),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Selesai'),
                                ),
                              ],
                            ),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Konfirmasi & Kirim', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
