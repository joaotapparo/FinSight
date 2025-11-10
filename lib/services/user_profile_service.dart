import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileService {
  static final _supabase = Supabase.instance.client;

  /// pega o perfil do usuário logado na tabela `profiles`
  /// retorna o JSON que a Fin salvou (investor_profile_json)
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final res = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) return null;

    final data = res['investor_profile_json'];
    if (data == null) return null;

    // garante que vem como Map<String, dynamic>
    return Map<String, dynamic>.from(data as Map);
  }

  /// opcional: pra saber se é admin
  static Future<bool> isAdmin() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final res = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();

    if (res == null) return false;
    return (res['role'] as String?) == 'admin';
  }
}
