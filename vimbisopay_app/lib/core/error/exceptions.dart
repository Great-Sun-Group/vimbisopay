class RateLimitException implements Exception {
  final String message;
  RateLimitException([this.message = 'Too many requests, please try again later']);
}
