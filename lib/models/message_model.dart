import 'package:flutter/widgets.dart';

enum OwnerType { receiver, sender }

/// 流式传输状态枚举
enum StreamingStatus {
  /// 非流式消息
  none,
  /// 流式传输中
  streaming,
  /// 流式传输完成
  completed,
  /// 流式传输错误
  error
}

OwnerType _of(String name) {
  if (name == OwnerType.receiver.toString()) {
    return OwnerType.receiver;
  } else {
    return OwnerType.sender;
  }
}

class MessageModel {
  /// Provides id
  final int? id;

  /// Avoid rebuilding the message widget when new incoming messages refresh the list.
  final GlobalKey key;

  /// Controls who is sending or receiving a message.
  /// Used to handle in which side of the screen the message
  /// will be displayed.
  final OwnerType ownerType;

  /// Name to be displayed with the initials.
  /// egg.: Higor Lapa will be H
  final String? ownerName;

  /// avatar url
  final String? avatar;

  /// The content to be displayed as a message.
  final String content;

  /// Provides message created time,milliseconds since.
  final int createdAt;

  ///Whether to display the creation time.
  bool showCreatedTime = false;

  /// 流式传输状态
  StreamingStatus streamingStatus;

  /// 流式传输的累积内容（用于打字机效果）
  String streamingContent;

  MessageModel({
    this.id,
    required this.ownerType,
    this.ownerName,
    this.avatar,
    required this.content,
    required this.createdAt,
    this.streamingStatus = StreamingStatus.none,
    this.streamingContent = '',
  }) : key = GlobalKey();

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json["id"],
        content: json["content"],
        createdAt: json["createdAt"],
        ownerType: _of(json["ownerType"]),
        avatar: json["avatar"],
        ownerName: json["ownerName"],
        streamingStatus: StreamingStatus.values.firstWhere(
          (e) => e.toString() == json["streamingStatus"],
          orElse: () => StreamingStatus.none,
        ),
        streamingContent: json["streamingContent"] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'createdAt': createdAt,
        'ownerName': ownerName,
        //数据库存储不支持复合类型
        'ownerType': ownerType.toString(),
        'avatar': avatar,
        'streamingStatus': streamingStatus.toString(),
        'streamingContent': streamingContent,
      };

  /// 创建流式消息的工厂方法
  factory MessageModel.createStreamingMessage({
    int? id,
    required OwnerType ownerType,
    String? ownerName,
    String? avatar,
    required int createdAt,
  }) => MessageModel(
        id: id,
        ownerType: ownerType,
        ownerName: ownerName,
        avatar: avatar,
        content: '', // 流式消息初始内容为空
        createdAt: createdAt,
        streamingStatus: StreamingStatus.streaming,
        streamingContent: '',
      );

  /// 复制消息并更新流式内容
  MessageModel copyWithStreamingContent(String newContent) {
    return MessageModel(
      id: id,
      ownerType: ownerType,
      ownerName: ownerName,
      avatar: avatar,
      content: content,
      createdAt: createdAt,
      streamingStatus: streamingStatus,
      streamingContent: newContent,
    )..showCreatedTime = showCreatedTime;
  }

  /// 完成流式传输
  MessageModel completeStreaming() {
    return MessageModel(
      id: id,
      ownerType: ownerType,
      ownerName: ownerName,
      avatar: avatar,
      content: streamingContent, // 将流式内容设为最终内容
      createdAt: createdAt,
      streamingStatus: StreamingStatus.completed,
      streamingContent: streamingContent,
    )..showCreatedTime = showCreatedTime;
  }
}
