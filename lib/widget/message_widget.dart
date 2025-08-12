import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';

import '../models/message_model.dart';
import '../util/wechat_date_format.dart';

typedef MessageWidgetBuilder = Widget Function(MessageModel message);
typedef OnBubbleClick = void Function(
    MessageModel message, BuildContext ancestor);

/// support text select
typedef HiSelectionArea = Widget Function(
    {required Text child, required MessageModel message});

class DefaultMessageWidget extends StatefulWidget {
  final MessageModel message;

  /// the font-family of the [content].
  final String? fontFamily;

  /// the font-size of the [content].
  final double fontSize;

  /// the size of the [avatar].
  final double avatarSize;

  /// the text-color of the [content].
  final Color? textColor;

  /// Background color of the message
  final Color? backgroundColor;
  final MessageWidgetBuilder? messageWidget;

  /// Called when the user taps this part of the material.
  final OnBubbleClick? onBubbleTap;

  /// Called when the user long-presses on this part of the material.
  final OnBubbleClick? onBubbleLongPress;

  final HiSelectionArea? hiSelectionArea;

  const DefaultMessageWidget(
      {required GlobalKey key,
      required this.message,
      this.fontFamily,
      this.fontSize = 16.0,
      this.textColor,
      this.backgroundColor,
      this.messageWidget,
      this.avatarSize = 40,
      this.onBubbleTap,
      this.onBubbleLongPress,
      this.hiSelectionArea})
      : super(key: key);

  @override
  State<DefaultMessageWidget> createState() => _DefaultMessageWidgetState();
}

class _DefaultMessageWidgetState extends State<DefaultMessageWidget>
    with TickerProviderStateMixin {

  /// 打字机光标动画控制器
  AnimationController? _cursorAnimationController;
  Animation<double>? _cursorAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCursorAnimation();
  }

  @override
  void dispose() {
    _cursorAnimationController?.dispose();
    super.dispose();
  }

  /// 初始化打字机光标动画
  void _initializeCursorAnimation() {
    if (widget.message.streamingStatus == StreamingStatus.streaming) {
      _cursorAnimationController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );
      _cursorAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _cursorAnimationController!,
        curve: Curves.easeInOut,
      ));
      _cursorAnimationController!.repeat(reverse: true);
    }
  }

  /// 检查是否需要更新动画状态
  void _updateAnimationState() {
    final isStreaming = widget.message.streamingStatus == StreamingStatus.streaming;

    if (isStreaming && _cursorAnimationController == null) {
      // 开始流式传输，初始化动画
      _initializeCursorAnimation();
    } else if (!isStreaming && _cursorAnimationController != null) {
      // 结束流式传输，停止动画
      _cursorAnimationController?.dispose();
      _cursorAnimationController = null;
      _cursorAnimation = null;
    }
  }

  double get contentMargin => widget.avatarSize + 10;

  String get senderInitials {
    if (widget.message.ownerName == null) return "";
    List<String> chars = widget.message.ownerName!.split(" ");
    if (chars.length > 1) {
      return chars[0];
    } else {
      return widget.message.ownerName![0];
    }
  }

  Widget get _buildCircleAvatar {
    var child = widget.message.avatar is String
        ? ClipOval(
            child: Image.network(
              widget.message.avatar!,
              height: widget.avatarSize,
              width: widget.avatarSize,
            ),
          )
        : CircleAvatar(
            radius: 20,
            child: Text(
              senderInitials,
              style: const TextStyle(fontSize: 16),
            ));
    return child;
  }

  @override
  Widget build(BuildContext context) {
    // 更新动画状态
    _updateAnimationState();

    if (widget.messageWidget != null) {
      return widget.messageWidget!(widget.message);
    }
    Widget content = widget.message.ownerType == OwnerType.receiver
        ? _buildReceiver(context)
        : _buildSender(context);
    return Column(
      children: [
        if (widget.message.showCreatedTime) _buildCreatedTime(),
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: content,
        ),
      ],
    );
  }

  Widget _buildReceiver(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: <Widget>[
        _buildCircleAvatar,
        Flexible(
          child: Bubble(
              margin: BubbleEdges.fromLTRB(10, 0, contentMargin, 0),
              stick: true,
              nip: BubbleNip.leftTop,
              color: widget.backgroundColor ?? const Color.fromRGBO(233, 232, 252, 10),
              alignment: Alignment.topLeft,
              child: _buildContentText(TextAlign.left, context)),
        ),
      ],
    );
  }

  Widget _buildSender(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Flexible(
          child: Bubble(
              margin: BubbleEdges.fromLTRB(contentMargin, 0, 10, 0),
              stick: true,
              nip: BubbleNip.rightTop,
              color: widget.backgroundColor ?? Colors.white,
              alignment: Alignment.topRight,
              child: _buildContentText(TextAlign.left, context)),
        ),
        _buildCircleAvatar
      ],
    );
  }

  Widget _buildContentText(TextAlign align, BuildContext context) {
    // 根据流式状态决定显示的内容
    String displayContent;
    bool showCursor = false;

    switch (widget.message.streamingStatus) {
      case StreamingStatus.streaming:
        displayContent = widget.message.streamingContent;
        showCursor = true;
        break;
      case StreamingStatus.completed:
      case StreamingStatus.error:
        displayContent = widget.message.content;
        break;
      case StreamingStatus.none:
      default:
        displayContent = widget.message.content;
        break;
    }

    // 构建文本内容
    Widget textContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            displayContent,
            textAlign: align,
            style: TextStyle(
              fontSize: widget.fontSize,
              color: widget.textColor ?? Colors.black,
              fontFamily: widget.fontFamily,
            ),
          ),
        ),
        // 显示打字机光标
        if (showCursor && _cursorAnimation != null)
          _buildStreamingCursor(),
      ],
    );

    // 应用文本选择区域包装
    if (widget.hiSelectionArea != null) {
      // 注意：hiSelectionArea 需要 Text widget，这里需要特殊处理
      if (!showCursor) {
        final textWidget = Text(
          displayContent,
          textAlign: align,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: widget.textColor ?? Colors.black,
            fontFamily: widget.fontFamily,
          ),
        );
        textContent = widget.hiSelectionArea!.call(
          child: textWidget,
          message: widget.message,
        );
      }
    }

    return InkWell(
      onTap: () => widget.onBubbleTap != null
          ? widget.onBubbleTap!(widget.message, context)
          : null,
      onLongPress: () => widget.onBubbleLongPress != null
          ? widget.onBubbleLongPress!(widget.message, context)
          : null,
      child: textContent,
    );
  }

  /// 构建流式传输光标指示器
  Widget _buildStreamingCursor() {
    return AnimatedBuilder(
      animation: _cursorAnimation!,
      builder: (context, child) {
        return Opacity(
          opacity: _cursorAnimation!.value,
          child: Container(
            width: 2,
            height: widget.fontSize,
            margin: const EdgeInsets.only(left: 2, bottom: 2),
            decoration: BoxDecoration(
              color: widget.textColor ?? Colors.black,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreatedTime() {
    String showT = WechatDateFormat.format(message.createdAt, dayOnly: false);
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: Text(showT),
    );
  }
}
