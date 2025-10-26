import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/noticia.dart';

class NoticiasService {
  static const String _baseUrl =
      'https://smartcapitalwebscraping-441880730356.us-central1.run.app';
  static const String _endpoint = '/noticias';

  static Future<List<Noticia>> buscarNoticias() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_endpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final String responseBody = response.body;

        try {
          // A API retorna uma string JSON com aspas duplas escapadas
          // Precisamos decodificar duas vezes
          final String unescapedJson = json.decode(responseBody);
          final List<dynamic> jsonList = json.decode(unescapedJson);

          return jsonList.map((json) => Noticia.fromJson(json)).toList();
        } catch (jsonError) {
          // Se falhar o parsing duplo, tenta parsing simples
          final List<dynamic> jsonList = json.decode(responseBody);
          return jsonList.map((json) => Noticia.fromJson(json)).toList();
        }
      } else {
        throw Exception('Erro ao buscar notícias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  static Future<List<Noticia>> buscarNoticiasPorFonte(String fonte) async {
    try {
      final noticias = await buscarNoticias();
      return noticias
          .where(
            (noticia) =>
                noticia.fonte.toLowerCase().contains(fonte.toLowerCase()),
          )
          .toList();
    } catch (e) {
      throw Exception('Erro ao filtrar notícias por fonte: $e');
    }
  }

  static Future<List<Noticia>> buscarNoticiasComResumo() async {
    try {
      final noticias = await buscarNoticias();
      return noticias
          .where(
            (noticia) => noticia.resumo != null && noticia.resumo!.isNotEmpty,
          )
          .toList();
    } catch (e) {
      throw Exception('Erro ao filtrar notícias com resumo: $e');
    }
  }
}
