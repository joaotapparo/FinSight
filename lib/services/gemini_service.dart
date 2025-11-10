import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static Future<Map<String, dynamic>> montarPerfil(List<Map<String, String>> chatHistory) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY não encontrada no .env');
    }

    // Junta todas as perguntas e respostas da conversa
    final buffer = StringBuffer();
    for (final msg in chatHistory) {
      buffer.writeln("${msg['role']}: ${msg['content']}");
    }

    final prompt = """
Você é um assistente que cria perfis de investidores personalizados.
Com base na conversa abaixo, devolva APENAS um JSON com este formato:

{
  "tipoInvestidor": "...",
  "interesses": ["...", "..."],
  "profissaoOuSetor": "...",
  "descricaoResumida": "..."
}

Conversa:
$buffer
""";

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$apiKey",
    );

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {"text": prompt}
          ]
        }
      ]
    });

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Erro no Gemini: ${response.body}');
    }

    final data = jsonDecode(response.body);

    // Segurança extra: verifica se há candidato e texto válido
    if (data["candidates"] == null || data["candidates"].isEmpty) {
      throw Exception('Nenhum resultado retornado pelo Gemini.');
    }

    final content = data["candidates"][0]["content"]["parts"][0]["text"];

    // 🔹 Extrai apenas o JSON do texto retornado
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start == -1 || end == -1) {
      throw Exception('Resposta inesperada do Gemini: $content');
    }

    final jsonText = content.substring(start, end + 1);

    return jsonDecode(jsonText);
  }
}
