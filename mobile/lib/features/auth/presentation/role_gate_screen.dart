import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/profile_provider.dart';

class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(currentProfileProvider, (previous, next) {
      next.whenData((profile) {
        if (profile == null || !profile.active) {
          Supabase.instance.client.auth.signOut();
          return;
        }
        context.go(profile.isOperator ? '/operator' : '/dashboard');
      });
    });

    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      body: Center(
        child: profile.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo cargar tu perfil.\n$error'),
          ),
          data: (_) => const Text('Preparando tu panel...'),
        ),
      ),
    );
  }
}
