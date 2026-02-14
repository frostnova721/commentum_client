import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import './models/comment.dart';
import './models/error.dart';
import './models/user.dart';
import 'commentum_config.dart';
import 'commentum_storage.dart';

/// Client for interacting with the Commentum API.
///
/// Handles authentication state, token management, and all CRUD operations
/// for comments, replies, and votes across multiple providers (AniList, MAL, Simkl).
class CommentumClient {
  final CommentumConfig config;
  final CommentumStorage storage;
  final http.Client _httpClient;

  /// In-memory cache of JWTs to minimize async storage reads.
  final Map<CommentumProvider, String> _tokenCache = {};
  
  CommentumProvider? _activeProvider;

  /// Creates a new [CommentumClient] instance.
  ///
  /// * [config]: Configuration for base URL and timeouts.
  /// * [storage]: Persistence strategy for tokens (e.g., SecureStorage, Hive).
  /// * [httpClient]: Optional custom http client for testing or interception.
  CommentumClient({
    required this.config,
    required this.storage,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// Hydrates the client state by loading persisted tokens from [storage].
  ///
  /// Call this immediately after instantiating the client.
  Future<void> init() async {
    for (final provider in CommentumProvider.values) {
      final token = await storage.getToken(provider);
      if (token != null) {
        _tokenCache[provider] = token;
      }
    }
  }

  /// Sets the active provider context (e.g., [CommentumProvider.anilist]).
  ///
  /// Subsequent requests will use the cached token for this provider.
  void setActiveProvider(CommentumProvider? provider) {
    _activeProvider = provider;
  }

  /// The currently active authentication provider.
  CommentumProvider? get activeProvider => _activeProvider;

  /// Whether the [activeProvider] has a valid cached token.
  bool get isLoggedIn => 
      _activeProvider != null && _tokenCache.containsKey(_activeProvider);

  // ---------------------------------------------------------------------------
  // AUTHENTICATION
  // ---------------------------------------------------------------------------

  /// Exchanges a third-party [providerAccessToken] for a Commentum JWT.
  ///
  /// * [provider]: The identity provider (e.g., MAL, Simkl).
  /// * [providerAccessToken]: The access token received from the provider's OAuth flow.
  ///
  /// Automatically caches the resulting JWT and sets the provider as active.
  Future<void> login(CommentumProvider provider, String providerAccessToken) async {
    final data = await _request(
      '/auth',
      method: 'POST',
      body: {
        'provider': provider.apiValue,
        'access_token': providerAccessToken,
      },
      useAuth: false,
    );

    final jwt = data['token'];
    _tokenCache[provider] = jwt;
    await storage.saveToken(provider, jwt);
    
    setActiveProvider(provider);
  }

  /// Logs out the specified [provider] (or the currently active one).
  ///
  /// Clears the token from both memory and [storage].
  /// Attempts to notify the server to invalidate the session (best-effort).
  Future<void> logout([CommentumProvider? provider]) async {
    final targetProvider = provider ?? _activeProvider;
    if (targetProvider == null) return;

    try {
      if (_tokenCache.containsKey(targetProvider)) {
        final prevActive = _activeProvider;
        _activeProvider = targetProvider;
        await _request('/auth', method: 'DELETE');
        _activeProvider = prevActive;
      }
    } catch (_) {
      // Suppress network errors during logout to ensure local cleanup proceeds.
    }

    _tokenCache.remove(targetProvider);
    await storage.deleteToken(targetProvider);

    if (_activeProvider == targetProvider) {
      _activeProvider = null;
    }
  }

  /// Fetches the profile of the currently authenticated user.
  ///
  /// Throws [CommentumError] if not logged in.
  Future<User> getMe() async {
    final data = await _request('/me');
    return User.fromJson(data['user']);
  }

  // ---------------------------------------------------------------------------
  // COMMENTS & REPLIES
  // ---------------------------------------------------------------------------

  /// Creates a new root-level comment on a media item.
  ///
  /// * [mediaId]: The ID of the media (anime/manga) in the external database.
  /// * [content]: The text body of the comment.
  Future<Comment> createComment(String mediaId, String content) async {
    final data = await _request(
      '/posts',
      method: 'POST',
      body: {'media_id': mediaId, 'content': content},
    );
    return Comment.fromJson(data['post']);
  }

  /// Creates a reply to an existing comment.
  ///
  /// * [parentId]: The ID of the comment being replied to.
  /// * [content]: The text body of the reply.
  Future<Comment> createReply(String parentId, String content) async {
    final data = await _request(
      '/posts',
      method: 'POST',
      body: {'parent_id': parentId, 'content': content},
    );
    return Comment.fromJson(data['post']);
  }

  /// Retrieves a paginated list of root comments for [mediaId].
  ///
  /// * [limit]: Max items to return (default: 20).
  /// * [cursor]: Pagination cursor from a previous [PaginatedComments] result.
  Future<PaginatedComments> listComments(
    String mediaId, {
    int limit = 20,
    String? cursor,
  }) async {
    final params = {'media_id': mediaId, 'limit': limit.toString()};
    if (cursor != null) params['cursor'] = cursor;

    final data = await _request('/posts', params: params);
    return PaginatedComments.fromJson(data, isReply: false);
  }

  /// Retrieves a paginated list of replies.
  ///
  /// * [rootId]: The ID of the top-level ancestor comment.
  /// * [parentId]: (Optional) Filter by direct parent ID.
  Future<PaginatedComments> listReplies(
    String rootId, {
    int limit = 20,
    String? cursor,
    String? parentId,
  }) async {
    final params = {'root_id': rootId, 'limit': limit.toString()};
    if (parentId != null) params['parent_id'] = parentId;
    if (cursor != null) params['cursor'] = cursor;

    final data = await _request('/posts', params: params);
    return PaginatedComments.fromJson(data, isReply: true);
  }

  /// Updates the text content of a comment.
  ///
  /// * [commentId]: ID of the comment to edit.
  /// * [content]: The new text content.
  Future<Comment> updateComment(String commentId, String content) async {
    final data = await _request(
      '/posts',
      method: 'PATCH',
      body: {'id': commentId, 'content': content},
    );
    return Comment.fromJson(data['post']);
  }

  /// Deletes a comment by [commentId].
  ///
  /// This action is typically irreversible.
  Future<void> deleteComment(String commentId) async {
    await _request('/posts?id=$commentId', method: 'DELETE');
  }

  // ---------------------------------------------------------------------------
  // INTERACTION
  // ---------------------------------------------------------------------------

  /// Casts or updates a vote on a comment.
  ///
  /// * [commentId]: The target comment ID.
  /// * [voteType]: `1` (Upvote), `-1` (Downvote), or `0` (Remove vote).
  Future<void> voteComment(String commentId, int voteType) async {
    await _request(
      '/votes',
      method: 'POST',
      body: {'post_id': commentId, 'vote_type': voteType},
    );
  }

  /// Reports a comment for moderation.
  ///
  /// * [commentId]: The ID of the offending comment.
  /// * [reason]: A short string describing the violation (e.g. "Spam", "Spoiler").
  Future<void> reportComment({
    required String commentId,
    required String reason,
  }) async {
    await _request(
      '/reports',
      method: 'POST',
      body: {'comment_id': commentId, 'reason': reason},
    );
  }

  // ---------------------------------------------------------------------------
  // INTERNAL NETWORKING
  // ---------------------------------------------------------------------------

  /// Performs the HTTP request, handles auth headers, and parses errors.
  Future<dynamic> _request(
    String endpoint, {
    String method = 'GET',
    Map<String, dynamic>? body,
    Map<String, String>? params,
    bool useAuth = true,
    bool isRetry = false,
  }) async {
    final url = Uri.parse('${config.baseUrl}$endpoint').replace(
      queryParameters: params,
    );

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (useAuth && _activeProvider != null) {
      final token = _tokenCache[_activeProvider];
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (config.enableLogging) {
      print('[Commentum] $method $url');
    }

    try {
      http.Response response;
      final encodedBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await _httpClient.post(url, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          response = await _httpClient.put(url, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          response = await _httpClient.patch(url, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          response = await _httpClient.delete(url, headers: headers, body: encodedBody);
          break;
        default:
          response = await _httpClient.get(url, headers: headers);
      }

      // Handle 401 Unauthorized
      if (response.statusCode == 401 && !isRetry && useAuth && _activeProvider != null) {
        throw CommentumError('Unauthorized: Token expired or invalid', 401);
      }

      final dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        throw CommentumError('Invalid JSON response from server', response.statusCode);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CommentumError(
          responseBody['error'] ?? 'Unknown Server Error',
          response.statusCode,
        );
      }

      return responseBody;

    } on http.ClientException catch (e) {
      throw CommentumError('Network Error: ${e.message}', 0);
    } catch (e) {
      if (e is CommentumError) rethrow;
      throw CommentumError('Unexpected Error: $e', 0);
    }
  }
  
  /// Closes the underlying HTTP client.
  void dispose() {
    _httpClient.close();
  }
}

/// A wrapper for paginated lists returned by the API.
///
/// Contains the list of [items] and a [nextCursor] for fetching the subsequent page.
class PaginatedComments {
  final List<Comment> items;
  final String? nextCursor;

  PaginatedComments({required this.items, this.nextCursor});

  factory PaginatedComments.fromJson(Map<String, dynamic> json, {required bool isReply}) {
    final key = isReply ? 'replies' : 'comments';
    return PaginatedComments(
      items: (json[key] as List?)?.map((c) => Comment.fromJson(c)).toList() ?? [],
      nextCursor: json['next_cursor'],
    );
  }
}