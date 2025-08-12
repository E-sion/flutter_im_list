import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_im_list/models/message_model.dart';
import 'package:flutter_im_list/core/chat_controller.dart';
import 'package:flutter_im_list/widget/chat_list_widget.dart';

/// 流式消息传输示例
/// 演示如何使用 flutter_im_list 的流式功能
class StreamingExample extends StatefulWidget {
  const StreamingExample({super.key});

  @override
  State<StreamingExample> createState() => _StreamingExampleState();
}

class _StreamingExampleState extends State<StreamingExample> {
  late ChatController chatController;
  final TextEditingController _textController = TextEditingController();
  Timer? _simulationTimer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeChatController();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    chatController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _initializeChatController() {
    chatController = ChatController(
      initialMessageList: [],
      timePellet: 60,
      scrollController: ScrollController(),
    );

    // 添加一些示例消息
    _addWelcomeMessages();
  }

  void _addWelcomeMessages() {
    final welcomeMessage = MessageModel(
      id: 1,
      ownerType: OwnerType.receiver,
      ownerName: "AI助手",
      avatar: null,
      content: "你好！我是AI助手。发送消息给我，我会以流式方式回复你。",
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    chatController.addMessage(welcomeMessage);
  }

  /// 发送用户消息
  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    // 添加用户消息
    final userMessage = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch,
      ownerType: OwnerType.sender,
      ownerName: "用户",
      avatar: null,
      content: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    chatController.addMessage(userMessage);

    // 清空输入框
    _textController.clear();

    // 模拟AI流式回复
    _simulateStreamingReply(text);
  }

  /// 模拟AI流式回复
  void _simulateStreamingReply(String userInput) {
    // 开始流式消息
    final streamingMessage = chatController.startStreamingMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      ownerType: OwnerType.receiver,
      ownerName: "AI助手",
      avatar: null,
    );

    // 生成回复内容
    final replyContent = _generateReplyContent(userInput);
    final words = replyContent.split(' ');
    
    int wordIndex = 0;
    String accumulatedContent = '';

    // 模拟逐词传输
    _simulationTimer = Timer.periodic(
      Duration(milliseconds: 100 + _random.nextInt(200)), // 100-300ms间隔
      (timer) {
        if (wordIndex >= words.length) {
          // 传输完成
          timer.cancel();
          chatController.completeStreamingMessage();
          return;
        }

        // 添加下一个词
        if (accumulatedContent.isNotEmpty) {
          accumulatedContent += ' ';
        }
        accumulatedContent += words[wordIndex];
        wordIndex++;

        // 更新流式内容
        chatController.updateStreamingContent(
          words[wordIndex - 1] + (wordIndex < words.length ? ' ' : ''),
          throttleMs: 50, // 50ms节流
        );
      },
    );
  }

  /// 生成回复内容
  String _generateReplyContent(String userInput) {
    final responses = [
      "这是一个很有趣的问题！让我来详细回答你。",
      "感谢你的提问。根据我的理解，这个问题可以从多个角度来分析。",
      "你提到的内容很有价值。我认为我们可以这样来看待这个问题。",
      "这确实是一个值得深入思考的话题。让我分享一些我的观点。",
      "基于你的输入，我想提供一些相关的信息和建议。",
    ];
    
    final baseResponse = responses[_random.nextInt(responses.length)];
    final additionalContent = "流式传输让对话更加自然和流畅，就像真人对话一样逐字显示内容。";
    
    return "$baseResponse $additionalContent 你觉得这种体验如何？";
  }

  /// 模拟网络错误
  void _simulateError() {
    final streamingMessage = chatController.startStreamingMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      ownerType: OwnerType.receiver,
      ownerName: "AI助手",
      avatar: null,
    );

    // 发送一些内容后模拟错误
    Timer(const Duration(milliseconds: 500), () {
      chatController.updateStreamingContent("这是一个测试消息，但是会发生错误...");
    });

    Timer(const Duration(milliseconds: 1500), () {
      chatController.handleStreamingError("网络连接中断");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('流式消息示例'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.error_outline),
            onPressed: _simulateError,
            tooltip: '模拟错误',
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ChatList(
              chatController: chatController,
              padding: const EdgeInsets.all(8.0),
            ),
          ),
          // 输入区域
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: chatController.isStreaming ? null : _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 简单的使用示例
class SimpleStreamingExample {
  late ChatController chatController;

  void initializeChat() {
    chatController = ChatController(
      initialMessageList: [],
      timePellet: 60,
      scrollController: ScrollController(),
    );
  }

  /// 基本流式消息发送示例
  void sendStreamingMessage() async {
    // 1. 开始流式消息
    final streamingMessage = chatController.startStreamingMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      ownerType: OwnerType.receiver,
      ownerName: "AI",
      avatar: null,
    );

    // 2. 模拟接收数据流
    final chunks = ["Hello", " ", "World", "!", " ", "This", " ", "is", " ", "streaming."];
    
    for (final chunk in chunks) {
      await Future.delayed(const Duration(milliseconds: 200));
      chatController.updateStreamingContent(chunk);
    }

    // 3. 完成流式传输
    chatController.completeStreamingMessage();
  }

  void dispose() {
    chatController.dispose();
  }
}
