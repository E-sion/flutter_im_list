import 'dart:async';

import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../widget/message_widget.dart';

class ChatController implements IChatController {
  /// Represents initial message list in chat which can be add by user.
  final List<MessageModel> initialMessageList;
  final ScrollController scrollController;

  ///Provide MessageWidgetBuilder to customize your bubble style.
  final MessageWidgetBuilder? messageWidgetBuilder;

  ///creation time group; unit second
  final int timePellet;
  List<int> pelletShow = [];

  /// 流式传输相关字段
  MessageModel? _currentStreamingMessage;
  Timer? _streamingThrottleTimer;
  static const int _defaultThrottleMs = 100; // 默认节流间隔100ms

  ChatController(
      {required this.initialMessageList,
      required this.scrollController,
      required this.timePellet,
      this.messageWidgetBuilder}) {
    for (var message in initialMessageList.reversed) {
      inflateMessage(message);
    }
  }

  /// Represents message stream of chat
  StreamController<List<MessageModel>> messageStreamController =
      StreamController();

  /// Used to dispose stream.
  void dispose() {
    // 清理流式传输相关资源
    _streamingThrottleTimer?.cancel();
    _currentStreamingMessage = null;

    messageStreamController.close();
    scrollController.dispose();
    initialMessageList.clear();
    pelletShow.clear();
  }

  ///ChatList is init ok
  void widgetReady() {
    if (!messageStreamController.isClosed) {
      messageStreamController.sink.add(initialMessageList);
    }
  }

  /// Used to add message in message list.
  @override
  void addMessage(MessageModel message) {
    //fix Bad state: Cannot add event after closing
    if (messageStreamController.isClosed) return;
    inflateMessage(message);
    // initialMessageList.add(message);
    //List反转后列是从底部向上展示，所以新来的消息需要插入到数据第0个位置
    initialMessageList.insert(0, message);
    messageStreamController.sink.add(initialMessageList);
    scrollToLastMessage();
  }

  @override
  void deleteMessage(MessageModel message) {
    if (messageStreamController.isClosed) return;
    initialMessageList.remove(message);
    pelletShow.clear();
    //时间的标记是从最久的消息开始标
    for (var message in initialMessageList.reversed) {
      inflateMessage(message);
    }
    messageStreamController.sink.add(initialMessageList);
  }

  /// Function for loading data while pagination.
  @override
  void loadMoreData(List<MessageModel> messageList) {
    //List反转后列是从底部向上展示，所以消息顺序也需要进行反转
    messageList = List.from(messageList.reversed);
    List<MessageModel> tempList = [...initialMessageList, ...messageList];
    //Clear record and redo
    pelletShow.clear();
    //时间的标记是从最久的消息开始标
    for (var message in tempList.reversed) {
      inflateMessage(message);
    }
    initialMessageList.clear();
    initialMessageList.addAll(tempList);
    if (messageStreamController.isClosed) return;
    messageStreamController.sink.add(initialMessageList);
  }

  /// Function to scroll to last messages in chat view
  void scrollToLastMessage() {
    //fix ScrollController not attached to any scroll views.
    if (!scrollController.hasClients) {
      return;
    }
    scrollController.animateTo(0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeIn);
  }

  ///set showCreatedTime flag
  inflateMessage(MessageModel message) {
    int pellet = (message.createdAt / (timePellet * 1000)).truncate();
    if (!pelletShow.contains(pellet)) {
      pelletShow.add(pellet);
      message.showCreatedTime = true;
    } else {
      message.showCreatedTime = false;
    }
  }

