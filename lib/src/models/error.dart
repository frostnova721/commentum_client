/// Base class for all exceptions thrown by [CommentumClient].
class CommentumException implements Exception {
  final String message;
  final int? statusCode;

  const CommentumException(this.message, [this.statusCode]);

  @override
  String toString() {
    if (statusCode != null) {
      return 'CommentumException [$statusCode]: $message';
    }
    return 'CommentumException: $message';
  }
}

/// Backward compatible error class alias.
class CommentumError extends CommentumException {
  const CommentumError(String message, [int? statusCode])
      : super(message, statusCode);
}

/// Thrown when an authentication error occurs (e.g., missing token, expired session, 401 response).
class CommentumAuthException extends CommentumException {
  const CommentumAuthException(String message, [int? statusCode = 401])
      : super(message, statusCode);
}

/// Thrown when local validation fails before sending a request (e.g., character limit exceeded).
class CommentumValidationException extends CommentumException {
  const CommentumValidationException(String message, [int? statusCode = 400])
      : super(message, statusCode);
}

/// Thrown when a network communication issue occurs (e.g., SocketException, connection timeout).
class CommentumNetworkException extends CommentumException {
  const CommentumNetworkException(String message) : super(message, 0);
}

/// Thrown when the Commentum API server returns an error HTTP status code (4xx, 5xx).
class CommentumServerException extends CommentumException {
  const CommentumServerException(String message, int statusCode)
      : super(message, statusCode);
}