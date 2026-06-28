# Commentum Client

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Dart Platforms](https://img.shields.io/badge/platforms-flutter%20|%20dart-blue)](https://pub.dev/packages/commentum_client)

A robust, type-safe, and modular Dart client for the **Commentum API**.

Designed to make integrating comment threads, voting systems, and moderation tools effortless. Features multi-account session management, a clean modular architecture, named parameters to prevent argument errors, and a storage-agnostic design with built-in in-memory fallback.

---

## 📑 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Getting Started](#-getting-started)
  - [1. Choose or Implement Storage](#1-choose-or-implement-storage)
  - [2. Initialize Client](#2-initialize-client)
- [Architecture & Usage](#-architecture--usage)
  - [Authentication & Multi-Account Management](#authentication--multi-account-management)
  - [Comments & Threads](#comments--threads)
  - [Interactions (Votes & Reports)](#interactions-votes--reports)
  - [Extensions](#-extensions)
- [Error Handling](#-error-handling)
- [Advanced Configuration](#-advanced-configuration)

---

## ✨ Features

* **Modular Architecture**: Cleanly separated sub-services (`client.auth`, `client.comments`, `client.interactions`) alongside convenient top-level facades.
* **Multi-Account Management**: Log into multiple providers simultaneously (**AniList**, **MyAnimeList**, **Simkl**), switch active accounts seamlessly, and load all profiles concurrently.
* **Named Parameters & Validation**: Prevents parameter order mix-ups and provides instant local validation before network dispatch.
* **Storage Agnostic**: Supports `flutter_secure_storage`, `shared_preferences`, `hive`, or the built-in `InMemoryCommentumStorage`.
* **Type-Safe Exceptions**: Granular hierarchy (`CommentumAuthException`, `CommentumValidationException`, `CommentumNetworkException`, `CommentumServerException`).

---

## 📦 Installation

Add `commentum_client` to your `pubspec.yaml`:

```yaml
dependencies:
  commentum_client: ^1.1.0
```

---

## 🚀 Getting Started

### 1. Choose or Implement Storage

You can use the ready-to-use `InMemoryCommentumStorage` or implement `CommentumStorage` for persistence across app restarts.

*Example using `flutter_secure_storage`:*

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:commentum_client/commentum_client.dart';

class SecureTokenStorage implements CommentumStorage {
  final _storage = const FlutterSecureStorage();
  
  String _key(CommentumProvider p) => 'commentum_token_${p.name}';

  @override
  Future<void> saveToken(CommentumProvider provider, String token) =>
      _storage.write(key: _key(provider), value: token);

  @override
  Future<String?> getToken(CommentumProvider provider) =>
      _storage.read(key: _key(provider));

  @override
  Future<void> deleteToken(CommentumProvider provider) =>
      _storage.delete(key: _key(provider));

  @override
  Future<Map<CommentumProvider, String>> getAllTokens() async {
    final tokens = <CommentumProvider, String>{};
    for (final provider in CommentumProvider.values) {
      final token = await getToken(provider);
      if (token != null && token.isNotEmpty) tokens[provider] = token;
    }
    return tokens;
  }

  @override
  Future<void> clearAll() async {
    for (final provider in CommentumProvider.values) {
      await deleteToken(provider);
    }
  }
}
```

### 2. Initialize Client

Create your client and hydrate its state at startup. All persisted multi-account tokens are restored automatically.

```dart
final client = CommentumClient(
  config: const CommentumConfig(
    baseUrl: 'https://api.yourdomain.com/v1',
    appClient: 'shonenx_mobile',
    enableLogging: true,
  ),
  storage: SecureTokenStorage(), // Or InMemoryCommentumStorage()
  preferredProvider: CommentumProvider.anilist,
);

void main() async {
  await client.init(); // Loads all logged-in accounts
  runApp(MyApp());
}
```

---

## 💻 Architecture & Usage

You can access endpoints through dedicated modules (`client.auth`, `client.comments`, `client.interactions`) or directly on `client`.

### Authentication & Multi-Account Management

```dart
// Login with a provider
await client.auth.login(CommentumProvider.anilist, 'oauth_access_token');
await client.auth.login(CommentumProvider.myanimelist, 'mal_access_token');

// Check logged-in providers
print(client.loggedInProviders); // [CommentumProvider.anilist, CommentumProvider.myanimelist]

// Switch active account context for posting
client.switchProvider(CommentumProvider.myanimelist);

// Get profiles for all currently logged-in accounts at once
final profiles = await client.getAllLoggedInProfiles();
profiles.forEach((provider, user) {
  print('${provider.displayName}: ${user.username}');
});

// Logout specific account or all accounts
await client.logout(CommentumProvider.anilist);
await client.logoutAll();
```

### Comments & Threads

All post methods require clear named parameters.

**Fetching Comments (with optional episode filter)**
```dart
final response = await client.comments.listComments(
  mediaId: '10123',
  episodeNumber: 3,
  limit: 20,
);
final comments = response.data;
```

**Posting a Comment**
```dart
final newComment = await client.comments.createComment(
  mediaId: '10123',
  mediaProvider: 'anilist',
  episodeNumber: 3,
  content: 'This episode was incredible!',
);
```

**Replying & Updating**
```dart
final reply = await client.comments.createReply(
  parentId: newComment.id,
  content: 'Totally agree with you!',
);

await client.comments.updateComment(
  commentId: reply.id,
  content: 'Totally agree! Best animation sequence.',
);
```

### Interactions (Votes & Reports)

```dart
// Upvote (+1) or Downvote (-1). Sending the same vote twice toggles/removes it!
await client.interactions.upvote(commentId: 'comment_123');
await client.interactions.downvote(commentId: 'comment_123');

// Report harmful content
await client.interactions.reportComment(
  commentId: 'comment_123',
  reason: 'Unmarked spoilers',
);
```

---

## 🧩 Extensions

The `CommentActions` extension provides direct interaction methods on any `Comment` instance:

```dart
final comment = response.data.first;

await comment.upVote(client);
await comment.downVote(client);
await comment.report(client, 'Spam');
await comment.delete(client);
```

---

## ⚠️ Error Handling

Catch granular typed exceptions to handle error states gracefully:

```dart
try {
  await client.createComment(
    mediaId: '101',
    mediaProvider: 'anilist',
    content: '', // Will fail validation
  );
} on CommentumValidationException catch (e) {
  print('Invalid input: ${e.message}');
} on CommentumAuthException catch (e) {
  print('Auth issue [${e.statusCode}]: Please log in again.');
} on CommentumServerException catch (e) {
  print('API Server Error [${e.statusCode}]: ${e.message}');
} on CommentumNetworkException catch (e) {
  print('Network failure: ${e.message}');
}
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.