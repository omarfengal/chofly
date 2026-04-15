import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../services/firebase_service.dart';
import '../../services/chat_service.dart' show kQuickReplies;
import '../../services/providers.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// CHAT SCREEN  — conversation client ↔ technicien [Feature #3]
// ════════════════════════════════════════════════════════════════
class ChatScreen extends StatefulWidget {
  final String requestId;
  final String otherPartyName;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.otherPartyName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _analyticsService = AnalyticsService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  bool _isSending = false;
  bool _showQuickReplies = true; // TÂCHE 4: quick replies visibles si champ vide
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _analyticsService.logChatOpened(widget.requestId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
    // Listen to input changes to fire typing events
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_textController.text.isEmpty) {
      _chatService.setTyping(widget.requestId, _myId, false);
      _typingTimer?.cancel();
      return;
    }
    // Debounce: send "typing" on first keystroke, clear after 2s idle
    _chatService.setTyping(widget.requestId, _myId, true);
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.setTyping(widget.requestId, _myId, false);
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatService.setTyping(widget.requestId, _myId, false);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _myId =>
      context.read<AuthProvider>().firebaseUser?.uid ?? '';

  String get _myName =>
      context.read<AuthProvider>().userModel?.name ?? '';

  String get _myRole =>
      context.read<AuthProvider>().userModel?.role ?? 'customer';

  Future<void> _markRead() async {
    await _chatService.markAllRead(widget.requestId, _myId);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    setState(() => _isSending = true);
    await _chatService.sendText(
      requestId: widget.requestId,
      senderId: _myId,
      senderName: _myName,
      senderRole: _myRole,
      text: text,
    );
    setState(() => _isSending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() => _isSending = true);
    await _chatService.sendImage(
      requestId: widget.requestId,
      senderId: _myId,
      senderName: _myName,
      senderRole: _myRole,
      imageFile: File(picked.path),
    );
    setState(() => _isSending = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: ChoflyAppBar(
        title: widget.otherPartyName,
        subtitle: 'Conversation sécurisée',
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.watchMessages(widget.requestId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppTheme.green),
                    ),
                  );
                }
                final messages = snap.data ?? [];
                if (messages.isEmpty) {
                  return const Center(
                    child: EmptyState(
                      emoji: '💬',
                      title: 'Démarrez la conversation',
                      subtitle: 'Échangez avec votre technicien\npour préciser l\'intervention.',
                    ),
                  );
                }
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMe = msg.senderId == _myId;
                    final showDate = i == 0 ||
                        messages[i].createdAt.day !=
                            messages[i - 1].createdAt.day;

                    return Column(
                      children: [
                        if (showDate)
                          _DateChip(date: msg.createdAt),
                        _MessageBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          StreamBuilder<bool>(
            stream: _chatService.watchOtherTyping(widget.requestId, _myId),
            builder: (_, snap) {
              final isTyping = snap.data ?? false;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isTyping
                  ? Padding(
                      key: const ValueKey('typing'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.card2,
                          child: Text(widget.otherPartyName.isNotEmpty
                            ? widget.otherPartyName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w700, color: AppTheme.green)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18),
                              topRight: Radius.circular(18),
                              bottomRight: Radius.circular(18),
                              bottomLeft: Radius.circular(4),
                            ),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: const _TypingDots(),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(key: ValueKey('no-typing')),
              );
            },
          ),

          // TÂCHE 4 — Quick replies
          _QuickReplies(
            onSelected: (text) {
              _textController.text = text;
              _sendText();
            },
            visible: _textController.text.isEmpty,
          ),

          // Input bar
          _InputBar(
            controller: _textController,
            isSending: _isSending,
            onSend: _sendText,
            onPickImage: _pickAndSendImage,
          ),
        ],
      ),
    );
  }
}

// ── Date chip ─────────────────────────────────────────────────
class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Aujourd\'hui';
    if (d == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Text(
            _label(),
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textMuted),
          ),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (other party only)
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.card2,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.green),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: message.type == MessageType.image
                  ? EdgeInsets.zero
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.green : AppTheme.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft:
                      Radius.circular(isMe ? 18 : 4),
                  bottomRight:
                      Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe
                    ? null
                    : Border.all(color: AppTheme.border),
              ),
              child: _buildContent(context),
            ),
          ),

          // Read tick (me only)
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(
              message.isRead
                  ? Icons.done_all_rounded
                  : Icons.done_rounded,
              size: 13,
              color: message.isRead
                  ? AppTheme.green
                  : AppTheme.textMuted,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? AppTheme.bg : AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${message.createdAt.hour.toString().padLeft(2, '0')}:'
              '${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10,
                color: isMe
                    ? Color.fromRGBO(8, 12, 8, 0.6)
                    : AppTheme.textMuted,
              ),
            ),
          ],
        );

      case MessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          child: GestureDetector(
            onTap: () => _openImage(context, message.imageUrl!),
            child: CachedNetworkImage(
              imageUrl: message.imageUrl!,
              width: 220,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 220,
                height: 180,
                color: AppTheme.card2,
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppTheme.green),
                  ),
                ),
              ),
            ),
          ),
        );

      case MessageType.system:
        return Text(
          message.text ?? '',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        );
    }
  }

  void _openImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullImageView(url: url),
      ),
    );
  }
}

// ── Full image viewer ─────────────────────────────────────────
class _FullImageView extends StatelessWidget {
  final String url;
  const _FullImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme:
            const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url),
        ),
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onPickImage;

  const _InputBar({
    required this.controller,
    required this.isSending,
    required this.onSend,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          // Photo button
          GestureDetector(
            onTap: isSending ? null : onPickImage,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(
                Icons.image_outlined,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: controller,
                style: const TextStyle(
                    fontSize: 14, color: AppTheme.textPrimary),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Votre message…',
                  hintStyle:
                      TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  filled: false,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: isSending ? null : onSend,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSending ? AppTheme.border : AppTheme.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.bg,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: AppTheme.bg,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated typing dots ──────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          // Each dot offset by 0.33
          final anim = Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _ctrl,
              curve: Interval(i * 0.33, (i * 0.33) + 0.5, curve: Curves.easeInOut),
            ),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Transform.translate(
              offset: Offset(0, -4 * anim.value),
              child: Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted
                    .withOpacity(0.4 + 0.6 * anim.value),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }));
      },
    );
  }
}
