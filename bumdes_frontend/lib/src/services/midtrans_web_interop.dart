// Conditional export: use web implementation when `dart:js` is available,
// otherwise use a stub that safely runs on non-web platforms (VM/test).
export 'midtrans_web_interop_stub.dart'
  if (dart.library.js) 'midtrans_web_interop_web.dart';
