import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../models/language_provider.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class AddMemorySheet extends StatefulWidget {
  final String coupleId;
  final String createdBy;
  final String activity;
  final VoidCallback? onDone;

  /// Edit mode: provide the existing doc ID to update instead of creating.
  final String? memoryId;
  final String? initialNote;

  const AddMemorySheet({
    super.key,
    required this.coupleId,
    required this.createdBy,
    required this.activity,
    this.onDone,
    this.memoryId,
    this.initialNote,
  });

  @override
  State<AddMemorySheet> createState() => _AddMemorySheetState();
}

class _AddMemorySheetState extends State<AddMemorySheet> {
  late final TextEditingController _ctrl;
  XFile? _pickedImage;
  bool _saving = false;

  bool get _isEditMode => widget.memoryId != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked != null && mounted) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _delete(AppStrings s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFAF7F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          s.memoriesDeleteTitle,
          style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A)),
        ),
        content: Text(
          s.memoriesDeleteBody,
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
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await StorageService.deleteMemoryImage(widget.coupleId, widget.memoryId!);
      await FirestoreService.deleteMemory(widget.coupleId, widget.memoryId!);
      if (mounted) {
        Navigator.pop(context);
        widget.onDone?.call();
      }
    } catch (e) {
      debugPrint('MEMORY DELETE ERROR: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.memoriesUploadError)),
        );
      }
    }
  }

  Future<void> _save(AppStrings s) async {
    final note = _ctrl.text.trim();
    setState(() => _saving = true);
    try {
      if (_isEditMode) {
        // Edit mode: upload image if picked, update note if changed.
        String? imageUrl;
        if (_pickedImage != null) {
          imageUrl = await StorageService.uploadMemoryImage(
            widget.coupleId,
            widget.memoryId!,
            _pickedImage!,
          );
        }
        final noteChanged = note != (widget.initialNote ?? '');
        if (imageUrl != null || noteChanged) {
          await FirestoreService.updateMemory(
            widget.coupleId,
            widget.memoryId!,
            note: noteChanged ? note : null,
            imageUrl: imageUrl,
          );
        }
      } else {
        // Create mode: always write a new doc.
        final docId = await FirestoreService.addMemory(
          coupleId: widget.coupleId,
          activity: widget.activity,
          note: note,
          createdBy: widget.createdBy,
        );
        if (_pickedImage != null) {
          final url = await StorageService.uploadMemoryImage(
            widget.coupleId,
            docId,
            _pickedImage!,
          );
          await FirestoreService.updateMemoryImageUrl(
              widget.coupleId, docId, url);
        }
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onDone?.call();
      }
    } catch (e) {
      debugPrint('MEMORY UPLOAD ERROR: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.memoriesUploadError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageProvider>().s;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                s.memoriesSheetTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.activity,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 18),
              // Image picker area
              GestureDetector(
                onTap: _saving ? null : _pickImage,
                child: Container(
                  height: _pickedImage != null ? 160 : 80,
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.divider,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: _pickedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _saving
                                    ? null
                                    : () =>
                                        setState(() => _pickedImage = null),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  color: AppTheme.textSecondary, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                s.memoriesAddPhoto,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                minLines: 3,
                maxLines: 6,
                maxLength: 200,
                enabled: !_saving,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.white,
                  hintText: s.memoriesSheetHint,
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(s),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA32D2D),
                    foregroundColor: AppTheme.white,
                    disabledBackgroundColor:
                        const Color(0xFFA32D2D).withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          s.memoriesSave,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _saving ? null : () => _delete(s),
                    child: Text(
                      s.memoriesDeleteButton,
                      style: const TextStyle(
                        color: Color(0xFFA32D2D),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
