import 'dart:convert';

enum AppNotificationType {
  reaction,
  comment,
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String actorName;
  final String spotId;
  final String spotName;
  final String message;
  final String? imagePath;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.actorName,
    required this.spotId,
    required this.spotName,
    required this.message,
    this.imagePath,
    required this.createdAt,
    required this.isRead,
  });

  AppNotification copyWith({
    String? id,
    AppNotificationType? type,
    String? actorName,
    String? spotId,
    String? spotName,
    String? message,
    String? imagePath,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      actorName: actorName ?? this.actorName,
      spotId: spotId ?? this.spotId,
      spotName: spotName ?? this.spotName,
      message: message ?? this.message,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'actorName': actorName,
      'spotId': spotId,
      'spotName': spotName,
      'message': message,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      type: AppNotificationType.values.firstWhere(
            (e) => e.name == map['type'],
        orElse: () => AppNotificationType.reaction,
      ),
      actorName: map['actorName'] as String? ?? '',
      spotId: map['spotId'] as String? ?? '',
      spotName: map['spotName'] as String? ?? '',
      message: map['message'] as String? ?? '',
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(jsonDecode(source) as Map<String, dynamic>);
}