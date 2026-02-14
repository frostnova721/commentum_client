import 'commentum_config.dart';

/// Abstract interface for token storage.
abstract class CommentumStorage {
  Future<void> saveToken(CommentumProvider provider, String token);
  Future<String?> getToken(CommentumProvider provider);
  Future<void> deleteToken(CommentumProvider provider);
  Future<void> clearAll();
}
