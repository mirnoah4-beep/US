import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../theme/app_theme.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool isAi;
  final String? senderName;
  const _Msg({required this.text, required this.isAi, this.senderName});
}

enum _Step { names, intro, p1Turn, thinking, p2Turn, done }

// ── Screen ────────────────────────────────────────────────────────────────────

class ResolveTogetherScreen extends StatefulWidget {
  const ResolveTogetherScreen({super.key});

  @override
  State<ResolveTogetherScreen> createState() => _ResolveTogetherScreenState();
}

class _ResolveTogetherScreenState extends State<ResolveTogetherScreen>
    with SingleTickerProviderStateMixin {

  final _n1Ctrl = TextEditingController();
  final _n2Ctrl = TextEditingController();
  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();

  String _name1 = 'Partner 1';
  String _name2 = 'Partner 2';
  final List<_Msg> _msgs = [];
  _Step _step = _Step.names;
  String _p1Msg = '';

  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _n1Ctrl.dispose();
    _n2Ctrl.dispose();
    _inputCtrl.dispose();
    _scroll.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── Logic ─────────────────────────────────────────────────────────────────────

  void _startChat() {
    FocusScope.of(context).unfocus();
    _name1 = _n1Ctrl.text.trim().isEmpty ? 'Partner 1' : _n1Ctrl.text.trim();
    _name2 = _n2Ctrl.text.trim().isEmpty ? 'Partner 2' : _n2Ctrl.text.trim();
    setState(() => _step = _Step.intro);
    _runIntro();
  }

  Future<void> _runIntro() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _push(_Msg(
      isAi: true,
      text: 'Hei dere! Jeg er her for å hjelpe — og jeg tar ikke sider. '
          'Jeg lytter likt til begge. Informasjonen dere deler her blir ikke '
          'lagret — alt slettes automatisk når dere forlater denne samtalen. 🤝',
    ));
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(
        isAi: true,
        text: '$_name1, la oss starte med deg. Hva føler du er urettferdig?',
      ));
      _step = _Step.p1Turn;
    });
    _scrollDown();
  }

  void _send() {
    if (_step == _Step.p1Turn) {
      _sendP1();
    } else if (_step == _Step.p2Turn) {
      _sendP2();
    }
  }

  Future<void> _sendP1() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _p1Msg = text;
    _inputCtrl.clear();
    _push(_Msg(isAi: false, text: text, senderName: _name1));
    setState(() => _step = _Step.thinking);
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(
        isAi: true,
        text: 'Takk $_name1, det hørte jeg. '
            'Nå er det din tur. $_name2, hva føler du?',
      ));
      _step = _Step.p2Turn;
    });
    _scrollDown();
  }

  Future<void> _sendP2() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _push(_Msg(isAi: false, text: text, senderName: _name2));
    setState(() => _step = _Step.thinking);
    await _callApi(_p1Msg, text);
  }

  Future<void> _callApi(String p1, String p2) async {
    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $kOpenAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'max_tokens': 350,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a neutral couples mediator. You never take sides. '
                  'You always validate both partners\' feelings equally and '
                  'suggest a kind, practical compromise. Keep your response '
                  'warm, short, and constructive. Respond in the same language '
                  'the partners used.',
            },
            {
              'role': 'user',
              'content': '$_name1 sier: "$p1"\n\n$_name2 sier: "$p2"',
            },
          ],
        }),
      );
      if (!mounted) return;
      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)['choices'][0]['message']['content'] as String)
          : 'Noe gikk galt. Prøv igjen.';
      setState(() {
        _msgs.add(_Msg(isAi: true, text: reply));
        _step = _Step.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _msgs.add(_Msg(isAi: true, text: 'Kunne ikke koble til. Sjekk internett.'));
        _step = _Step.done;
      });
    }
    _scrollDown();
  }

  void _push(_Msg msg) {
    setState(() => _msgs.add(msg));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool get _inputEnabled => _step == _Step.p1Turn || _step == _Step.p2Turn;

  String get _hint {
    if (_step == _Step.p1Turn) return '$_name1, skriv her…';
    if (_step == _Step.p2Turn) return '$_name2, skriv her…';
    return '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1, thickness: 0.5, color: Color(0xFFE0D9D0)),
            Expanded(
              child: _step == _Step.names
                  ? _buildNamesView()
                  : _buildChatView(),
            ),
            if (_step != _Step.names) _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
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
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 15,
                  color: Color(0xFF888888),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'US',
                style: TextStyle(
                  color: AppTheme.accentRose,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.0,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFAECE7),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFF5C4B3), width: 0.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.balance_outlined, color: Color(0xFF993C1D), size: 13),
                SizedBox(width: 5),
                Text(
                  'Nøytral AI',
                  style: TextStyle(
                    color: Color(0xFF993C1D),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Names view ────────────────────────────────────────────────────────────────

  Widget _buildNamesView() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        const Text(
          'Hvem er dere?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'AI-megleren henvender seg til dere personlig.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _nameField(_n1Ctrl, 'Partner 1 sitt navn'),
        const SizedBox(height: 12),
        _nameField(_n2Ctrl, 'Partner 2 sitt navn'),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: _startChat,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Start samtalen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _nameField(TextEditingController ctrl, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
          border: InputBorder.none,
        ),
        onSubmitted: (_) => _startChat(),
      ),
    );
  }

  // ── Chat view ─────────────────────────────────────────────────────────────────

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      itemCount: _msgs.length + (_step == _Step.thinking ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msgs.length) return _typingBubble();
        return _bubble(_msgs[i]);
      },
    );
  }

  Widget _bubble(_Msg msg) {
    return msg.isAi ? _aiBubble(msg.text) : _userBubble(msg.text, msg.senderName ?? '');
  }

  Widget _aiBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.accentRose,
                      size: 12,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AI-megler',
                      style: TextStyle(
                        color: AppTheme.accentRose,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.zero,
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 56),
        ],
      ),
    );
  }

  Widget _userBubble(String text, String name) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 56),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.accentRose,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.zero,
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: AppTheme.white,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppTheme.accentRose, size: 12),
              SizedBox(width: 4),
              Text(
                'AI-megler',
                style: TextStyle(
                  color: AppTheme.accentRose,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.zero,
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, child) {
                final t = _dotCtrl.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(t, 0),
                    const SizedBox(width: 5),
                    _dot(t, 2 * pi / 3),
                    const SizedBox(width: 5),
                    _dot(t, 4 * pi / 3),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(double t, double phase) {
    final wave = sin(t * 2 * pi + phase);
    final y = -4.0 * (wave > 0 ? wave : 0.0);
    return Transform.translate(
      offset: Offset(0, y),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: AppTheme.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── Input bar ─────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE0D9D0), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE0D9D0), width: 0.5),
              ),
              child: TextField(
                controller: _inputCtrl,
                enabled: _inputEnabled,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                ),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _hint,
                  hintStyle: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _inputEnabled ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _inputEnabled
                    ? AppTheme.accentRose
                    : const Color(0xFFE0D9D0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                color: _inputEnabled ? AppTheme.white : const Color(0xFFB4B2A9),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
