import 'dart:io';
import 'package:http/http.dart' as http;

// Turns the failures that mean "the explorer could not be reached" into a stated reason
// rather than a raw socket error.
//
// Every explorer call goes through this, so "no internet" and "that explorer is down" read as
// the different problems they are — only one of them is the user's to fix.

// ─── Network-error guard ──────────────────────────────────────────────────────
// Wraps any async call; converts SocketException / ClientException into a
// friendly, user-readable Exception so the UI can show a clean message.
Future<T> guardNetwork<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on SocketException catch (e) {
    // errno 7 (Android ENOENT/host not found) and 11001 (Windows WSAHOST_NOT_FOUND)
    // mean DNS resolution failed — the explorer is down, NOT that there's no internet.
    final isDnsFail =
        e.osError?.errorCode == 7 || e.osError?.errorCode == 8 || e.osError?.errorCode == 11001;
    final msg = isDnsFail
        ? 'Explorer unavailable. The server could not be reached.'
        : 'No internet connection. Transaction history is unavailable.';
    throw Exception(msg);
  } on http.ClientException {
    throw Exception('No internet connection. Transaction history is unavailable.');
  }
}
