import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/chat_message.dart';
import '../models/chat_provider.dart';
import '../models/chat_read_state.dart';
import '../models/language_provider.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';

/// Private 1:1 partner chat — the Chat tab.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final can = _controller.text.trim().isNotEmpty;
    if (can != _canSend) setState(() => _canSend = can);
  }

  void _onScroll() {
    // reverse:true — "top" of the visible history is maxScrollExtent.
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      context.read<ChatProvider>().loadOlder();
    }
  }

  Future<void> _send(AppStrings s) async {
    final text = _controller.text;
    if (text.trim().length > ChatService.maxTextLength) {
      _toast(s.chatTooLong(ChatService.maxTextLength));
      return;
    }
    final ok = await context.read<ChatProvider>().sendText(text);
    if (!mounted) return;
    if (ok) {
      _controller.clear();
      // Newest message is index 0 in a reversed list — jump to it.
      if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    } else if (text.trim().isNotEmpty) {
      _toast(s.chatSendFailed);
    }
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _ChatAppBar(
        name: app.partnerName.isNotEmpty ? app.partnerName : s.chatTitleFallback,
        avatarUrl: app.partnerAvatarUrl,
      ),
      body: Column(
        children: [
          if (chat.isFromCache && chat.messages.isNotEmpty) _OfflineBar(text: s.chatOffline),
          Expanded(child: _body(s, chat, app)),
          if (chat.hasPartner) _InputBar(
            controller: _controller,
            hint: s.chatInputHint,
            sendLabel: s.chatSend,
            canSend: _canSend,
            onSend: () => _send(s),
          ),
        ],
      ),
    );
  }

  Widget _body(AppStrings s, ChatProvider chat, AppState app) {
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
    if (chat.messages.isEmpty) {
      return _EmptyState(
        icon: Icons.chat_bubble_outline,
        title: s.chatEmptyTitle,
        subtitle: s.chatEmptySub,
      );
    }
    return _MessageList(
      controller: _scroll,
      messages: chat.messages,
      myUid: app.userId,
      partnerName: app.partnerName,
      partnerLastReadAt: chat.partnerLastReadAt,
      loadingOlder: chat.loadingOlder,
      hasMore: chat.hasMore,
      s: s,
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String? avatarUrl;
  const _ChatAppBar({required this.name, required this.avatarUrl});

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
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
  final String myUid;
  final String partnerName;
  final DateTime? partnerLastReadAt;
  final bool loadingOlder;
  final bool hasMore;
  final AppStrings s;

  const _MessageList({
    required this.controller,
    required this.messages,
    required this.myUid,
    required this.partnerName,
    required this.partnerLastReadAt,
    required this.loadingOlder,
    required this.hasMore,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    // Only my newest message carries a delivery status label.
    final myNewestIdx = newestOutgoingIndex(messages, myUid);

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: messages.length + 1,
      itemBuilder: (context, i) {
        if (i == messages.length) {
          // Header slot at the very top of history.
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
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final showDay = older == null || isDifferentDay(m.sortTime, older.sortTime);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDay) _DayChip(label: _dayLabel(m.sortTime)),
            _Bubble(
              message: m,
              mine: mine,
              partnerName: partnerName,
              isNorwegian: s.isNorwegian,
              s: s,
            ),
            if (mine && i == myNewestIdx)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 6, bottom: 4),
                child: Text(
                  switch (outgoingStatusFor(m, partnerLastReadAt)) {
                    OutgoingStatus.sending => s.chatSending,
                    OutgoingStatus.sent => s.chatSent,
                    OutgoingStatus.seen => s.chatSeen,
                  },
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              )
            else
              const SizedBox(height: 4),
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
  final String partnerName;
  final bool isNorwegian;
  final AppStrings s;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.partnerName,
    required this.isNorwegian,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    final child = message.type == ChatMessageType.idea && message.idea != null
        ? _IdeaCard(idea: message.idea!, mine: mine, partnerName: partnerName, s: s)
        : Text(
            message.text,
            style: TextStyle(
              color: mine ? AppTheme.white : AppTheme.textPrimary,
              fontSize: 15,
              height: 1.35,
            ),
          );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Opacity(
        opacity: message.isPending ? 0.7 : 1,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxW),
          padding: message.type == ChatMessageType.idea
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: message.type == ChatMessageType.idea
                ? Colors.transparent
                : (mine ? AppTheme.accentRose : AppTheme.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            border: message.type == ChatMessageType.idea || mine
                ? null
                : Border.all(color: AppTheme.divider, width: 0.5),
          ),
          child: child,
        ),
      ),
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
                    mine ? s.chatIdeaSharedByYou : s.chatIdeaSharedBy(partnerName.isNotEmpty ? partnerName : s.chatTitleFallback),
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
                  // Reuses the app's tab navigation — Plan is tab 2.
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

// ── Input bar / misc ─────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String sendLabel;
  final bool canSend;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.hint,
    required this.sendLabel,
    required this.canSend,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
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
          IconButton.filled(
            onPressed: canSend ? onSend : null,
            tooltip: sendLabel,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              disabledBackgroundColor: AppTheme.accentRose.withValues(alpha: 0.35),
              foregroundColor: AppTheme.white,
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 22),
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
