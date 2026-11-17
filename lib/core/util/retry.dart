import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

typedef Sleeper = Future<void> Function(Duration);

/// Runs [action], retrying with exponential backoff while [retryIf] says the
/// failure is transient.
Future<T> withRetry<T>(
  Future<T> Function() action, {
  required bool Function(Object error) retryIf,
  int maxAttempts = 5,
  Duration baseDelay = const Duration(milliseconds: 500),
  Sleeper sleep = Future<void>.delayed,
  Random? random,
}) async {
  final rng = random ?? Random();
  for (var attempt = 1; ; attempt++) {
    try {
      return await action();
    } catch (e) {
      if (attempt >= maxAttempts || !retryIf(e)) rethrow;
      final backoff = baseDelay * pow(2, attempt - 1).toInt();
      await sleep(backoff + Duration(milliseconds: rng.nextInt(250)));
    }
  }
}

/// Carries the HTTP status of a failed Drive call.
class DriveApiException implements Exception {
  DriveApiException(this.status, this.message);

  final int status;
  final String message;

  bool get isNotFound => status == 404;

  @override
  String toString() => 'Drive error $status: $message';
}

/// Rate limits, server errors and dropped connections are worth retrying.
bool isTransient(Object error) {
  if (error is DriveApiException) {
    return error.status == 429 ||
        error.status >= 500 ||
        (error.status == 403 && error.message.contains('ateLimit'));
  }
  return error is SocketException ||
      error is TimeoutException ||
      error is HttpException ||
      error is http.ClientException;
}
