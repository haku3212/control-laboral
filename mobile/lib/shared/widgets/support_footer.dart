import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_branding.dart';

class SupportFooter extends StatelessWidget {
  const SupportFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            'Desarrollado por ${AppBranding.developerName}',
            textAlign: TextAlign.center,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => _openWhatsApp(context),
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: const Text(
              'Soporte por WhatsApp: ${AppBranding.supportPhone}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              textStyle: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final message = Uri.encodeComponent(
      'Hola, necesito soporte con Control Laboral AI.',
    );
    final uri = Uri.parse(
      'https://wa.me/${AppBranding.supportWhatsAppNumber}?text=$message',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
    );
  }
}
