import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class Household {
  final String id;
  final String name;
  final String inviteCode;
  final int memberCount;

  const Household({required this.id, required this.name, required this.inviteCode, required this.memberCount});

  factory Household.fromMap(Map<String, dynamic> m) => Household(
        id: m['id'] as String,
        name: m['name'] as String,
        inviteCode: m['invite_code'] as String,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 1,
      );
}

class HouseholdMember {
  final String email;
  final String role;
  const HouseholdMember(this.email, this.role);
}

class HouseholdException implements Exception {
  final String message;
  const HouseholdException(this.message);
  @override
  String toString() => message;
}

class HouseholdService {
  static Household _first(dynamic result) {
    final rows = List<Map<String, dynamic>>.from(result as List);
    if (rows.isEmpty) throw const HouseholdException('Não foi possível carregar a casa.');
    return Household.fromMap(rows.first);
  }

  /// The signed-in user's household (created on first use).
  static Future<Household> ensure() async => _first(await SupabaseService.client.rpc('ensure_household'));

  static Future<Household> join(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.length < 6) throw const HouseholdException('Digite o código completo.');
    try {
      return _first(await SupabaseService.client.rpc('join_household', params: {'p_code': clean}));
    } on PostgrestException catch (e) {
      if (e.message.contains('invalid_code')) {
        throw const HouseholdException('Código não encontrado. Confira com quem te convidou.');
      }
      rethrow;
    }
  }

  static Future<List<HouseholdMember>> members() async {
    final rows = List<Map<String, dynamic>>.from(await SupabaseService.client.rpc('household_members_list') as List);
    return [for (final r in rows) HouseholdMember(r['email'] as String? ?? '—', r['role'] as String? ?? 'member')];
  }
}
