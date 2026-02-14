class CommentumError implements Exception {
  final String message;
  final int status;
  CommentumError(this.message, this.status);
  @override
  String toString() => 'CommentumError: $message (Status: $status)';
}