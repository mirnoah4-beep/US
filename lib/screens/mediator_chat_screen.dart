import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/secrets.dart';
import '../models/app_state.dart';
import '../theme/app_theme.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _kPurpleBg = Color(0xFFEEEDFE);
const _kPurple = Color(0xFF534AB7);
const _kNoahBubble = Color(0xFFC1544A);
const _kSarahBubble = Color(0xFF3B6D11);
const _kBorder = Color(0xFFE0D9D0);

// ── Model ─────────────────────────────────────────────────────────────────────

enum _Sender { ai, user1, user2 }

class _ChatMsg {
  final _Sender sender;
  String text;
  _ChatMsg({required this.sender, required this.text});
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MediatorChatScreen extends StatefulWidget {
  const MediatorChatScreen({super.key});

  @override
  State<MediatorChatScreen> createState() => _MediatorChatScreenState();
}

class _MediatorChatScreenState extends State<MediatorChatScreen>
    with TickerProviderStateMixin {
  final List<_ChatMsg> _msgs = [];
  bool _typing = false;
  bool _chipsVisible = false;
  bool _inputEnabled = false;
  http.Client? _httpClient;

  final _inputCtrl = TextEditingController();
  final _scroll = ScrollController();
  late final AnimationController _dotCtrl;

  // Names come from AppState — read once in initState
  late final String _name1;
  late final String _name2;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    final appState = context.read<AppState>();
    _name1 = appState.displayName;
    _name2 = appState.partnerName;

    WidgetsBinding.instance.addPostFrameCallback((_) => _sendGreeting());
  }

  @override
  void dispose() {
    _httpClient?.close();
    _inputCtrl.dispose();
    _scroll.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // ── Greeting ─────────────────────────────────────────────────────────────────

  Future<void> _sendGreeting() async {
    setState(() => _typing = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _typing = false;
      _msgs.add(_ChatMsg(
        sender: _Sender.ai,
        text: 'Hei. Jeg er her for å hjelpe dere finne frem\ntil hverandre. Hva vil dere snakke om?',
      ));
      _chipsVisible = true;
      _inputEnabled = true;
    });
    _scrollDown();
  }

  // ── Send ──────────────────────────────────────────────────────────────────────

  void _onChipTap(String text) {
    setState(() => _chipsVisible = false);
    _sendMessage(text);
  }

