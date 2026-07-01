# bumdes_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Midtrans payment integration

1. Install dependencies:

```bash
cd bumdes_frontend
flutter pub get
```

2. Usage:

- Checkout in-app will call backend `POST /api/checkout` and receive `snap_token`.
- If `snap_token` is present, app opens `MidtransPaymentScreen` and triggers Snap payment.

3. Notes:

- Make sure `MIDTRANS_CLIENT_KEY` is set in backend `.env` and backend server is reachable by the app.
- For local Midtrans webhook testing, use a public tunnel like `ngrok`.
