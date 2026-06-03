import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/app_state.dart';
import '../models/language_provider.dart';
import '../models/memories_provider.dart';
import '../models/memory_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_memory_sheet.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    final memories = context.watch<MemoriesProvider>().memories;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          s.memoriesTimelineTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: memories.isEmpty
          ? _buildEmpty(s)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              itemCount: memories.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppTheme.divider),
              itemBuilder: (ctx, i) {
                final memory = memories[i];
                return Dismissible(
                  key: ValueKey(memory.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => _showDeleteConfirm(ctx, memory, s),
                  onDismissed: (_) {
                    final coupleId = ctx.read<AppState>().coupleId;
                    StorageService.deleteMemoryImage(coupleId, memory.id);
                    FirestoreService.deleteMemory(coupleId, memory.id);
                  },
                  background: const SizedBox.shrink(),
                  secondaryBackground: Container(
                    color: const Color(0xFFD32F2F),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_rounded,
                        color: Colors.white, size: 24),
                  ),
                  child: _MemoryRow(
                    memory: memory,
                    s: s,
                    onTap: () => _handleTap(ctx, memory, s),
                  ),
                );
              },
            ),
    );
  }

  Future<bool?> _showDeleteConfirm(
      BuildContext context, MemoryModel memory, AppStrings s) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F4),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.memoriesDeleteTitle,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A)),
        ),
        content: Text(
          s.readableActivity(memory.activity),
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.memoriesDeleteCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(s.memoriesDeleteConfirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context, MemoryModel memory, AppStrings s) {
    if (memory.imageUrl == null) {
      final appState = context.read<AppState>();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddMemorySheet(
          coupleId: appState.coupleId,
          createdBy: appState.userId,
          activity: s.readableActivity(memory.activity),
          memoryId: memory.id,
          initialNote: memory.note,
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _MemoryDetailScreen(memory: memory, s: s),
        ),
      );
    }
  }

  Widget _buildEmpty(AppStrings s) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            s.memoriesTimelineEmpty,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.memoriesTimelineEmptySub,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  final MemoryModel memory;
  final AppStrings s;
  final VoidCallback onTap;

  const _MemoryRow({
    required this.memory,
    required this.s,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = memory.imageUrl != null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5F2),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.hardEdge,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: memory.imageUrl!,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 200),
                      errorWidget: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppTheme.textMuted),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined,
                      color: Color(0xFFA32D2D), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.readableActivity(memory.activity),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.memoriesRelativeDate(memory.createdAt),
                        style: const TextStyle(
                          color: AppTheme.textSubtle,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (memory.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      memory.note,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                    Text(
                      s.memoriesAddPhoto,
                      style: const TextStyle(
                        color: Color(0xFFA32D2D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              hasImage
                  ? Icons.chevron_right_rounded
                  : Icons.add_photo_alternate_outlined,
              color: hasImage ? AppTheme.textMuted : const Color(0xFFA32D2D),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryDetailScreen extends StatelessWidget {
  final MemoryModel memory;
  final AppStrings s;

  const _MemoryDetailScreen({required this.memory, required this.s});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (memory.imageUrl != null)
            CachedNetworkImage(
              imageUrl: memory.imageUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 300),
            )
          else
            const Center(
              child: Icon(Icons.photo_library_outlined,
                  color: Colors.white38, size: 72),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                  stops: [0.0, 0.65],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.readableActivity(memory.activity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Georgia',
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.memoriesRelativeDate(memory.createdAt),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (memory.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      memory.note,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
