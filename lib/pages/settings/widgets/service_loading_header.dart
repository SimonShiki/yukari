import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/l10n.dart';

/// The trailing spinner, sized like the refresh button it replaces.
const serviceTrailingSpinner = SizedBox.square(
  dimension: 48,
  child: Padding(
    padding: EdgeInsets.all(12),
    child: CircularProgressIndicator(strokeWidth: 3),
  ),
);

/// The service header before the first check answers.
///
/// It is laid out exactly like a real header — same leading size, same
/// two-line shape, same trailing size — so the state landing changes only the
/// words, never the geometry around them.
class ServiceLoadingHeader extends StatelessWidget {
  const ServiceLoadingHeader({super.key, required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => M3EListItem(
    leading: const Icon(Icons.settings_suggest_outlined),
    // No new l10n key may be added, and this is the app's only generic
    // "loading" string.
    headline: Text(l10n.homeLoading),
    // An empty supporting line keeps the two-line height of a real header.
    supportingText: const Text(''),
    trailing: serviceTrailingSpinner,
  );
}
