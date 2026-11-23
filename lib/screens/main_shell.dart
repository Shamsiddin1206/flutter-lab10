// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../services/classifier.dart';
import '../services/history.dart';
import '../services/image_sources.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'model_screen.dart';

/// Bottom navigation for Home, History and Model. Result is pushed on top.
/// The shared services arrive by constructor injection and are handed down.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.classifier,
    required this.history,
    required this.sources,
  });

  final Classifier classifier;
  final HistoryStore history;
  final ImageSources sources;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back on History/Model goes to Home first, then leaves the app.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            HomeScreen(
              classifier: widget.classifier,
              history: widget.history,
              sources: widget.sources,
            ),
            HistoryScreen(
              history: widget.history,
              labels: widget.classifier.labels,
            ),
            ModelScreen(classifier: widget.classifier),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: ListenableBuilder(
                listenable: widget.history,
                builder: (context, _) => Badge(
                  isLabelVisible: !widget.history.isEmpty,
                  label: Text('${widget.history.entries.length}'),
                  child: const Icon(Icons.history_outlined),
                ),
              ),
              selectedIcon: const Icon(Icons.history),
              label: 'History',
            ),
            const NavigationDestination(
              icon: Icon(Icons.memory_outlined),
              selectedIcon: Icon(Icons.memory),
              label: 'Model',
            ),
          ],
        ),
      ),
    );
  }
}
