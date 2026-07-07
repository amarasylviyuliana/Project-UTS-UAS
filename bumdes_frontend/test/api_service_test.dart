import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bumdes_frontend/src/services/api_service.dart';

void main() {
  test(
    'ApiService converts invalid JSON responses into ApiException',
    () async {
      final client = MockClient((request) async {
        return http.Response(
          'not-json',
          500,
          headers: {'content-type': 'text/html'},
        );
      });

      final service = ApiService(client: client);

      await expectLater(
        service.post('/auth/login', {
          'email': 'x@test.com',
          'password': 'secret',
        }),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test('ApiService sends AJAX headers for login requests', () async {
    final client = MockClient((request) async {
      expect(request.headers['Content-Type'], contains('application/json'));
      expect(request.headers['Accept'], contains('application/json'));
      expect(request.headers['X-Requested-With'], 'XMLHttpRequest');

      return http.Response(
        jsonEncode({'message': 'ok'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final service = ApiService(client: client);
    final response = await service.post('/auth/login', {
      'email': 'x@test.com',
      'password': 'secret',
    });

    expect(response['message'], 'ok');
  });
}
