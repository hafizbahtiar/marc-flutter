class Author {
  const Author({required this.memberId, required this.displayName});

  final String memberId;
  final String? displayName;

  factory Author.fromJson(Map<String, dynamic> json) {
    return Author(
      memberId: json['member_id'] as String,
      displayName: json['display_name'] as String?,
    );
  }

  String get label => displayName?.isNotEmpty == true ? displayName! : memberId;
}

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.content,
    required this.createdAt,
    required this.editedAt,
    required this.author,
    required this.images,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  final String id;
  final String type;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final Author author;
  final List<String> images;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  bool get isAnnouncement => type == 'announcement';
  bool get isEdited => editedAt != null;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      type: json['type'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      images: (json['images'] as List).cast<String>(),
      likeCount: json['like_count'] as int,
      commentCount: json['comment_count'] as int,
      likedByMe: json['liked_by_me'] as bool,
    );
  }

  Post copyWith({int? likeCount, bool? likedByMe}) {
    return Post(
      id: id,
      type: type,
      content: content,
      createdAt: createdAt,
      editedAt: editedAt,
      author: author,
      images: images,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.parentCommentId,
    required this.content,
    required this.createdAt,
    required this.editedAt,
    required this.author,
    required this.likeCount,
    required this.likedByMe,
  });

  final String id;
  final String? parentCommentId;
  final String content;
  final DateTime createdAt;
  final DateTime? editedAt;
  final Author author;
  final int likeCount;
  final bool likedByMe;

  bool get isEdited => editedAt != null;
  bool get isTopLevel => parentCommentId == null;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      parentCommentId: json['parent_comment_id'] as String?,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      author: Author.fromJson(json['author'] as Map<String, dynamic>),
      likeCount: json['like_count'] as int,
      likedByMe: json['liked_by_me'] as bool,
    );
  }
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.actorId,
    required this.type,
    required this.postId,
    required this.commentId,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final String type;
  final String postId;
  final String? commentId;
  final bool read;
  final DateTime createdAt;

  bool get isLike => type == 'post_like';
  bool get isComment => type == 'post_comment';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      actorId: json['actor_id'] as String,
      type: json['type'] as String,
      postId: json['post_id'] as String,
      commentId: json['comment_id'] as String?,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
