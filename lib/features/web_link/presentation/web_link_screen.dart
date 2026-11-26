import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/providers.dart';
import '../../../design/design.dart';
import '../../../domain/constants.dart';
import '../../menus/application/menu_providers.dart';
import '../../menus/presentation/menu_locked_view.dart';

/// Opens a URL in the external browser. A provider so tests can record it.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) =>
      (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
  name: 'urlOpener',
);

/// Opens `<web app>/app/<path>` in the browser; tells the person if it fails.
Future<void> openWebAppPage(
  BuildContext context,
  WidgetRef ref,
  String path,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = ref.read(appConfigProvider).webAppPage(path);
  var ok = false;
  try {
    ok = await ref.read(urlOpenerProvider)(uri);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open the browser.")),
    );
  }
}

/// A feature that lives on the web app only: explains what it does and opens
/// it in the browser, rather than leaving the app silently.
class WebLinkScreen extends ConsumerWidget {
  const WebLinkScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    required this.webPath,
    this.menu,
  });

  final String title;
  final IconData icon;
  final String description;

  /// Page under `/app/` on the web.
  final String webPath;
  final FeatureMenu? menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (menu != null &&
        ref.watch(menuStatusProvider(menu!)) == MenuStatus.locked) {
      return AppPage(
        title: title,
        body: MenuLockedView(feature: title, icon: icon),
      );
    }
    final palette = context.palette;
    return AppPage(
      title: title,
      padBody: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenGutter,
          AppSpacing.sm,
          AppSpacing.screenGutter,
          AppSpacing.huge,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTile(icon: icon, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '$title lives on the web app',
                  style: AppTypography.title.copyWith(color: palette.ink),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTypography.body.copyWith(color: palette.muted),
                ),
                const SizedBox(height: AppSpacing.xl),
                PillButton(
                  label: 'Open in browser',
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onPressed: () => openWebAppPage(context, ref, webPath),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) => const WebLinkScreen(
    title: 'Trips',
    icon: Icons.luggage_outlined,
    description:
        'Plan trip budgets and track what each trip costs. Open the web app '
        'to manage your trips.',
    webPath: 'trips',
    menu: FeatureMenu.trips,
  );
}
