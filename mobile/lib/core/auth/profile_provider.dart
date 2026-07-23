import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';
import 'app_profile.dart';

final currentProfileProvider = FutureProvider<AppProfile?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;

  final row = await client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return AppProfile.fromMap(row);
});
