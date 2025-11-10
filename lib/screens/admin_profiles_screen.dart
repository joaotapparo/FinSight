import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';

class AdminProfilesScreen extends StatefulWidget {
  const AdminProfilesScreen({super.key});

  @override
  State<AdminProfilesScreen> createState() => _AdminProfilesScreenState();
}

class _AdminProfilesScreenState extends State<AdminProfilesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _profiles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await UserProfileService.getAllProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggleRole(Map<String, dynamic> profile) async {
    final currentRole = profile['role'] ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';

    await UserProfileService.updateUserRole(
      userId: profile['id'],
      role: newRole,
    );

    await _loadProfiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Perfis'),
        actions: [
          IconButton(
            onPressed: _loadProfiles,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FFA3)))
          : _error != null
              ? Center(
                  child: Text(
                    'Erro: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final p = _profiles[index];
                    final json = p['investor_profile_json'];
                    final interesses = (json is Map && json['interesses'] != null)
                        ? json['interesses'].toString()
                        : '-';

                    return Card(
                      color: const Color(0xFF151515),
                      child: ListTile(
                        title: Text(
                          p['id'] ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          'role: ${p['role'] ?? 'user'}\ninteresses: $interesses',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => _toggleRole(p),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (p['role'] ?? 'user') == 'admin'
                                ? Colors.red
                                : const Color(0xFF00FFA3),
                            foregroundColor:
                                (p['role'] ?? 'user') == 'admin' ? Colors.white : Colors.black,
                          ),
                          child: Text(
                            (p['role'] ?? 'user') == 'admin'
                                ? 'Tornar user'
                                : 'Tornar admin',
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
