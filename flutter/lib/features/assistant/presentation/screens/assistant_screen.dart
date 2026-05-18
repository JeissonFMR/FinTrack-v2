import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/constants/app_colors.dart';
import '../providers/assistant_provider.dart';

const _suggestions = [
  '¿Cuánto gasté este mes?',
  '¿En qué categoría gasto más?',
  'Mis 5 transacciones más grandes este mes',
  '¿Cuánto pago en suscripciones?',
  '¿Cómo voy con mis metas?',
  '¿Voy mejor o peor que el mes pasado?',
];

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _partialText = '';
  String? _spanishLocaleId;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (e) {
        // ignore: avoid_print
        print('[STT] Error: ${e.errorMsg} (permanent=${e.permanent})');
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_friendlyError(e.errorMsg)),
              backgroundColor: AppColors.expense,
            ),
          );
        }
      },
      onStatus: (status) {
        // ignore: avoid_print
        print('[STT] Status: $status');
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );

    if (available) {
      // Encontrar mejor locale español disponible
      final locales = await _speech.locales();
      final spanish = locales.firstWhere(
        (l) => l.localeId.startsWith('es'),
        orElse: () => stt.LocaleName('', ''),
      );
      _spanishLocaleId = spanish.localeId.isEmpty ? null : spanish.localeId;
      // ignore: avoid_print
      print('[STT] Locale español elegido: $_spanishLocaleId '
          '(disponibles ES: ${locales.where((l) => l.localeId.startsWith('es')).map((l) => l.localeId).join(", ")})');
    }

    if (mounted) setState(() => _speechAvailable = available);
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'error_no_match':
        return 'No te entendí. Intenta de nuevo más claro o más cerca del mic.';
      case 'error_speech_timeout':
        return 'No escuché nada. Verifica el micrófono.';
      case 'error_audio':
      case 'error_audio_error':
        return 'Error con el micrófono. ¿El emulador tiene acceso al mic del host?';
      case 'error_network':
        return 'Sin conexión a internet para reconocimiento de voz.';
      case 'error_permission':
        return 'Permiso de micrófono denegado.';
      case 'error_busy':
        return 'El reconocedor está ocupado. Espera un momento.';
      default:
        return 'Error de voz: $code';
    }
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Reconocimiento de voz no disponible. Verifica el micrófono y la app de voz de Google.'),
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _partialText = '';
    });

    await _speech.listen(
      localeId: _spanishLocaleId, // null → usa locale por defecto del sistema
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
      ),
      onResult: (result) {
        // ignore: avoid_print
        print('[STT] Result: "${result.recognizedWords}" final=${result.finalResult}');
        setState(() {
          _partialText = result.recognizedWords;
          _inputCtrl.text = result.recognizedWords;
          _inputCtrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _inputCtrl.text.length),
          );
        });
      },
    );
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    if (_isListening) await _speech.stop();
    _inputCtrl.clear();
    setState(() => _partialText = '');
    await ref.read(assistantChatProvider.notifier).ask(text);
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantChatProvider);
    final loading = ref.watch(assistantChatProvider.notifier).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome,
                  size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            const Text('Asistente'),
          ],
        ),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  ref.read(assistantChatProvider.notifier).clear(),
              tooltip: 'Limpiar chat',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(onSuggestion: _send)
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: messages.length + (loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (loading && i == messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(message: messages[i]);
                    },
                  ),
          ),
          _InputBar(
            controller: _inputCtrl,
            onSend: _send,
            enabled: !loading,
            isListening: _isListening,
            partialText: _partialText,
            speechAvailable: _speechAvailable,
            onMicTap: _toggleMic,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ValueChanged<String> onSuggestion;
  const _EmptyState({required this.onSuggestion});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 32, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Pregúntale a tu plata',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hazme cualquier pregunta sobre tus finanzas en lenguaje natural. Tu información nunca se comparte fuera del sistema.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: context.colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'PRUEBA CON ESTAS PREGUNTAS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.colors.textHint,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map(
          (q) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onSuggestion(q),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(q, style: const TextStyle(fontSize: 13)),
                    ),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: context.colors.textHint),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bgColor = isUser
        ? AppColors.primary
        : message.isError
            ? AppColors.expense.withValues(alpha: 0.08)
            : context.colors.surface;
    final fgColor = isUser
        ? Colors.white
        : message.isError
            ? AppColors.expense
            : context.colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: context.colors.border),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: fgColor,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colors.textHint,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Consultando tus datos...',
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSend;
  final bool enabled;
  final bool isListening;
  final String partialText;
  final bool speechAvailable;
  final VoidCallback onMicTap;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.enabled,
    required this.isListening,
    required this.partialText,
    required this.speechAvailable,
    required this.onMicTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isListening) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.expense,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      partialText.isEmpty
                          ? 'Escuchando...'
                          : 'Escuchando: "$partialText"',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !isListening,
                    textInputAction: TextInputAction.send,
                    onSubmitted: enabled ? onSend : null,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Pregúntale algo a tu plata...',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
                if (speechAvailable)
                  IconButton(
                    onPressed: enabled ? onMicTap : null,
                    icon: Icon(
                      isListening ? Icons.stop_circle : Icons.mic_none_rounded,
                    ),
                    color:
                        isListening ? AppColors.expense : AppColors.primary,
                    tooltip: isListening ? 'Detener' : 'Hablar',
                  ),
                IconButton(
                  onPressed: enabled ? () => onSend(controller.text) : null,
                  icon: const Icon(Icons.send_rounded),
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