  void _onSend() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || !_inputEnabled) return;
    _inputCtrl.clear();
    _sendMessage(text);
  }

  Future<void> _sendMessage(String text) async {
    setState(() {
      _msgs.add(_ChatMsg(sender: _Sender.user1, text: text));
      _chipsVisible = false;
      _inputEnabled = false;
      _typing = true;
    });
    _scrollDown();
    await _streamResponse();
  }

  // ── OpenAI streaming ─────────────────────────────────────────────────────────

  String _systemPrompt() {
    return 'Du er en varm og nøytral samtalepartner som hjelper et par '
        'å forstå hverandre bedre. Parret heter $_name1 og $_name2.\n\n'
        'Regler du alltid følger:\n'
        '- Skriv alltid på perfekt, naturlig norsk bokmål\n'
        '- Aldri bryt av setninger midt i\n'
        '- Hold svarene korte — maks 2-3 setninger\n'
        '- Still ett spørsmål av gangen\n'
        '- Vær varm, rolig og nøytral — ta aldri side\n'
        '- Hjelp dem finne felles grunn\n'
        '- Ikke bruk engelske ord eller uttrykk';
  }

  List<Map<String, String>> _buildHistory() {
    final history = <Map<String, String>>[];
    for (final msg in _msgs) {
      final role = msg.sender == _Sender.ai ? 'assistant' : 'user';
      final prefix = msg.sender == _Sender.user2 ? '$_name2: ' : '';
      history.add({'role': role, 'content': '$prefix${msg.text}'});
    }
    return history;
  }

  Future<void> _streamResponse() async {
    _httpClient = http.Client();
    try {
      final response = await _httpClient!.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $kOpenAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'max_tokens': 300,
          'messages': [
            {'role': 'system', 'content': _systemPrompt()},
            ..._buildHistory(),
          ],
        }),
      );
      if (!mounted) return;
      final String reply;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        reply = decoded['choices'][0]['message']['content'] as String? ??
            'Beklager, noe gikk galt. Prøv igjen.';
      } else {
        reply = 'Beklager, noe gikk galt. Prøv igjen.';
      }
      setState(() {
        _typing = false;
        _msgs.add(_ChatMsg(sender: _Sender.ai, text: reply.trim()));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_ChatMsg(
            sender: _Sender.ai,
            text: 'Kunne ikke koble til. Sjekk internettforbindelsen.'));
      });
    } finally {
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() => _inputEnabled = true);
        _scrollDown();
      }
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────────

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Leave dialog ─────────────────────────────────────────────────────────────

  Future<bool> _confirmLeave() async {
    if (_msgs.length <= 1) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Avslutte samtalen?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'Samtalen slettes når du går ut og kan ikke gjenopprettes.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.45,
          ),
        ),
        actionsPadding: EdgeInsets.zero,
        actions: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentRose,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Fortsett samtalen',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB4B2A9),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Avslutt og slett',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmLeave();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const Divider(height: 1, thickness: 0.5, color: _kBorder),
              Expanded(child: _buildChatList()),
              _buildInputRow(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final shouldPop = await _confirmLeave();
              if (shouldPop && context.mounted) Navigator.pop(context);
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.white,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder, width: 0.5),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new,
                    size: 15, color: Color(0xFF888888)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _kPurpleBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.handshake_outlined, size: 18, color: _kPurple),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hjelp oss',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Privat · bare dere to',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF888888),
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kPurpleBg,
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'Privat',
              style: TextStyle(
                color: _kPurple,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chat list ─────────────────────────────────────────────────────────────────

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      itemCount: _msgs.length + (_typing ? 1 : 0) + (_chipsVisible ? 1 : 0),
      itemBuilder: (_, i) {
        if (_typing && i == _msgs.length) return _typingBubble();
        if (_chipsVisible) {
          final chipsIndex = _msgs.length + (_typing ? 1 : 0);
          if (i == chipsIndex) return _quickChips();
        }
        final msg = _msgs[i];
        return switch (msg.sender) {
          _Sender.ai => _aiBubble(msg.text),
          _Sender.user1 => _userBubble(msg.text, _name1, _kNoahBubble),
          _Sender.user2 => _userBubble(msg.text, _name2, _kSarahBubble),
        };
      },
    );
  }

  Widget _aiBubble(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: const BoxDecoration(
              color: _kPurpleBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.handshake_outlined, size: 14, color: _kPurple),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppTheme.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(color: _kBorder, width: 0.8),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A1A1A),
                  height: 1.45,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _userBubble(String text, String name, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(width: 56),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, right: 2),
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: const BoxDecoration(
              color: _kPurpleBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.handshake_outlined, size: 14, color: _kPurple),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: _kBorder, width: 0.8),
            ),
            child: AnimatedBuilder(
              animation: _dotCtrl,
              builder: (context, child) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final phase =
                      ((_dotCtrl.value - i / 7.0) % 1.0 + 1.0) % 1.0;
                  final opacity = 0.25 + 0.75 * sin(phase * pi).abs();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _kPurple.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickChips() {
    const chips = [
      'Vi er uenige om noe',
      'Vi klarer ikke bestemme oss',
      'Vi trenger å snakke sammen',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips
            .map(
              (label) => GestureDetector(
                onTap: () => _onChipTap(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accentRose, width: 1.2),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.accentRose,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Input ─────────────────────────────────────────────────────────────────────

  Widget _buildInputRow(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 0.5, color: _kBorder),
        Padding(
          padding: EdgeInsets.only(
            left: 14,
            right: 14,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom > 0
                ? 10
                : 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: _inputEnabled,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Skriv her…',
                      hintStyle: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                      filled: true,
                      fillColor: AppTheme.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide:
                            const BorderSide(color: _kBorder, width: 0.8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide:
                            const BorderSide(color: _kBorder, width: 0.8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: AppTheme.accentRose, width: 1.2),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide:
                            const BorderSide(color: _kBorder, width: 0.8),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _inputEnabled ? _onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _inputEnabled
                        ? AppTheme.accentRose
                        : AppTheme.accentRose.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child:
                        Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Samtalen er privat og blir ikke lagret',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFB4B2A9),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
