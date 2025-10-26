class Noticia {
  final String id;
  final String titulo;
  final String link;
  final String? resumo;
  final String fonte;
  final DateTime? dataColeta;

  Noticia({
    required this.id,
    required this.titulo,
    required this.link,
    this.resumo,
    required this.fonte,
    this.dataColeta,
  });

  factory Noticia.fromJson(Map<String, dynamic> json) {
    return Noticia(
      id: json['_id'] ?? '',
      titulo: json['titulo'] ?? '',
      link: json['link'] ?? '',
      resumo: json['resumo'],
      fonte: json['fonte'] ?? '',
      dataColeta: json['data_coleta'] != null
          ? DateTime.tryParse(json['data_coleta']['\$date'] ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'titulo': titulo,
      'link': link,
      'resumo': resumo,
      'fonte': fonte,
      'data_coleta': dataColeta != null
          ? {'\$date': dataColeta!.toIso8601String()}
          : null,
    };
  }

  String get dataFormatada {
    if (dataColeta == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dataColeta!);

    if (difference.inDays > 0) {
      return '${difference.inDays} dia${difference.inDays > 1 ? 's' : ''} atrás';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hora${difference.inHours > 1 ? 's' : ''} atrás';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''} atrás';
    } else {
      return 'Agora mesmo';
    }
  }
}
