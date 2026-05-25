import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/secrets.dart';
import '../theme/app_theme.dart';

// Logged-in user + partner — replace with real auth data when available
const _p1Name = 'Noah';
const _p2Name = 'Alex';

const _kSystemPrompt =
    'You are Tom Arne, a warm, super positive and always happy couples mediator. '
    'You have a big heart and genuinely care about both partners. You never take '
    'sides — ever. You always validate both partners\' feelings equally and make '
    'both feel heard and respected. You give creative, practical and uplifting '
    'ideas to solve their problems. You help them see things from completely '
    'different perspectives they may not have considered. You are never negative, '
    'never judgmental, and always find something positive in what both partners '
    'say. Your tone is like a wise, warm friend — not a therapist or a robot. '
    'Keep responses short, warm, and constructive. Always end with an uplifting '
    'and hopeful message about their relationship. Respond in the same language '
    'the partners used.';

// ── Types ─────────────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool isAi;
  final String? sender;
  const _Msg({required this.text, required this.isAi, this.sender});
}

enum _Phase {
  p1Turn,   // Partner 1 typing
  p1Done,   // Tom Arne responding to P1
  notif,    // In-app notification showing
  p2Intro,  // Tom Arne greeting P2
  p2Turn,   // Partner 2 typing
  thinking, // API call in progress
  done,
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ResolveTogetherScreen extends StatefulWidget {
  const ResolveTogetherScreen({super.key});

  @override
  State<ResolveTogetherScreen> createState() => _ResolveTogetherScreenState();
}

class _ResolveTogetherScreenState extends State<ResolveTogetherScreen>
    with TickerProviderStateMixin {

  final List<_Msg> _msgs = [];
  _Phase _phase = _Phase.p1Turn;
  String _p1Msg = '';
  bool _tomTyping = false;
  bool _showNotif = false;

  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  late final AnimationController _dotCtrl;
  late final AnimationController _notifCtrl;
  late final Animation<Offset> _notifSlide;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _notifCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _notifSlide = Tween<Offset>(
      begin: const Offset(0, -1.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _notifCtrl, curve: Curves.easeOutCubic));

    _runP1Intro();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scroll.dispose();
    _dotCtrl.dispose();
    _notifCtrl.dispose();
    super.dispose();
  }

  // ── Flow ──────────────────────────────────────────────────────────────────────

  Future<void> _runP1Intro() async {
    setState(() => _tomTyping = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _tomTyping = false);
    _push(_Msg(
      isAi: true,
      text: 'Hei $_p1Name! Jeg er her for å hjelpe dere å finne midten — '
          'og jeg tar ikke sider. Informasjonen dere deler her blir ikke lagret '
          'og slettes automatisk når dere forlater samtalen. 🤝 '
          'Hva føler du er urettferdig?',
    ));
  }

  Future<void> _sendP1() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _p1Msg = text;
    _inputCtrl.clear();
    _push(_Msg(isAi: false, text: text, sender: _p1Name));
    setState(() {
      _phase = _Phase.p1Done;
      _tomTyping = true;
    });
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _tomTyping = false);
    _push(_Msg(
      isAi: true,
      text: 'Takk $_p1Name, jeg hørte deg. '
          'Jeg sender dette videre til $_p2Name nå — de får beskjed om å komme inn.',
    ));
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _phase = _Phase.notif;
      _showNotif = true;
    });
    _notifCtrl.forward();
  }

  Future<void> _p2Join() async {
    await _notifCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _showNotif = false;
      _phase = _Phase.p2Intro;
      _tomTyping = true;
    });
    _scrollDown();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _tomTyping = false);
    _push(_Msg(
      isAi: true,
      text: 'Hei $_p2Name! $_p1Name har delt noe med meg. '
          'Jeg har lyttet til dem — nå vil jeg høre din side. Hva føler du?',
    ));
    setState(() => _phase = _Phase.p2Turn);
  }

  Future<void> _sendP2() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    _push(_Msg(isAi: false, text: text, sender: _p2Name));
    setState(() {
      _phase = _Phase.thinking;
      _tomTyping = true;
    });
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
          'max_tokens': 400,
          'messages': [
            {'role': 'system', 'content': _kSystemPrompt},
            {
              'role': 'user',
              'content': '$_p1Name sier: "$p1"\n\n$_p2Name sier: "$p2"',
            },
          ],
        }),
      );
      if (!mounted) return;
      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)['choices'][0]['message']['content'] as String)
          : 'Noe gikk galt. Prøv igjen om litt.';
      setState(() {
        _tomTyping = false;
        _msgs.add(_Msg(isAi: true, text: reply));
        _phase = _Phase.done;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tomTyping = false;
        _msgs.add(_Msg(isAi: true, text: 'Kunne ikke koble til. Sjekk internett.'));
        _phase = _Phase.done;
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

  void _send() {
    if (_phase == _Phase.p1Turn) {
      _sendP1();
    } else if (_phase == _Phase.p2Turn) {
      _sendP2();
    }
  }

  bool get _inputEnabled =>
      _phase == _Phase.p1Turn || _phase == _Phase.p2Turn;

  String get _hint {
    if (_phase == _Phase.p1Turn) return '$_p1Name, skriv her…';
    if (_phase == _Phase.p2Turn) return '$_p2Name, skriv her…';
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
              child: Stack(
                children: [
                  _buildChatView(),
                  if (_showNotif)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SlideTransition(
                        position: _notifSlide,
                        child: _buildNotifBanner(),
                      ),
                    ),
                ],
              ),
            ),
            _buildInputBar(),
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
                  'Tom Arne · Nøytral',
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

  // ── Chat ──────────────────────────────────────────────────────────────────────

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      itemCount: _msgs.length + (_tomTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _msgs.length) return _typingBubble();
        final msg = _msgs[i];
        return msg.isAi
            ? _aiBubble(msg.text)
            : _userBubble(msg.text, msg.sender ?? '');
      },
    );
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
                      'Tom Arne',
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
              Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.accentRose,
                size: 12,
              ),
              SizedBox(width: 4),
              Text(
                'Tom Arne',
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
        decoration: const BoxDecoration(
          color: AppTheme.textMuted,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── In-app notification banner ─────────────────────────────────────────────────

  Widget _buildNotifBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F0),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFAC775), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFAEEDA),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🤝', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_p1Name vil løse noe sammen med deg.',
                    style: const TextStyle(
                      color: Color(0xFF2C2420),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Tom Arne venter 🤝',
                    style: TextStyle(
                      color: Color(0xFF854F0B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _p2Join,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.accentRose,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Kom inn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
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
                color:
                    _inputEnabled ? AppTheme.white : const Color(0xFFB4B2A9),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
