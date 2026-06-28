import '../commentum_config.dart';
import '../models/comment.dart';
import '../models/error.dart';
import '../models/response.dart';
import '../network/commentum_http_client.dart';
import 'auth_manager.dart';

/// Manages comment and reply creation, listing, updating, and moderation deletion.
class CommentumCommentManager {
  final CommentumConfig config;
  final CommentumHttpClient _network;
  final CommentumAuthManager _auth;

  CommentumCommentManager({
    required this.config,
    required CommentumHttpClient network,
    required CommentumAuthManager auth,
  })  : _network = network,
        _auth = auth;

  /// Creates a new root-level comment on a media item.
  ///
  /// * [mediaId]: Unique ID of the media in the external provider database.
  /// * [mediaProvider]: Source database identifier (e.g., 'mal', 'anilist').
  /// * [content]: The comment text body. Must be between 1 and 500 characters.
  ///
  /// Throws [CommentumValidationException] if content length is invalid.
  /// Throws [CommentumAuthException] if user is not logged in.
  Future<Comment> createComment({
    required String mediaId,
    required String mediaProvider,
    required String content,
    int? episodeNumber,
  }) async {
    _validateContent(content);
    _auth.isLoggedIn ? null : _throwAuth();

    final body = {
      'media_id': mediaId,
      'media_provider': mediaProvider,
      'content': content,
      'client': config.appClient,
    };
    if (episodeNumber != null) {
      body['episode_number'] = '$episodeNumber';
    }

    final data = await _network.request(
      '/posts',
      method: 'POST',
      body: body,
    );
    return Comment.fromJson(data['post']);
  }

  /// Creates a reply to an existing parent comment or reply.
  ///
  /// * [parentId]: ID of the comment being replied to.
  /// * [content]: The reply text body. Must be between 1 and 500 characters.
  Future<Comment> createReply({
    required String parentId,
    required String content,
  }) async {
    _validateContent(content);
    _auth.isLoggedIn ? null : _throwAuth();

    final data = await _network.request(
      '/posts',
      method: 'POST',
      body: {
        'parent_id': parentId,
        'content': content,
        'client': config.appClient,
      },
    );
    return Comment.fromJson(data['post']);
  }

  /// Retrieves a paginated list of top-level comments for [mediaId].
  ///
  /// * [limit]: Maximum number of items to return (default: 20).
  /// * [cursor]: Pagination cursor obtained from a previous response.
  /// * [episodeNumber]: Optional episode number filter.
  Future<CommentumResponse> listComments({
    required String mediaId,
    int limit = 20,
    String? cursor,
    int? episodeNumber,
  }) async {
    final params = {'media_id': mediaId, 'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;
    if (episodeNumber != null) params['episode_number'] = episodeNumber.toString();

    final data = await _network.request('/posts', params: params);
    return CommentumResponse.fromJson(data, isReply: false);
  }

  /// Retrieves a paginated list of replies under a root comment.
  ///
  /// * [rootId]: ID of the top-level ancestor root comment.
  /// * [parentId]: Optional filter for direct parent ID.
  /// * [limit]: Maximum items per page (default: 20).
  /// * [cursor]: Pagination cursor obtained from previous response.
  Future<CommentumResponse> listReplies({
    required String rootId,
    String? parentId,
    int limit = 20,
    String? cursor,
  }) async {
    final params = {'root_id': rootId, 'limit': limit.toString()};
    if (parentId != null) params['parent_id'] = parentId;
    if (cursor != null) params['cursor'] = cursor;

    final data = await _network.request('/posts', params: params);
    return CommentumResponse.fromJson(data, isReply: true);
  }

  /// Updates the text content of an existing comment authored by the current user.
  ///
  /// * [commentId]: Unique identifier of the target comment.
  /// * [content]: The updated text body (1 to 500 characters).
  Future<Comment> updateComment({
    required String commentId,
    required String content,
  }) async {
    _validateContent(content);
    _auth.isLoggedIn ? null : _throwAuth();

    final data = await _network.request(
      '/posts',
      method: 'PATCH',
      body: {'id': commentId, 'content': content},
    );
    return Comment.fromJson(data['post']);
  }

  /// Permanently deletes a comment or reply by its [commentId].
  Future<void> deleteComment({required String commentId}) async {
    _auth.isLoggedIn ? null : _throwAuth();
    await _network.request('/posts?id=$commentId', method: 'DELETE');
  }

  void _validateContent(String content) {
    if (content.trim().isEmpty) {
      throw const CommentumValidationException(
          'Comment content cannot be empty.');
    }
    if (content.length > 500) {
      throw const CommentumValidationException(
          'Comment content exceeds maximum limit of 500 characters.');
    }
  }

  void _throwAuth() {
    throw const CommentumAuthException(
      'Authentication required to post or edit comments.',
    );
  }
}
