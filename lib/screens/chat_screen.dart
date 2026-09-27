import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/chat_grouping.dart';
import '../models/chat_message.dart';
import '../models/chat_provider.dart';
import '../models/chat_read_state.dart';
import '../models/language_provider.dart';
import '../services/chat_image_cache.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import 'memories_screen.dart';

/// Private 1:1 partner chat — the Chat tab.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
    // Keeps "read the chat N min ago" honest while the screen sits open.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Typing writes are throttled inside the provider — this is cheap.
    context.read<ChatProvider>().onComposerChanged(_controller.text);
  }

  void _onScroll() {
    // reverse:true — "top" of the visible history is maxScrollExtent.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      context.read<ChatProvider>().loadOlder();
    }
  }

  Future<void> _sendText(AppStrings s, String text) async {
    if (text.trim().length > ChatService.maxTextLength) {
      _toast(s.chatTooLong(ChatService.maxTextLength));
      return;
    }
    final ok = await context.read<ChatProvider>().sendText(text);
    if (!mounted) return;
    if (ok) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } else if (text.trim().isNotEmpty) {
      _toast(s.chatSendFailed);
    }
  }

  Future<void> _sendComposer(AppStrings s) async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear(); // the provider sees the empty composer → typing off
    await _sendText(s, text);
  }

  Future<void> _attachPhoto(AppStrings s) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accentRose),
              title: Text(s.chatPickGallery, style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppTheme.accentRose),
              title: Text(s.chatPickCamera, style: const TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    // Same picker + size hints Memories uses; compression happens in
    // StorageService.compressToJpeg on upload.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    await context.read<ChatProvider>().sendImage(picked);
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  void _openMemories() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const MemoriesScreen()),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.textPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final chat = context.watch<ChatProvider>();
    final app = context.watch<AppState>();
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final partnerName = app.partnerName.isNotEmpty ? app.partnerName : s.chatTitleFallback;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _ChatAppBar(
        name: partnerName,
        avatarUrl: app.partnerAvatarUrl,
        subtitle: _readSubtitle(s, chat.partnerLastReadAt),
        onMemories: _openMemories,
        memoriesTooltip: s.chatMemoriesTooltip,
      ),
      body: Column(
        children: [
          if (chat.isFromCache && chat.messages.isNotEmpty) _OfflineBar(text: s.chatOffline),
          Expanded(
            // Tapping empty thread space (or any state view) drops the keyboard.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: _body(s, chat, app, partnerName),
            ),
          ),
          if (chat.hasPartner) ...[
            // Reserved-height slot: the indicator fades in/out without moving
            // the thread or the composer.
            _TypingSlot(
              visible: chat.partnerTyping,
              label: s.chatTyping(partnerName),
            ),
            if (!keyboardOpen)
              _QuickReplies(
                chips: [
                  (label: s.chatQuickUsTime, onTap: () => _sendText(s, s.chatQuickUsTime)),
                  (label: s.chatQuickDateSoon, onTap: () => _sendText(s, s.chatQuickDateSoon)),
                  (label: s.chatQuickPlan, onTap: () => app.requestTabNavigation(2)),
                ],
              ),
            _InputBar(
              controller: _controller,
              hint: s.chatInputHint,
              sendLabel: s.chatSend,
              attachLabel: s.chatAttachPhoto,
              onSend: () => _sendComposer(s),
              onAttach: () => _attachPhoto(s),
            ),
          ],
        ],
      ),
    );
  }

  String? _readSubtitle(AppStrings s, DateTime? lastReadAt) {
    final r = readRecency(lastReadAt, DateTime.now());
    if (r == null) return null;
    return switch (r.kind) {
      ReadRecencyKind.justNow => s.chatReadJustNow,
      ReadRecencyKind.minutes => s.chatReadMinutesAgo(r.value),
      ReadRecencyKind.hours => s.chatReadHoursAgo(r.value),
    };
  }

  Widget _body(AppStrings s, ChatProvider chat, AppState app, String partnerName) {
    if (!chat.initialized) {
      return const Center(
        child: SizedBox(
          width: 22, height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRose),
        ),
      );
    }
    if (!chat.hasPartner) {
      return _EmptyState(
        icon: Icons.favorite_border,
        title: s.chatNoPartnerTitle,
        subtitle: s.chatNoPartnerSub,
      );
    }
    if (chat.error != null && chat.messages.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_outlined,
        title: s.chatErrorTitle,
        subtitle: '',
        action: TextButton(
          onPressed: () {
            chat.clearError();
            chat.loadOlder();
          },
          child: Text(s.chatRetry, style: const TextStyle(color: AppTheme.accentRose)),
        ),
      );
    }
    if (chat.messages.isEmpty && chat.uploads.isEmpty) {
      return _EmptyState(
        icon: Icons.chat_bubble_outline,
        title: s.chatEmptyTitle,
        subtitle: s.chatEmptySub,
      );
    }
    return _MessageList(
      controller: _scroll,
      messages: chat.messages,
      uploads: chat.uploads,
      onRetryUpload: chat.retryUpload,
      onRemoveUpload: chat.removeUpload,
      myUid: app.userId,
      partnerName: partnerName,
      partnerLastReadAt: chat.partnerLastReadAt,
      loadingOlder: chat.loadingOlder,
      isHearted: chat.isHearted,
      onToggleHeart: (id) {
        HapticFeedback.lightImpact();
        chat.toggleHeart(id);
      },
      s: s,
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String? avatarUrl;
  final String? subtitle;
  final VoidCallback onMemories;
  final String memoriesTooltip;

  const _ChatAppBar({
    required this.name,
    required this.avatarUrl,
    required this.subtitle,
    required this.onMemories,
    required this.memoriesTooltip,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 20,
      toolbarHeight: 64,
      title: Row(
        children: [
          _Avatar(url: avatarUrl, name: name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Neutral read-watermark label — never "online", never a dot.
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Material(
            color: AppTheme.white,
            shape: const CircleBorder(side: BorderSide(color: AppTheme.divider, width: 0.5)),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              tooltip: memoriesTooltip,
              onPressed: onMemories,
              icon: const Icon(Icons.photo_library_outlined, color: AppTheme.accentRose, size: 20),
            ),
          ),
        ),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(0.5),
        child: Divider(height: 0.5, thickness: 0.5, color: AppTheme.divider),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double size;
  const _Avatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '❤';
    final fallback = Container(
      width: size, height: size,
      decoration: const BoxDecoration(color: AppTheme.accentRoseLight, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(color: AppTheme.accentRose, fontSize: size * 0.42, fontWeight: FontWeight.w700)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

// ── Message list ─────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final ScrollController controller;
  final List<ChatMessage> messages; // newest first
  final List<PendingUpload> uploads; // newest first, local only
  final void Function(String id) onRetryUpload;
  final void Function(String id) onRemoveUpload;
  final String myUid;
  final String partnerName;
  final DateTime? partnerLastReadAt;
  final bool loadingOlder;
  final bool Function(String messageId) isHearted;
  final void Function(String messageId) onToggleHeart;
  final AppStrings s;

  const _MessageList({
    required this.controller,
    required this.messages,
    required this.uploads,
    required this.onRetryUpload,
    required this.onRemoveUpload,
    required this.myUid,
    required this.partnerName,
    required this.partnerLastReadAt,
    required this.loadingOlder,
    required this.isHearted,
    required this.onToggleHeart,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    // Only my newest message carries a delivery receipt.
    final myNewestIdx = newestOutgoingIndex(messages, myUid);

    final nUp = uploads.length;
    return ListView.builder(
      controller: controller,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: nUp + messages.length + 1,
      itemBuilder: (context, idx) {
        // Local uploads sit at the newest end, before any server message.
        if (idx < nUp) {
          final u = uploads[idx];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _UploadBubble(
                upload: u,
                onRetry: () => onRetryUpload(u.id),
                onRemove: () => onRemoveUpload(u.id),
                s: s,
              ),
              const SizedBox(height: 10),
            ],
          );
        }
        final i = idx - nUp;
        if (i == messages.length) {
          if (loadingOlder) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(child: Text(s.chatLoadingOlder,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
            );
          }
          return const SizedBox(height: 8);
        }
        final m = messages[i];
        final mine = m.isMine(myUid);
        final pos = groupPositionAt(messages, i);
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final showDay = older == null || isDifferentDay(m.sortTime, older.sortTime);
        final isReceiptSlot = mine && i == myNewestIdx;

        Widget? footer;
        if (isReceiptSlot) {
          footer = _Receipt(
            status: outgoingStatusFor(m, partnerLastReadAt),
            sentAt: m.createdAt,
            seenAt: partnerLastReadAt,
            s: s,
          );
        } else if (showsGroupFooter(pos)) {
          footer = Text(
            hhmm(m.sortTime),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
          );
        }

        return Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showDay) _DayChip(label: _dayLabel(m.sortTime)),
            _Bubble(
              message: m,
              mine: mine,
              pos: pos,
              partnerName: partnerName,
              hearted: isHearted(m.id),
              onLongPress: m.id.isEmpty ? null : () => onToggleHeart(m.id),
              s: s,
            ),
            if (footer != null)
              Padding(
                padding: EdgeInsets.only(top: 3, left: mine ? 0 : 6, right: mine ? 6 : 0),
                child: footer,
              ),
            SizedBox(height: gapBelow(pos)),
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return s.chatToday;
    if (diff == 1) return s.chatYesterday;
    return s.homeFormattedDate(t);
  }
}

/// Sending… · ✓ Sent HH:mm (message time) · ✓✓ Seen HH:mm (partner read time).
class _Receipt extends StatelessWidget {
  final OutgoingStatus status;
  final DateTime? sentAt;
  final DateTime? seenAt;
  final AppStrings s;
  const _Receipt({required this.status, required this.sentAt, required this.seenAt, required this.s});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppTheme.textMuted, fontSize: 11);
    switch (status) {
      case OutgoingStatus.sending:
        return Text(s.chatSending, style: style);
      case OutgoingStatus.sent:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_rounded, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 3),
          Text(s.chatSentAt(sentAt != null ? hhmm(sentAt!) : ''), style: style),
        ]);
      case OutgoingStatus.seen:
        return Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.done_all_rounded, size: 14, color: AppTheme.accentGreen),
          const SizedBox(width: 3),
          Text(
            s.chatSeenAt(seenAt != null ? hhmm(seenAt!) : ''),
            style: style.copyWith(color: AppTheme.accentGreen),
          ),
        ]);
    }
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  const _DayChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardBeige,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final GroupPosition pos;
  final String partnerName;
  final bool hearted;
  final VoidCallback? onLongPress;
  final AppStrings s;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.pos,
    required this.partnerName,
    required this.hearted,
    required this.onLongPress,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    final isIdea = message.type == ChatMessageType.idea && message.idea != null;
    final isImage = message.type == ChatMessageType.image && message.storagePath != null;
    final standalone = isIdea || isImage; // structured: never grouped/flattened
    final c = bubbleCorners(mine: mine, pos: standalone ? GroupPosition.single : pos);

    final child = isIdea
        ? _IdeaCard(idea: message.idea!, mine: mine, partnerName: partnerName, s: s)
        : isImage
            ? _ImageBubble(message: message, s: s)
            : Text(
            message.text,
            style: TextStyle(
              color: mine ? AppTheme.white : AppTheme.textPrimary,
              fontSize: 15,
              height: 1.35,
            ),
          );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: standalone ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: standalone ? Colors.transparent : (mine ? AppTheme.accentRose : AppTheme.white),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(c.topLeft),
          topRight: Radius.circular(c.topRight),
          bottomLeft: Radius.circular(c.bottomLeft),
          bottomRight: Radius.circular(c.bottomRight),
        ),
        border: standalone || mine ? null : Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: child,
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Opacity(
          opacity: message.isPending ? 0.7 : 1,
          child: Padding(
            // Room for the heart badge to overlap the bottom corner.
            padding: EdgeInsets.only(bottom: hearted ? 8 : 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                bubble,
                if (hearted)
                  Positioned(
                    bottom: -8,
                    left: mine ? -6 : null,
                    right: mine ? null : -6,
                    child: const _HeartBadge(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One small badge, shown when EITHER member has hearted the message.
class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.divider, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.favorite_rounded, size: 12, color: AppTheme.accentRose),
    );
  }
}

// ── Idea card (type: idea) ───────────────────────────────────────────────────

class _IdeaCard extends StatelessWidget {
  final ChatIdea idea;
  final bool mine;
  final String partnerName;
  final AppStrings s;
  const _IdeaCard({required this.idea, required this.mine, required this.partnerName, required this.s});

  @override
  Widget build(BuildContext context) {
    final no = s.isNorwegian;
    return GestureDetector(
      onTap: () => showChatIdeaSheet(context, idea),
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (idea.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: idea.coverImageUrl!,
                height: 120, width: double.infinity, fit: BoxFit.cover,
                placeholder: (_, _) => Container(height: 120, color: AppTheme.cardBeige),
                errorWidget: (_, _, _) => Container(height: 120, color: AppTheme.cardBeige),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mine ? s.chatIdeaSharedByYou : s.chatIdeaSharedBy(partnerName),
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(idea.title(no),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${idea.meta(no)} · ${idea.category(no)}',
                      style: const TextStyle(color: AppTheme.textSubtle, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail sheet for a shared idea, with a route into planning.
Future<void> showChatIdeaSheet(BuildContext context, ChatIdea idea) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final s = ctx.watch<LanguageProvider>().s;
      final no = s.isNorwegian;
      return Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppTheme.accentRoseLight, borderRadius: BorderRadius.circular(999)),
              child: Text(idea.category(no),
                  style: const TextStyle(color: AppTheme.accentRose, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            Text(idea.title(no),
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(idea.meta(no), style: const TextStyle(color: AppTheme.textSubtle, fontSize: 13)),
            const SizedBox(height: 14),
            if (idea.description(no).isNotEmpty)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: AppTheme.white, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(14),
                child: Text(idea.description(no),
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, height: 1.5)),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ctx.read<AppState>().requestTabNavigation(2);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  foregroundColor: AppTheme.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(s.chatIdeaPlan, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.chatIdeaClose,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ── Typing indicator ─────────────────────────────────────────────────────────

/// Fixed-height slot so appearing/disappearing never shifts the thread.
class _TypingSlot extends StatelessWidget {
  final bool visible;
  final String label;
  const _TypingSlot({required this.visible, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: visible
                ? Row(
                    key: const ValueKey('typing'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _TypingDots(),
                      const SizedBox(width: 8),
                      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          // Staggered pulse: each dot peaks a third of a cycle after the last.
          final t = ((_c.value - i / 3) % 1.0);
          final lift = (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Container(
            width: 6, height: 6,
            margin: EdgeInsets.only(right: i < 2 ? 3 : 0, bottom: lift * 3),
            decoration: BoxDecoration(
              color: AppTheme.accentRose.withValues(alpha: 0.45 + 0.55 * lift),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

// ── Quick replies ────────────────────────────────────────────────────────────

class _QuickReplies extends StatelessWidget {
  final List<({String label, VoidCallback onTap})> chips;
  const _QuickReplies({required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(chips[i].label),
          onPressed: chips[i].onTap,
          backgroundColor: AppTheme.white,
          side: const BorderSide(color: AppTheme.divider, width: 0.5),
          shape: const StadiumBorder(),
          labelStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// ── Input bar / misc ─────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final String attachLabel;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  const _InputBar({
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.attachLabel,
    required this.onSend,
    required this.onAttach,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(4, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment lives in the composer — the header icon is Memories,
          // and only Memories.
          IconButton(
            tooltip: attachLabel,
            onPressed: onAttach,
            icon: const Icon(Icons.add_photo_alternate_outlined, color: AppTheme.accentRose, size: 24),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              maxLength: ChatService.maxTextLength,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                counterText: '',
                hintText: hint,
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Derived straight from the controller so the button can never lag
          // behind the text (pale when empty, full burgundy when there is
          // anything non-whitespace to send).
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              final canSend = value.text.trim().isNotEmpty;
              return IconButton.filled(
                onPressed: canSend ? onSend : null,
                tooltip: sendLabel,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  disabledBackgroundColor: AppTheme.accentRose.withValues(alpha: 0.30),
                  foregroundColor: AppTheme.white,
                  disabledForegroundColor: AppTheme.white,
                ),
                icon: const Icon(Icons.arrow_upward_rounded, size: 22),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OfflineBar extends StatelessWidget {
  final String text;
  const _OfflineBar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.warningAmberLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.heatAmberText, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AppTheme.accentRoseLight, shape: BoxShape.circle),
              child: Icon(icon, color: AppTheme.accentRose, size: 30),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}

// ── Image messages ───────────────────────────────────────────────────────────

const double _kImageBubbleWidth = 240;

/// Inline image: resolves the Storage path through the rules-governed URL
/// cache, reserves the aspect ratio while loading, and opens fullscreen.
class _ImageBubble extends StatelessWidget {
  final ChatMessage message;
  final AppStrings s;
  const _ImageBubble({required this.message, required this.s});

  @override
  Widget build(BuildContext context) {
    final frame = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: _kImageBubbleWidth,
        child: AspectRatio(
          aspectRatio: message.aspectRatio.clamp(0.5, 2.0),
          child: FutureBuilder<String>(
            future: ChatImageCache.urlFor(message.storagePath!),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ImagePlaceholder(icon: Icons.broken_image_outlined, label: s.chatImageUnavailable);
              }
              final url = snap.data;
              if (url == null) return const _ImagePlaceholder(spinner: true);
              return GestureDetector(
                onTap: () => showChatImageViewer(context, url, s),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const _ImagePlaceholder(spinner: true),
                  errorWidget: (_, _, _) =>
                      _ImagePlaceholder(icon: Icons.broken_image_outlined, label: s.chatImageUnavailable),
                ),
              );
            },
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider, width: 0.5),
      ),
      child: frame,
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool spinner;
  final IconData? icon;
  final String? label;
  const _ImagePlaceholder({this.spinner = false, this.icon, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.cardBeige,
      alignment: Alignment.center,
      child: spinner
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentRose),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.textMuted, size: 26),
                if (label != null) ...[
                  const SizedBox(height: 4),
                  Text(label!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ],
            ),
    );
  }
}

/// A local image still uploading (or failed), shown on the sender's side.
class _UploadBubble extends StatelessWidget {
  final PendingUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final AppStrings s;
  const _UploadBubble({required this.upload, required this.onRetry, required this.onRemove, required this.s});

  @override
  Widget build(BuildContext context) {
    final failed = upload.status == UploadStatus.failed;
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: _kImageBubbleWidth,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Opacity(
                    opacity: failed ? 0.55 : 0.75,
                    child: Image.file(File(upload.localPath), fit: BoxFit.cover),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: failed ? 0.25 : 0.08),
                      alignment: Alignment.center,
                      child: failed
                          ? const Icon(Icons.error_outline_rounded, color: AppTheme.white, size: 30)
                          : const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          if (failed) ...[
            if (upload.diagnostic != null)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: Text(
                  upload.diagnostic!,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s.chatImageFailed, style: const TextStyle(color: AppTheme.heatRedText, fontSize: 11)),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(s.chatRetry, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.accentRose)),
              ),
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: Text(s.chatImageRemove, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ]),
          ] else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(s.chatImageUploading, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

/// Fullscreen viewer with pinch-zoom. Pushed on the ROOT navigator so it
/// covers the tab bar too.
Future<void> showChatImageViewer(BuildContext context, String url, AppStrings s) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (ctx, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white),
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined, color: AppTheme.white, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8, right: 8,
                child: IconButton(
                  tooltip: s.chatImageClose,
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppTheme.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
      transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    ),
  );
}
