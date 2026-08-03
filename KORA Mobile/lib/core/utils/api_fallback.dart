/// Tries [request] with each URL in [urls] in sequence.
/// On exception waits [delay] before moving to the next URL.
/// Throws the last error if all URLs fail.
Future<T> tryWithFallbacks<T>(
  List<String> urls,
  Future<T> Function(String url) request, {
  Duration delay = const Duration(seconds: 1),
}) async {
  assert(urls.isNotEmpty, 'urls must not be empty');
  Object? lastError;
  StackTrace? lastStack;
  for (int i = 0; i < urls.length; i++) {
    try {
      return await request(urls[i]);
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      if (i < urls.length - 1) await Future.delayed(delay);
    }
  }
  Error.throwWithStackTrace(lastError!, lastStack!);
}
