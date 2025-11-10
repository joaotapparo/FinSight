import '../models/noticia.dart';

class NoticiasRecomendadasService {
  /// [perfil] é o investor_profile_json salvo no Supabase
  /// [noticias] é a lista original
  static Future<List<Noticia>> ranquearNoticias({
    required Map<String, dynamic> perfil,
    required List<Noticia> noticias,
  }) async {
    // interesses pode vir como List ou como String
    final rawInteresses = perfil['interesses'];
    List<String> interesses = [];

    if (rawInteresses is List) {
      interesses = rawInteresses.map((e) => e.toString().toLowerCase()).toList();
    } else if (rawInteresses is String) {
      interesses = rawInteresses
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (interesses.isEmpty) {
      return noticias;
    }

    // atribui uma nota pra cada notícia
    final scored = noticias.map((n) {
      int score = 0;
      final texto =
          '${n.titulo} ${n.resumo ?? ''} ${n.fonte}'.toLowerCase();

      for (final i in interesses) {
        if (texto.contains(i)) {
          score += 10; // bateu interesse
        }
      }

      // pequeno bônus pra notícias mais novas, se tiver data
      return _ScoredNoticia(noticia: n, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.map((e) => e.noticia).toList();
  }
}

class _ScoredNoticia {
  final Noticia noticia;
  final int score;

  _ScoredNoticia({required this.noticia, required this.score});
}
