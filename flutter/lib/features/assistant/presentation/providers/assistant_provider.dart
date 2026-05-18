import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime at;

  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    required this.at,
  });
}

class AssistantChatNotifier extends Notifier<List<ChatMessage>> {
  bool _loading = false;
  bool get isLoading => _loading;

  @override
  List<ChatMessage> build() => [];

  void clear() {
    state = [];
  }

  Future<void> ask(String question) async {
    if (question.trim().isEmpty || _loading) return;

    // Agregar mensaje del usuario inmediatamente
    state = [
      ...state,
      ChatMessage(text: question.trim(), isUser: true, at: DateTime.now()),
    ];
    _loading = true;
    ref.notifyListeners();

    try {
      final api = ref.read(apiClientProvider);
      final storage = ref.read(tokenStorageProvider);
      final workspaceId = await storage.getWorkspaceId();
      if (workspaceId == null) {
        _addAssistant('No tengo acceso a tu workspace. Inicia sesión.', isError: true);
        return;
      }

      final res = await api.post(
        '/workspaces/$workspaceId/assistant/ask',
        data: {'question': question.trim()},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final answer = data['answer'] as String? ?? 'No tengo respuesta.';
      final error = data['error'] == true;
      _addAssistant(answer, isError: error);
    } catch (e) {
      _addAssistant(
        'Tuve un problema conectándome. Intenta de nuevo en un momento.',
        isError: true,
      );
    } finally {
      _loading = false;
      ref.notifyListeners();
    }
  }

  void _addAssistant(String text, {bool isError = false}) {
    state = [
      ...state,
      ChatMessage(
        text: text,
        isUser: false,
        isError: isError,
        at: DateTime.now(),
      ),
    ];
  }
}

final assistantChatProvider =
    NotifierProvider<AssistantChatNotifier, List<ChatMessage>>(
        AssistantChatNotifier.new);
