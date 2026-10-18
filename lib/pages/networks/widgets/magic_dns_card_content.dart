part of 'magic_dns_card.dart';

/// The sentence that explains [state] on [controller]'s platform.
String _messageFor(
  BuildContext context,
  MagicDnsController controller,
  MagicDnsState state,
) {
  final l10n = context.l10n;
  final automatic = controller.system.automatic;
  final base = magicDnsZoneBase(controller.zone.value);
  return switch (state) {
    // A configured or off network never builds the card; these are defensive.
    MagicDnsState.off || MagicDnsState.configured => '',
    MagicDnsState.notRunning =>
      automatic ? l10n.magicDnsStartAutomatic : l10n.magicDnsStartManual,
    MagicDnsState.missing =>
      automatic ? l10n.magicDnsWindowsMissing : l10n.magicDnsMissing(base),
    MagicDnsState.unsupported => l10n.magicDnsNoResolved,
    MagicDnsState.noInterface => l10n.magicDnsNoInterface,
    MagicDnsState.failed => l10n.magicDnsFailed(controller.error.value ?? ''),
  };
}

/// The actions [state] offers on [controller]'s platform.
List<Widget> _buttonsFor(
  BuildContext context,
  MagicDnsController controller,
  MagicDnsState state,
  bool busy,
) {
  final l10n = context.l10n;
  final configurable = controller.system.configurable;
  return [
    if (configurable &&
        (state == MagicDnsState.missing || state == MagicDnsState.failed))
      M3EButton.icon(
        onPressed: busy ? null : controller.apply,
        icon: const Icon(Icons.dns_rounded),
        label: Text(l10n.magicDnsApply),
      ),
    // A failed attempt can leave a partial configuration behind; this clears
    // whatever reached the interface.
    if (configurable &&
        state == MagicDnsState.failed &&
        controller.interfaceName.value.isNotEmpty)
      M3EButton.icon(
        onPressed: busy ? null : controller.reset,
        icon: const Icon(Icons.restart_alt_rounded),
        label: Text(l10n.magicDnsReset),
        style: M3EButtonStyle.tonal,
      ),
    if (state != MagicDnsState.notRunning && state != MagicDnsState.unsupported)
      M3EButton.icon(
        onPressed: busy ? null : controller.refresh,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l10n.settingsCheckAgain),
        style: M3EButtonStyle.text,
      ),
  ];
}

/// The copyable fallback for [state]: the hand-written configuration, or the
/// commands that test the server directly when EasyTier configured the DNS.
Widget? _commandsFor(
  BuildContext context,
  MagicDnsController controller,
  MagicDnsState state, {
  required String zone,
  required String? name,
}) {
  final l10n = context.l10n;
  final system = controller.system;
  final (label, lines) = switch (state) {
    MagicDnsState.unsupported => (
      l10n.magicDnsManual,
      system.resolvConfLines(zone: zone),
    ),
    MagicDnsState.missing || MagicDnsState.failed => (
      system.automatic ? l10n.magicDnsWindowsTest : l10n.magicDnsManual,
      system.manualCommands(
        zone: zone,
        interfaceName: controller.interfaceName.value,
        name: name,
      ),
    ),
    _ => (null, const <String>[]),
  };
  if (label == null || lines.isEmpty) return null;
  return _CommandBox(label: label, lines: lines);
}

/// Whether another TUN proxy can be blamed for the missing names. EasyTier
/// sets its own interface DNS on Windows, so a running FlClash-style proxy is
/// the usual reason the card appears there.
bool _showsConflict(MagicDnsController controller, MagicDnsState state) =>
    controller.system.automatic && state == MagicDnsState.missing;

/// One `label  value` line of the card.
class _ValueLine extends StatelessWidget {
  const _ValueLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSecondaryContainer;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// The state icon and the sentence that explains it.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, required this.message});

  final MagicDnsState state;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final (icon, color) = switch (state) {
      MagicDnsState.configured => (Icons.check_circle_rounded, colors.primary),
      MagicDnsState.failed => (Icons.error_outline_rounded, colors.error),
      _ => (Icons.info_outline_rounded, colors.onSecondaryContainer),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 18, color: color),
        ),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSecondaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}
