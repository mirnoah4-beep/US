import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../theme/app_theme.dart';

class ResolveTogetherScreen extends StatefulWidget {
  const ResolveTogetherScreen({super.key});

  @override
  State<ResolveTogetherScreen> createState() => _ResolveTogetherScreenState();
}

class _ResolveTogetherScreenState extends State<ResolveTogetherScreen> {
  final _ctrlA = TextEditingController();
  final _ctrlB = TextEditingController();
  bool _loading = false;
  String? _response;
  String? _error;

  @override
  void dispose() {
    _ctrlA.dispose();
    _ctrlB.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final a = _ctrlA.text.trim();
    final b = _ctrlB.text.trim();
    if (a.isEmpty || b.isEmpty) return;

    setState(() {
      _loading = true;
      _response = null;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $kOpenAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'max_tokens': 300,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a neutral couples mediator. You never take sides. '
                      'You always validate both partners\' feelings equally and '
                      'suggest a kind, practical compromise. Keep your response '
                      'warm, short, and constructive.',
            },
            {
              'role': 'user',
              'content': 'Partner A says: "$a"\n\nPartner B says: "$b"',
            },
          ],
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _response = data['choices'][0]['message']['content'] as String;
        });
      } else {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } catch (_) {
      setState(() => _error = 'Could not connect. Check your internet.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 60),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 28),
            const Text(
              'Løs det sammen',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'AI tar ikke sider — den lytter likt til begge',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 28),
            _inputCard(
              label: 'Partner A',
              hint: 'Hva synes du?',
              controller: _ctrlA,
            ),
            const SizedBox(height: 12),
            _inputCard(
              label: 'Partner B',
              hint: 'Hva synes du?',
              controller: _ctrlB,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  foregroundColor: AppTheme.white,
                  disabledBackgroundColor:
                      AppTheme.accentRose.withValues(alpha: 0.5),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.white,
                        ),
                      )
                    : const Text(
                        'Send inn svarene',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (_response != null) ...[
              const SizedBox(height: 24),
              _responseCard(_response!),
            ],
            if (_error != null) ...[
              const SizedBox(height: 24),
              _errorCard(_error!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
            ),
            child: const Center(
              child: Icon(Icons.arrow_back_ios_new,
                  size: 15, color: Color(0xFF888888)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputCard({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D9D0), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: AppTheme.accentRose.withValues(alpha: 0.5),
                    width: 1.0),
              ),
              filled: true,
              fillColor: AppTheme.background,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _responseCard(String text) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentRose.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.accentRose, size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'Her er et forslag',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFAECE7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C4B3), width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF993C1D),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
