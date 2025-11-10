import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/gemini_service.dart';

class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});

  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // cada msg: { "role": "assistant" | "user", "content": "..." }
  final List<Map<String, String>> _messages = [];

  bool _isLoading = false;
  bool _finished = false;

  // perguntas fixas da Fin
  final List<String> _perguntas = [
    "Oi! 👋 Eu sou a Fin, sua assistente da Finsight. Pra te recomendar notícias melhores, me conta: em que área você trabalha ou tem mais interesse? (ex: agronegócio, tecnologia, cripto, imóveis...)",
    "Legal 😄. E sobre investimentos: você prefere mais segurança ou aceita mais risco se o retorno for maior?",
    "Show! Agora me fala: quanto tempo você costuma deixar um investimento antes de resgatar? (ex: curto prazo, 1 ano, longo prazo...)",
    "Última pergunta: que tipos de notícias do mercado você gostaria de receber com mais frequência? (ex: soja, cripto, imóveis, startups, mercado externo...)"
  ];

  @override
  void initState() {
    super.initState();
    // primeira fala da Fin
    _messages.add({
      "role": "assistant",
      "content": _perguntas.first,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _finished) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _controller.clear();
    });
    _scrollToBottom();

    final respostasUsuario =
        _messages.where((m) => m['role'] == 'user').length;

    if (respostasUsuario >= _perguntas.length) {
      await _finalizarPerfil();
      return;
    }

    setState(() {
      _messages.add({
        "role": "assistant",
        "content": _perguntas[respostasUsuario],
      });
    });
    _scrollToBottom();
  }

  // fallback se o Gemini não devolver JSON
  Map<String, dynamic> _montarPerfilFallback() {
    // pega só as respostas do usuário na ordem
    final respostas =
        _messages.where((m) => m['role'] == 'user').map((m) => m['content']!).toList();

    final area = respostas.isNotEmpty ? respostas[0] : 'mercado financeiro';
    final risco =
        respostas.length > 1 ? respostas[1].toLowerCase() : 'segurança';
    final horizonte = respostas.length > 2 ? respostas[2] : 'médio prazo';
    final interesses = respostas.length > 3 ? respostas[3] : 'notícias gerais';

    String tipoInvestidor;
    if (risco.contains('seguran')) {
      tipoInvestidor = 'conservador';
    } else if (risco.contains('mais risco') ||
        risco.contains('arroj') ||
        risco.contains('alto')) {
      tipoInvestidor = 'arrojado';
    } else {
      tipoInvestidor = 'moderado';
    }

    return {
      "tipoInvestidor": tipoInvestidor,
      "area": area,
      "horizonte": horizonte,
      "interesses": interesses
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      "origem": "fallback",
    };
  }

  Future<void> _finalizarPerfil() async {
    setState(() => _isLoading = true);

    Map<String, dynamic> perfil;

    try {
      // 1) tenta o Gemini
      perfil = await GeminiService.montarPerfil(_messages);
      // se chegar aqui, beleza
    } catch (e) {
      // 2) se der ruim no Gemini, monta você mesmo
      perfil = _montarPerfilFallback();
      debugPrint('Gemini falhou, usando fallback: $e');
    }

    // 3) tenta salvar no Supabase SEMPRE
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception("Usuário não autenticado.");
      }

      await supabase.from('profiles').upsert({
        'id': user.id,
        'role': 'user',
        'investor_profile': perfil['tipoInvestidor'],
        'investor_profile_json': perfil,
      });

      setState(() {
        final interesses = (perfil['interesses'] is List)
            ? (perfil['interesses'] as List).join(', ')
            : '';
        _messages.add({
          "role": "assistant",
          "content":
              "Perfeito! 🟢 Montei seu perfil como **${perfil['tipoInvestidor']}**.\n"
                  "Vou priorizar notícias sobre: ${interesses.isNotEmpty ? interesses : 'os temas que você citou'}.\n"
                  "Pode mudar isso depois nas configurações."
        });
        _finished = true;
      });
    } on PostgrestException catch (e) {
      // erro do Supabase (RLS, etc.)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Supabase não deixou salvar: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _messages.add({
          "role": "assistant",
          "content":
              "Consegui entender seu perfil, mas não deu pra salvar agora 😢.\nMensagem técnica: ${e.message}"
        });
      });
    } catch (e) {
      // erro inesperado
      setState(() {
        _messages.add({
          "role": "assistant",
          "content":
              "Não consegui montar o perfil agora 😢. Tenta de novo mais tarde."
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu perfil FinSight'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Colors.pinkAccent
                          : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          if (!_finished)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      hintText: 'Digite sua resposta...',
                      contentPadding: EdgeInsets.all(8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                icon: const Icon(Icons.home),
                label: const Text('Ir para Home'),
              ),
            )
        ],
      ),
    );
  }
}
