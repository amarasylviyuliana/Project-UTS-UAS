// Conditional export: use the web implementation (dart:html) only when
// compiling for the web. On Android/iOS/VM/tests, the stub is used instead,
// so dart:html is never referenced outside of web builds.
export 'midtrans_snap_loader_stub.dart'
    if (dart.library.html) 'midtrans_snap_loader_web.dart';