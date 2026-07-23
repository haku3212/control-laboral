import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/auth/profile_provider.dart';

class RoleGateScreen extends ConsumerWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: profileAsync.when(
            loading: () => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cargando perfil...'),
              ],
            ),
            error: (error, stackTrace) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo consultar el perfil.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(currentProfileProvider);
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (profile) {
              if (user == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    context.go('/login');
                  }
                });

                return const Text('Sesión no disponible.');
              }

              if (profile == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_off_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'La sesión inició correctamente, pero no se encontró '
                      'el perfil asociado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'ID del usuario:\n${user.id}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        ref.invalidate(currentProfileProvider);
                      },
                      child: const Text('Volver a consultar'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();

                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                );
              }

              if (!profile.active) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.block_outlined,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Este usuario está inactivo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();

                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;

                context.go(
                  profile.isOperator ? '/operator' : '/dashboard',
                );
              });

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Bienvenido, ${profile.fullName}'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}