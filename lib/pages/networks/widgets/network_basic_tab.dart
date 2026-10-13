import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../controllers/network_editor_controller.dart';
import '../../../models/network.dart';
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
          title: 'Network Identity',
          icon: Icons.fingerprint,
          children: [
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.networkName,
                decoration: const InputDecoration(
                  labelText: 'Network Name',
                  helperText: 'Unique identifier for this network',
                  border: OutlineInputBorder(),
                ),
                validator: _editor.networkNameError,
                onValid: (v) => _editor.update((n) => n.networkName = v.trim()),
              ),
            ),
            FieldSegment(
              child: ValidatedTextField(
                initialValue: _network.hostname,
                decoration: const InputDecoration(
                  labelText: 'Hostname (Optional)',
                  helperText: 'Device name in the network (max 32 chars)',
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
                    labelText: 'Network Secret (Optional)',
                    helperText: 'Shared secret for authentication',
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
                              ? 'Hide secret'
                              : 'Show secret',
                          onPressed: () =>
                              _secretVisible.value = !_secretVisible.value,
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Generate random secret',
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
          title: 'IP Configuration',
          icon: Icons.network_check,
          children: [
            SignalBuilder(
              builder: (context) => SwitchSegment(
                title: 'Enable DHCP',
                subtitle: 'Automatically assign IP addresses',
                value: _editor.network.value!.dhcp,
                onChanged: (v) => _editor.update((n) => n.dhcp = v),
              ),
            ),
            FieldSegment(
              child: SignalBuilder(
                builder: (context) => ValidatedTextField(
                  initialValue: _network.ipv4,
                  decoration: const InputDecoration(
                    labelText: 'IPv4 Address (CIDR)',
                    hintText: '10.144.144.1/24',
                    helperText: 'Your IPv4 address in CIDR notation',
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
                decoration: const InputDecoration(
                  labelText: 'IPv6 Address (CIDR)',
                  hintText: 'fd00::1/64',
                  helperText: 'Your IPv6 address in CIDR notation',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => validateCidr(v, InternetAddressType.IPv6),
                onValid: (v) =>
                    _editor.update((n) => n.ipv6 = v.isEmpty ? null : v),
              ),
            ),
          ],
        ),
        // Android has no background service to start networks on boot.
        if (!Platform.isAndroid) StartupSection(controller: _editor),
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
