import 'dart:async';

import 'package:flutter/services.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_magic_dns.dart';
import '../../../l10n/l10n.dart';
import 'package:yukari_core/system/magic_dns.dart';
import '../../../widgets/snackbar/app_snackbar.dart';

part 'magic_dns_card_content.dart';

part 'magic_dns_command_box.dart';

/// The Magic DNS helper: the DNS server, this network's Magic DNS name, and
/// what the system DNS is doing, with the actions that change it.
///
/// It sits where Magic DNS is enabled (the network editor) and in a running
/// network's peers tab, where the system DNS can actually be configured. The
/// caller can pass a [controller] it owns; without one the card creates and
/// disposes its own.
class MagicDnsCard extends StatefulWidget {
  const MagicDnsCard({
    super.key,
    required this.networkId,
    this.controller,
    this.system,
    this.padding = EdgeInsets.zero,
  });

  /// The network whose Magic DNS this card explains.
  final String networkId;

  /// A controller the caller owns and disposes, or null to create one.
  final MagicDnsController? controller;

  /// The system reader the created controller uses; null reads the host.
  final MagicDnsSystem? system;

  /// Space around the card; a hidden card takes none of it.
  final EdgeInsetsGeometry padding;

  @override
  State<MagicDnsCard> createState() => _MagicDnsCardState();
}

class _MagicDnsCardState extends State<MagicDnsCard> {
  late final MagicDnsController _controller =
      widget.controller ??
      MagicDnsController(networkId: widget.networkId, system: widget.system);

  /// A problem state is shown once the automatic setup has had a moment to
  /// finish, so a configured network never flashes the card at start.
  bool _settled = false;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _scheduleSettle() {
    _settle ??= Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.system.supported) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SignalBuilder(
      builder: (context) {
        final state = _controller.state.value;
        // Only the states that need attention show: a configured system DNS
        // (after the automatic setup or a manual apply) and an off network
        // need nothing from the user.
        if (state == MagicDnsState.configured ||
            state == MagicDnsState.off ||
            _controller.dismissed.value) {
          return const SizedBox.shrink();
        }
        if (!_settled && state != MagicDnsState.notRunning) {
          _scheduleSettle();
          return const SizedBox.shrink();
        }
        final busy = _controller.busy.value;
        final zone = _controller.zone.value;
        final magicName = _controller.magicName.value;
        final commands = _commandsFor(
          context,
          _controller,
          state,
          zone: zone,
          name: magicName,
        );
        return Padding(
          padding: widget.padding,
          child: Material(
            color: colors.secondaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    spacing: 8,
                    children: [
                      Icon(
                        Icons.dns_rounded,
                        color: colors.onSecondaryContainer,
                      ),
                      Expanded(
                        child: Text(
                          context.l10n.magicDnsTitle,
                          style: theme.emphasizedTextTheme.titleSmall?.copyWith(
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                      if (busy)
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      IconButton(
                        tooltip: context.l10n.magicDnsDismiss,
                        visualDensity: VisualDensity.compact,
                        onPressed: _controller.dismiss,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  _ValueLine(
                    label: context.l10n.magicDnsServer,
                    value: magicDnsServer,
                  ),
                  _ValueLine(
                    label: context.l10n.magicDnsName,
                    value: magicName ?? context.l10n.magicDnsNameUnknown,
                  ),
                  _StatusLine(
                    state: state,
                    message: _messageFor(context, _controller, state),
                  ),
                  if (_buttonsFor(context, _controller, state, busy)
                      case final buttons when buttons.isNotEmpty)
                    Wrap(spacing: 8, runSpacing: 8, children: buttons),
                  ?commands,
                  if (_showsConflict(_controller, state))
                    Text(
                      context.l10n.magicDnsConflictNote(magicDnsZoneBase(zone)),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
