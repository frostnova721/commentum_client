import '../commentum_client.dart';
import 'comment.dart';

extension CommentActions on Comment {
  /// Upvotes this comment.
  /// 
  /// Wraps [CommentumClient.voteComment].
  Future<void> upVote(CommentumClient client) async {
    await client.voteComment(id, 1);
  }

  /// Downvotes this comment.
  /// 
  /// Wraps [CommentumClient.voteComment].
  Future<void> downVote(CommentumClient client) async {
    await client.voteComment(id, -1);
  }

  /// Removes the vote from this comment.
  /// 
  /// Wraps [CommentumClient.voteComment].
  Future<void> removeVote(CommentumClient client) async {
    await client.voteComment(id, 0);
  }

  /// Deletes this comment.
  /// 
  /// Wraps [CommentumClient.deleteComment].
  Future<void> delete(CommentumClient client) async {
    await client.deleteComment(id);
  }

  /// Reports this comment.
  /// 
  /// Wraps [CommentumClient.reportComment].
  Future<void> report(CommentumClient client, String reason) async {
    await client.reportComment(commentId: id, reason: reason);
  }
}
