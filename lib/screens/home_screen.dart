import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/noticia.dart';
import '../services/noticias_service.dart';
import 'onboarding_chat_screen.dart';
import '../services/user_profile_service.dart';
import '../services/noticias_recomendadas_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    Key? key,
    required this.onToggleTheme,
    required this.isDark,
  }) : super(key: key);

  final VoidCallback onToggleTheme;
  final bool isDark;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // estado de notícias
  List<Noticia> _noticias = [];
  List<Noticia> _noticiasOriginais = [];
  bool _isLoading = true;
  String? _error;

  // filtro por fonte (menu ... )
  String _filtroFonte = 'Todas';

  // perfil da Fin
  Map<String, dynamic>? _perfilFin;
  bool _isAdmin = false;

  // chips de categorias
  String? _categoriaSelecionada;
  List<String> _categorias = [];

  // paleta base (dark)
  final Color _bgDark = const Color(0xFF0D0D0D);
  final Color _cardDark = const Color(0xFF141414);
  final Color _neon = const Color(0xFF00FFA3);
  final Color _cyan = const Color(0xFF00BFFF);

  Color get _background =>
      widget.isDark ? _bgDark : const Color(0xFFF5F6F7);
  Color get _cardColor => widget.isDark ? _cardDark : Colors.white;
  Color get _textPrimary =>
      widget.isDark ? Colors.white : const Color(0xFF0D0D0D);
  Color get _textSecondary =>
      widget.isDark ? Colors.white70 : const Color(0xFF4D4D4D);

  @override
  void initState() {
    super.initState();
    _carregarTudo();
  }

  Future<void> _carregarTudo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. carrega perfil do usuário
      final perfil = await UserProfileService.getCurrentUserProfile();

      // se não tem perfil ou não tem json → manda pra Fin
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      Map<String, dynamic>? row;
      if (user != null) {
        row = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      }

      if (row == null || row['investor_profile_json'] == null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const OnboardingChatScreen(),
            ),
          );
        }
        return;
      }

      // pegar role pra saber se é admin
      final role = row['role'] as String? ?? 'user';
      _isAdmin = role == 'admin';

      _perfilFin = row['investor_profile_json'] as Map<String, dynamic>?;

      // montar categorias (pego dos interesses do perfil)
      _categorias = _montarCategorias(_perfilFin);
      if (_categorias.isNotEmpty) {
        _categoriaSelecionada = _categorias.first;
      }

      // 2. carrega notícias
      final noticias = await NoticiasService.buscarNoticias();

      // 3. se tiver perfil, ranqueia
      List<Noticia> noticiasFinais = noticias;
      if (perfil != null) {
        noticiasFinais = await NoticiasRecomendadasService.ranquearNoticias(
          perfil: perfil,
          noticias: noticias,
        );
      }

      setState(() {
        _noticias = noticiasFinais;
        _noticiasOriginais = noticiasFinais;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> _montarCategorias(Map<String, dynamic>? perfil) {
    if (perfil == null) return [];
    final interesses = perfil['interesses'];
    if (interesses is List) {
      return interesses.map((e) => e.toString()).toList();
    }
    if (interesses is String) {
      return interesses.split(',').map((e) => e.trim()).toList();
    }
    return [];
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

      // mantém ordenação da IA
      final perfil = await UserProfileService.getCurrentUserProfile();
      if (perfil != null) {
        noticias = await NoticiasRecomendadasService.ranquearNoticias(
          perfil: perfil,
          noticias: noticias,
        );
      }

      setState(() {
        _noticias = noticias;
        _noticiasOriginais = noticias;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filtrarPorCategoria(String? categoria) {
    setState(() {
      _categoriaSelecionada = categoria;
      if (categoria == null) {
        _noticias = List.from(_noticiasOriginais);
      } else {
        _noticias = _noticiasOriginais
            .where(
              (n) =>
                  n.titulo.toLowerCase().contains(categoria.toLowerCase()) ||
                  (n.resumo ?? '')
                      .toLowerCase()
                      .contains(categoria.toLowerCase()) ||
                  n.fonte.toLowerCase().contains(categoria.toLowerCase()),
            )
            .toList();
      }
    });
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
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            // logo
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: _cyan.withOpacity(.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/finsight_logo.png',
                fit: BoxFit.cover,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FinSight',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'notícias inteligentes',
                  style: TextStyle(
                    color: _textPrimary.withOpacity(.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // tema
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isDark
                  ? Icons.wb_sunny_outlined
                  : Icons.dark_mode_outlined,
              color: _textPrimary,
            ),
            tooltip: widget.isDark ? 'Modo claro' : 'Modo escuro',
          ),
          IconButton(
            onPressed: _carregarTudo,
            icon: Icon(Icons.refresh, color: _textPrimary),
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: _textPrimary),
            onSelected: _filtrarPorFonte,
            itemBuilder: (context) => _obterFontesUnicas().map((fonte) {
              return PopupMenuItem<String>(
                value: fonte,
                child: Row(
                  children: [
                    if (fonte == _filtroFonte)
                      Icon(Icons.check, color: _cyan, size: 18),
                    const SizedBox(width: 6),
                    Text(fonte),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: _textPrimary),
            tooltip: 'Sair',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _neon),
            const SizedBox(height: 16),
            Text(
              'Carregando notícias...',
              style: TextStyle(color: _textPrimary),
            ),
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
              style: TextStyle(color: _textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarTudo,
              style: ElevatedButton.styleFrom(backgroundColor: _neon),
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carregarTudo,
      color: _neon,
      backgroundColor: _background,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildPerfilCard(),
          const SizedBox(height: 12),
          _buildChipsCategorias(),
          const SizedBox(height: 12),
          Text(
            'Destaques pra você',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ..._noticias.map(_buildNoticiaCard).toList(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPerfilCard() {
    final tipo = _perfilFin?['tipoInvestidor']?.toString() ?? 'desconhecido';
    final interesses = _perfilFin?['interesses'];
    String interessesStr = '';
    if (interesses is List) {
      interessesStr = interesses.join(', ');
    } else if (interesses is String) {
      interessesStr = interesses;
    }

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt, color: widget.isDark ? Colors.amber : Colors.amber[700], size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fin te conhece assim 👇',
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perfil: $tipo',
                  style: TextStyle(color: _textSecondary, fontSize: 12),
                ),
                if (interessesStr.isNotEmpty)
                  Text(
                    'Interesses: $interessesStr',
                    style: TextStyle(color: _textSecondary, fontSize: 11.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingChatScreen(),
                ),
              );
            },
            icon: Icon(Icons.edit, color: _textSecondary, size: 18),
          ),
          if (_isAdmin)
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, '/admin-profiles');
              },
              style: TextButton.styleFrom(
                backgroundColor: _cyan.withOpacity(.12),
                foregroundColor: _textPrimary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              child: const Text(
                'ADMIN',
                style: TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChipsCategorias() {
    if (_categorias.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categorias[index];
          final bool ativo = cat == _categoriaSelecionada;
          return GestureDetector(
            onTap: () => _filtrarPorCategoria(ativo ? null : cat),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: ativo ? _neon : Colors.transparent,
                border: Border.all(
                  color: ativo ? Colors.transparent : _textPrimary.withOpacity(.25),
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  color: ativo ? Colors.black : _textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoticiaCard(Noticia noticia) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: () => _abrirLink(noticia.link),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _cyan.withOpacity(.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      noticia.fonte,
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (noticia.dataFormatada.isNotEmpty)
                    Text(
                      noticia.dataFormatada,
                      style: TextStyle(
                        color: _textSecondary.withOpacity(.5),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                noticia.titulo,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (noticia.resumo != null && noticia.resumo!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  noticia.resumo!,
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.open_in_new,
                      size: 16, color: _neon.withOpacity(.8)),
                  const SizedBox(width: 4),
                  Text(
                    'Ler mais',
                    style: TextStyle(
                      color: _neon.withOpacity(.8),
                      fontWeight: FontWeight.w500,
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
