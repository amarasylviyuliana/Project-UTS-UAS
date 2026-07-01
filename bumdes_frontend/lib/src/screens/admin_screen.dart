

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminStoreApprovalPage extends StatefulWidget {
  const AdminStoreApprovalPage({Key? key}) : super(key: key);

  @override
  State<AdminStoreApprovalPage> createState() => _AdminStoreApprovalPageState();
}

class _AdminStoreApprovalPageState extends State<AdminStoreApprovalPage> {
  // Ganti dengan URL API kamu
  static const String baseUrl = 'http://YOUR_API_URL';

  List<dynamic> _pendingStores = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPendingStores();
  }

  // Ambil token dari SharedPreferences atau storage kamu
  Future<String?> _getToken() async {
    // Sesuaikan dengan cara project kamu menyimpan token
    // Contoh: return SharedPreferences.getInstance().then((p) => p.getString('token'));
    return null; // ganti ini
  }

  // ============================================================
  // GET /admin/store-approvals — ambil daftar toko pending
  // ============================================================
  Future<void> _fetchPendingStores() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/admin/store-approvals'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Sesuaikan key 'data' dengan response backend Laravel kamu
          _pendingStores = data['data'] ?? data ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data toko';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // POST /admin/store-approvals/{id}/approve — setujui toko
  // ============================================================
  Future<void> _approveStore(int storeId, String storeName) async {
    final confirm = await _showConfirmDialog(
      'Setujui Toko',
      'Apakah kamu yakin ingin menyetujui toko "$storeName"?',
      confirmLabel: 'Setujui',
      confirmColor: Colors.green,
    );
    if (!confirm) return;

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/store-approvals/$storeId/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toko "$storeName" berhasil disetujui'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchPendingStores(); // refresh list
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Gagal menyetujui toko'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // POST /admin/store-approvals/{id}/reject — tolak toko
  // ============================================================
  Future<void> _rejectStore(int storeId, String storeName) async {
    // Minta alasan penolakan
    final reason = await _showRejectDialog(storeName);
    if (reason == null) return; // user batal

    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/admin/store-approvals/$storeId/reject'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Toko "$storeName" ditolak'),
            backgroundColor: Colors.orange,
          ),
        );
        _fetchPendingStores();
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Gagal menolak toko'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ============================================================
  // DIALOG KONFIRMASI
  // ============================================================
  Future<bool> _showConfirmDialog(
    String title,
    String message, {
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(confirmLabel, style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ============================================================
  // DIALOG ALASAN PENOLAKAN
  // ============================================================
  Future<String?> _showRejectDialog(String storeName) async {
    final controller = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tolak Toko'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alasan penolakan toko "$storeName":'),
            SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Tulis alasan penolakan...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Alasan tidak boleh kosong')),
                );
                return;
              }
              Navigator.pop(ctx, controller.text.trim());
            },
            child: Text('Tolak', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Persetujuan Toko BUMDes'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _fetchPendingStores,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPendingStores,
              child: Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    if (_pendingStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Tidak ada toko yang menunggu persetujuan',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPendingStores,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: _pendingStores.length,
        separatorBuilder: (_, __) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final store = _pendingStores[index];
          return _buildStoreCard(store);
        },
      ),
    );
  }

  Widget _buildStoreCard(Map<String, dynamic> store) {
    // Sesuaikan key dengan response backend kamu
    final int storeId = store['id'] ?? store['store_id'] ?? 0;
    final String storeName = store['store_name'] ?? store['name'] ?? 'Tanpa Nama';
    final String ownerName = store['owner_name'] ?? store['user']?['name'] ?? '-';
    final String ownerEmail = store['owner_email'] ?? store['user']?['email'] ?? '-';
    final String address = store['address'] ?? store['store_address'] ?? '-';
    final String submittedAt = store['created_at'] ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: nama toko + badge status
            Row(
              children: [
                Expanded(
                  child: Text(
                    storeName,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Menunggu',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 20),
            // Info toko
            _infoRow(Icons.person, 'Pemilik', ownerName),
            SizedBox(height: 6),
            _infoRow(Icons.email, 'Email', ownerEmail),
            SizedBox(height: 6),
            _infoRow(Icons.location_on, 'Alamat', address),
            if (submittedAt.isNotEmpty) ...[
              SizedBox(height: 6),
              _infoRow(Icons.access_time, 'Didaftarkan', submittedAt.substring(0, 10)),
            ],
            SizedBox(height: 16),
            // Tombol Setujui & Tolak
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectStore(storeId, storeName),
                    icon: Icon(Icons.close, color: Colors.red),
                    label: Text('Tolak', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveStore(storeId, storeName),
                    icon: Icon(Icons.check, color: Colors.white),
                    label: Text('Setujui', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}