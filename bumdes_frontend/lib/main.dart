import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'src/app.dart';
export 'src/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  runApp(const BumdesApp());
}
 