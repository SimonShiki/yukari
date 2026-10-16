import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../controllers/home_controller.dart';
import '../../l10n/l10n.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.navHome)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final margin = constraints.maxWidth < 600
                ? 16.0
                : constraints.maxWidth < 840
                ? 24.0
                : 32.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(margin, 8, margin, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      BackendHeader(controller: _controller),
                      _StatGrid(controller: _controller),
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
}

/// The stat grid: four columns when the content allows it, then two, then one.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 720
            ? 4
            : width >= 440
            ? 2
            : 1;
        final cardWidth = (width - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: NetworksCard(
                controller: controller,
                onOpen: () => context.go(controller.networksRoute),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: AddressCard(controller: controller),
            ),
            SizedBox(
              width: cardWidth,
              child: NatCard(controller: controller),
            ),
            SizedBox(
              width: cardWidth,
              child: TrafficCard(controller: controller),
            ),
          ],
        );
      },
    );
  }
}
