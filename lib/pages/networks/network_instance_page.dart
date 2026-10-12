import 'package:material_ui/material_ui.dart';

class NetworkInstancePage extends StatelessWidget {
  const NetworkInstancePage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Instance')),
      body: const Center(child: Text('Network Instance Page')),
    );
  }
}
