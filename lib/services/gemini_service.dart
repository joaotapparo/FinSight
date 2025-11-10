import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  static Future<Map<String, dynamic>> montarPerfil(List<Map<String, String>> chatHistory) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY não encontrada no .env');
    }

    // junta todas as perguntas e respostas
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
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey",
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
    final content = data["candidates"][0]["content"]["parts"][0]["text"];

    // pode vir texto extra, tenta achar só o JSON
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    final jsonText = content.substring(start, end + 1);

    return jsonDecode(jsonText);
  }
}
