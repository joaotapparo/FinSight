import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/noticia.dart';
import '../services/noticias_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Noticia> _noticias = [];
  bool _isLoading = true;
  String? _error;
  String _filtroFonte = 'Todas';

  @override
  void initState() {
    super.initState();
    _carregarNoticias();
  }

  Future<void> _carregarNoticias() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final noticias = await NoticiasService.buscarNoticias();
      setState(() {
        _noticias = noticias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _filtrarPorFonte(String fonte) async {
    setState(() {
      _filtroFonte = fonte;
      _isLoading = true;
    });

    try {
      List<Noticia> noticias;
      if (fonte == 'Todas') {
        noticias = await NoticiasService.buscarNoticias();
      } else {
        noticias = await NoticiasService.buscarNoticiasPorFonte(fonte);
      }

      setState(() {
        _noticias = noticias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o link'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<String> _obterFontesUnicas() {
    final fontes = _noticias.map((n) => n.fonte).toSet().toList();
    fontes.sort();
    return ['Todas', ...fontes];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finsight - Notícias'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarNoticias,
          ),
          PopupMenuButton<String>(
            onSelected: _filtrarPorFonte,
            itemBuilder: (context) => _obterFontesUnicas().map((fonte) {
              return PopupMenuItem<String>(
                value: fonte,
                child: Row(
                  children: [
                    if (fonte == _filtroFonte)
                      const Icon(Icons.check, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(fonte),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando notícias...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erro ao carregar notícias',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarNoticias,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    if (_noticias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.newspaper, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhuma notícia encontrada'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarNoticias,
      child: Column(
        children: [
          if (_filtroFonte != 'Todas')
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.deepPurple.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Filtrado por: $_filtroFonte',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _filtrarPorFonte('Todas'),
                    child: const Text('Limpar Filtro'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _noticias.length,
              itemBuilder: (context, index) {
                final noticia = _noticias[index];
                return _buildNoticiaCard(noticia);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoticiaCard(Noticia noticia) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _abrirLink(noticia.link),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      noticia.fonte,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (noticia.dataFormatada.isNotEmpty)
                    Text(
                      noticia.dataFormatada,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                noticia.titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (noticia.resumo != null && noticia.resumo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  noticia.resumo!,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Ler mais',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
