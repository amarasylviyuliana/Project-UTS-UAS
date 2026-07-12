import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'src/app.dart';
import 'src/services/midtrans_service.dart';
export 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // FIX: bersihkan sisa script/overlay Midtrans (snap.js) yang mungkin
  // masih nyantol di DOM dari sesi sebelumnya (mis. dari hot restart saat
  // development, di mana DOM browser TIDAK ikut ter-reset walau kode Dart
  // di-restart). Overlay yang tertinggal ini transparan tapi tetap
  // mengunci klik & scroll di seluruh app. Aman dipanggil walau tidak ada
  // sisa apa pun (no-op).
  MidtransService.teardownWeb();

  runApp(const BumdesApp());
}