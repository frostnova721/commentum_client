import '../models/error.dart';
import '../network/commentum_http_client.dart';
import 'auth_manager.dart';

/// Manages community interactions including upvoting, downvoting, and moderation reporting.
class CommentumInteractionManager {
  final CommentumHttpClient _network;
  final CommentumAuthManager _auth;

  CommentumInteractionManager({
    required CommentumHttpClient network,
    required CommentumAuthManager auth,
  })  : _network = network,
        _auth = auth;

  /// Casts or toggles a vote on a comment or reply.
  ///
  /// * [commentId]: Target comment identifier.
  /// * [voteType]: `1` for upvote, `-1` for downvote. Sending the same vote twice removes it.
  Future<void> voteComment({
    required String commentId,
    required int voteType,
  }) async {
    _auth.isLoggedIn ? null : _throwAuth();
    if (voteType != 1 && voteType != -1) {
      throw const CommentumValidationException(
          'Invalid voteType. Must be 1 (up) or -1 (down). Sending the same vote twice removes it.');
    }

    await _network.request(
      '/votes',
      method: 'POST',
      body: {'post_id': commentId, 'vote_type': voteType},
    );
  }

  /// Convenience method to upvote a comment (+1). Sending twice toggles/removes upvote.
  Future<void> upvote({required String commentId}) =>
      voteComment(commentId: commentId, voteType: 1);

  /// Convenience method to downvote a comment (-1). Sending twice toggles/removes downvote.
  Future<void> downvote({required String commentId}) =>
      voteComment(commentId: commentId, voteType: -1);

  /// Reports a comment or reply to community moderators.
  ///
  /// * [commentId]: Target comment identifier.
  /// * [reason]: Explanation of the violation (e.g., 'Spam', 'Harassment', 'Spoiler').
  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    _auth.isLoggedIn ? null : _throwAuth();
    if (reason.trim().isEmpty) {
      throw const CommentumValidationException(
          'Report reason cannot be empty.');
    }

    await _network.request(
      '/reports',
      method: 'POST',
      body: {'post_id': commentId, 'reason': reason},
    );
  }

  void _throwAuth() {
    throw const CommentumAuthException(
      'Authentication required to vote or report comments.',
    );
  }
}