  /// 开始流式传输消息
  /// 创建一个新的流式消息并添加到列表中
  MessageModel startStreamingMessage({
    int? id,
    required OwnerType ownerType,
    String? ownerName,
    String? avatar,
  }) {
    // 创建流式消息
    final streamingMessage = MessageModel.createStreamingMessage(
      id: id,
      ownerType: ownerType,
      ownerName: ownerName,
      avatar: avatar,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // 设置时间显示标志
    inflateMessage(streamingMessage);

    // 添加到消息列表
    initialMessageList.insert(0, streamingMessage);
    _currentStreamingMessage = streamingMessage;

    // 通知UI更新
    if (!messageStreamController.isClosed) {
      messageStreamController.sink.add(initialMessageList);
    }

    // 滚动到最新消息
    scrollToLastMessage();

    return streamingMessage;
  }

  /// 更新流式传输内容
  /// 使用节流控制避免频繁UI更新
  void updateStreamingContent(String chunk, {int? throttleMs}) {
    if (_currentStreamingMessage == null) return;

    // 累积内容
    final newContent = _currentStreamingMessage!.streamingContent + chunk;

    // 取消之前的节流定时器
    _streamingThrottleTimer?.cancel();

    // 设置新的节流定时器
    _streamingThrottleTimer = Timer(
      Duration(milliseconds: throttleMs ?? _defaultThrottleMs),
      () => _performStreamingUpdate(newContent),
    );
  }

  /// 执行实际的流式UI更新（私有方法）
  void _performStreamingUpdate(String content) {
    if (_currentStreamingMessage == null || messageStreamController.isClosed) {
      return;
    }

    // 查找当前流式消息在列表中的位置
    final index = initialMessageList.indexWhere(
      (msg) => msg.key == _currentStreamingMessage!.key,
    );

    if (index != -1) {
      // 更新消息内容
      final updatedMessage = _currentStreamingMessage!.copyWithStreamingContent(content);
      initialMessageList[index] = updatedMessage;
      _currentStreamingMessage = updatedMessage;

      // 通知UI更新
      messageStreamController.sink.add(initialMessageList);
    }
  }

  /// 完成流式传输
  /// 将流式内容设为最终内容并更新状态
  void completeStreamingMessage() {
    if (_currentStreamingMessage == null) return;

    // 取消任何待处理的节流更新
    _streamingThrottleTimer?.cancel();

    // 查找当前流式消息在列表中的位置
    final index = initialMessageList.indexWhere(
      (msg) => msg.key == _currentStreamingMessage!.key,
    );

    if (index != -1) {
      // 完成流式传输，将流式内容设为最终内容
      final completedMessage = _currentStreamingMessage!.completeStreaming();
      initialMessageList[index] = completedMessage;

      // 通知UI更新
      if (!messageStreamController.isClosed) {
        messageStreamController.sink.add(initialMessageList);
      }
    }

    // 清理流式状态
    _currentStreamingMessage = null;
  }

  /// 处理流式传输错误
  void handleStreamingError(String errorMessage) {
    if (_currentStreamingMessage == null) return;

    // 取消任何待处理的节流更新
    _streamingThrottleTimer?.cancel();

    // 查找当前流式消息在列表中的位置
    final index = initialMessageList.indexWhere(
      (msg) => msg.key == _currentStreamingMessage!.key,
    );

    if (index != -1) {
      // 创建错误状态的消息
      final errorMessage = MessageModel(
        id: _currentStreamingMessage!.id,
        ownerType: _currentStreamingMessage!.ownerType,
        ownerName: _currentStreamingMessage!.ownerName,
        avatar: _currentStreamingMessage!.avatar,
        content: _currentStreamingMessage!.streamingContent.isEmpty
            ? "消息传输失败"
            : _currentStreamingMessage!.streamingContent,
        createdAt: _currentStreamingMessage!.createdAt,
        streamingStatus: StreamingStatus.error,
        streamingContent: _currentStreamingMessage!.streamingContent,
      )..showCreatedTime = _currentStreamingMessage!.showCreatedTime;

      initialMessageList[index] = errorMessage;

      // 通知UI更新
      if (!messageStreamController.isClosed) {
        messageStreamController.sink.add(initialMessageList);
      }
    }

    // 清理流式状态
    _currentStreamingMessage = null;
  }

  /// 获取当前流式消息
  MessageModel? get currentStreamingMessage => _currentStreamingMessage;

  /// 检查是否正在进行流式传输
  bool get isStreaming => _currentStreamingMessage != null;
}

abstract class IChatController {
  /// Used to add message in message list.
  void addMessage(MessageModel message);

  /// Delete message.
  void deleteMessage(MessageModel message);

  /// Function for loading data while pagination.
  void loadMoreData(List<MessageModel> messageList);

  /// Start streaming message transmission
  MessageModel startStreamingMessage({
    int? id,
    required OwnerType ownerType,
    String? ownerName,
    String? avatar,
  });

  /// Update streaming content
  void updateStreamingContent(String chunk, {int? throttleMs});

  /// Complete streaming transmission
  void completeStreamingMessage();

  /// Handle streaming error
  void handleStreamingError(String errorMessage);

  /// Get current streaming message
  MessageModel? get currentStreamingMessage;

  /// Check if streaming is in progress
  bool get isStreaming;
}
