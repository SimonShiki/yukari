import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../l10n/l10n.dart';
import '../../../models/backend.dart';
import '../../../models/network.dart';
import '../../../signals/backend.dart';
import '../../../utils/crypto_utils.dart';
import '../../../utils/validator.dart';
import '../../../widgets/form_section/form_segments.dart';
import '../../../widgets/form_section/form_section.dart';
import 'network_form_tab.dart';
import 'node_list_editor.dart';
import 'startup_section.dart';
import 'validated_text_field.dart';

class NetworkBasicTab extends StatefulWidget {
  const NetworkBasicTab({
    super.key,
    required this.formKey,
    required this.controller,
  });

  final GlobalKey<FormState> formKey;
  final NetworkEditorController controller;

  @override
  State<NetworkBasicTab> createState() => _NetworkBasicTabState();
}

class _NetworkBasicTabState extends State<NetworkBasicTab>
    with AutomaticKeepAliveClientMixin {
  final _secretVisible = signal(false);
  late final _secretController = TextEditingController(
    text: _network.networkSecret,
  );

  NetworkEditorController get _editor => widget.controller;
  Network get _network => _editor.network.peek()!;

  // Keeps typed text and validation errors when switching tabs.
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _secretVisible.dispose();
    _secretController.dispose();
    super.dispose();
  }

  void _setSecret(String secret) =>
      _editor.update((n) => n.networkSecret = secret.isEmpty ? null : secret);

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return NetworkFormTab(
      formKey: widget.formKey,
      children: [
        FormSection(
          title: context.l10n.networkIdentity,
          icon: Icons.fingerprint,
          children: [
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.networkName,
                decoration: InputDecoration(
                  labelText: context.l10n.networkName,
                  helperText: context.l10n.networkNameHelper,
                  border: OutlineInputBorder(),
                ),
                validator: _editor.networkNameError,
                onValid: (v) => _editor.update((n) => n.networkName = v.trim()),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.hostname,
                decoration: InputDecoration(
                  labelText: context.l10n.networkHostname,
                  helperText: context.l10n.networkHostnameHelper,
                  border: OutlineInputBorder(),
                ),
                maxLength: 32,
                validator: validateHostname,
                onValid: (v) => _editor.update(
                  (n) => n.hostname = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
            ),
            FieldSegment(
              child: SignalBuilder(
                builder: (context) => ValidatedTextField(
                  controller: _secretController,
                  decoration: InputDecoration(
                    labelText: context.l10n.networkSecret,
                    helperText: context.l10n.networkSecretHelper,
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _secretVisible.value
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip: _secretVisible.value
                              ? context.l10n.networkHideSecret
                              : context.l10n.networkShowSecret,
                          onPressed: () =>
                              _secretVisible.value = !_secretVisible.value,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: context.l10n.networkGenerateSecret,
                          onPressed: () {
                            _secretController.text = generateSecretKey();
                            _setSecret(_secretController.text);
                          },
                        ),
                      ],
                    ),
                  ),
                  obscureText: !_secretVisible.value,
                  onValid: _setSecret,
                ),
              ),
            ),
          ],
        ),
        FormSection(
          title: context.l10n.networkIpConfiguration,
          icon: Icons.network_check,
          children: [
            SignalBuilder(
              builder: (context) => SwitchSegment(
                title: context.l10n.networkDhcp,
                subtitle: context.l10n.networkDhcpDescription,
                value: _editor.network.value!.dhcp,
                onChanged: (v) => _editor.update((n) => n.dhcp = v),
              ),
            ),
            FieldSegment(
              child: SignalBuilder(
                builder: (context) => ValidatedTextField(
                  initialValue: _network.ipv4,
                  decoration: InputDecoration(
                    labelText: context.l10n.networkIpv4,
                    hintText: '10.144.144.1/24',
                    helperText: context.l10n.networkIpv4Helper,
                    border: OutlineInputBorder(),
                  ),
                  enabled: !_editor.network.value!.dhcp,
                  validator: (v) => validateCidr(v, InternetAddressType.IPv4),
                  onValid: (v) =>
                      _editor.update((n) => n.ipv4 = v.isEmpty ? null : v),
                ),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.ipv6,
                decoration: InputDecoration(
                  labelText: context.l10n.networkIpv6,
                  hintText: 'fd00::1/64',
                  helperText: context.l10n.networkIpv6Helper,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => validateCidr(v, InternetAddressType.IPv6),
                onValid: (v) =>
                    _editor.update((n) => n.ipv6 = v.isEmpty ? null : v),
              ),
            ),
          ],
        ),
        // On Android only the root service, if chosen, starts networks on
        // boot; the app itself cannot.
        if (!Platform.isAndroid || backend.peek().kind == BackendKind.service)
          StartupSection(controller: _editor),
        SignalBuilder(
          builder: (context) => NodeListEditor(
            nodes: _editor.network.value!.nodes,
            onNodesChanged: (nodes) => _editor.update((n) => n.nodes = nodes),
          ),
        ),
      ],
    );
  }
}
