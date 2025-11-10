import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfilesScreen extends StatefulWidget {
  const AdminProfilesScreen({super.key});

  @override
  State<AdminProfilesScreen> createState() => _AdminProfilesScreenState();
}

class _AdminProfilesScreenState extends State<AdminProfilesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _supabase.from('profiles').select().order('created_at');
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> profile) async {
    final TextEditingController investorCtrl = TextEditingController(
      text: profile['investor_profile']?.toString() ?? '',
    );
    final TextEditingController interessesCtrl = TextEditingController(
      text: _extractInteresses(profile),
    );

    String role = profile['role']?.toString() ?? 'user';

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF141414),
          title: const Text(
            'Editar perfil',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: role,
                  dropdownColor: const Color(0xFF141414),
                  decoration: const InputDecoration(
                    labelText: 'Papel (role)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'user',
                      child: Text('user'),
                    ),
                    DropdownMenuItem(
                      value: 'admin',
                      child: Text('admin'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) role = v;
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: investorCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Tipo investidor',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: interessesCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Interesses (separados por vírgula)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _saveProfile(
                  profile['id'] as String,
                  role,
                  investorCtrl.text.trim(),
                  interessesCtrl.text.trim(),
                  original: profile,
                );
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // monta um string de interesses a partir do json
  String _extractInteresses(Map<String, dynamic> profile) {
    final json = profile['investor_profile_json'];
    if (json is Map && json['interesses'] is List) {
      return (json['interesses'] as List).join(', ');
    }
    return '';
  }

  Future<void> _saveProfile(
    String id,
    String role,
    String investorProfile,
    String interesses, {
    required Map<String, dynamic> original,
  }) async {
    try {
      // monta json atualizado
      Map<String, dynamic> investorJson = {};
      if (original['investor_profile_json'] is Map) {
        investorJson =
            Map<String, dynamic>.from(original['investor_profile_json']);
      }
      investorJson['tipoInvestidor'] = investorProfile;
      investorJson['interesses'] = interesses
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await _supabase.from('profiles').update({
        'role': role,
        'investor_profile': investorProfile,
        'investor_profile_json': investorJson,
      }).eq('id', id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadProfiles();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        title: const Text('Perfis (admin)'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00FFA3)),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (_, i) {
                    final p = _profiles[i];
                    return ListTile(
                      tileColor: const Color(0xFF141414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      title: Text(
                        p['id'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        'role: ${p['role'] ?? 'user'} · investidor: ${p['investor_profile'] ?? '-'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: () => _openEditDialog(p),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: _profiles.length,
                ),
    );
  }
}
