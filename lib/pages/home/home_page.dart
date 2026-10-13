import 'package:material_ui/material_ui.dart';

import '../../controllers/home_controller.dart';
import 'widgets/address_card.dart';
import 'widgets/backend_header.dart';
import 'widgets/nat_card.dart';
import 'widgets/networks_card.dart';
import 'widgets/traffic_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  final HomeController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller = widget.controller ?? HomeController();

  @override
  void initState() {
    super.initState();
    _controller.start();
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Home')),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Margins of the compact, medium and expanded window classes.
          final margin = switch (constraints.maxWidth) {
            < 600 => 16.0,
            < 840 => 24.0,
            _ => 32.0,
          };
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(margin, 8, margin, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _spacing,
                  children: [
                    BackendHeader(controller: _controller),
                    _StatGrid(
                      children: [
                        NetworksCard(controller: _controller),
                        AddressCard(controller: _controller),
                        NatCard(controller: _controller),
                        TrafficCard(controller: _controller),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

const _spacing = 12.0;

/// Equal columns of stat cards: one row of four on wide windows, then two,
/// then one. The cards are as tall as each other by design, so rows stay
/// even without stretching them.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = switch (constraints.maxWidth) {
        >= 720 => 4,
        >= 440 => 2,
        _ => 1,
      };
      final width = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: _spacing,
        runSpacing: _spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
