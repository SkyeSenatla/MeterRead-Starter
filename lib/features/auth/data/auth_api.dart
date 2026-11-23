import 'package:dio/dio.dart';
import 'package:meterread/core/network/failure_from.dart';
import 'package:meterread/features/auth/domain/reader.dart';

/// What sign-in and refresh send back.
typedef TokenPair = ({
  String accessToken,
  String refreshToken,
  DateTime expiresAt,
  Reader reader,
});

final class AuthApi {
  /// Creates the API over [_dio].
  const new(this._dio);

  final Dio _dio;

  /// POST /auth/sign-in.
  Future<TokenPair> signIn(String email, String password) =>
      withFailures(() async {
        final response = await _dio.post<Map<String, Object?>>(
          '/auth/sign-in',
          data: {'email': email, 'password': password},
        );
        return _pair(response.data!);
      });

  Future<TokenPair> refresh(String refreshToken) => withFailures(() async {
    final response = await _dio.post<Map<String, Object?>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    return _pair(response.data!);
  });

  /// POST /auth/sign-out: the API forgets the session.
  Future<void> signOut(String refreshToken) => withFailures(() async {
    await _dio.post<void>(
      '/auth/sign-out',
      data: {'refreshToken': refreshToken},
    );
  });

  static TokenPair _pair(Map<String, Object?> json) => (
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    expiresAt: DateTime.now().add(Duration(seconds: json['expiresIn']! as int)),
    reader: Reader(
      name: json['readerName']! as String,
      email: json['email']! as String,
    ),
  );
}
