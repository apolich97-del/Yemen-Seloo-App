import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../shein/presentation/shein_web_screen.dart';
import 'store_tab.dart';

/// تبويب المتجر: كتالوج يمن سيلو + تصفح SHEIN في مكان واحد.
class StoreHub extends StatelessWidget {
  const StoreHub({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          title: const Text('المتجر'),
          bottom: TabBar(
            labelColor: T.primary,
            unselectedLabelColor: T.muted,
            indicatorColor: T.primary,
            tabs: const [
              Tab(text: 'كتالوج يمن سيلو'),
              Tab(text: 'تصفح SHEIN'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [StoreTab(), SheinWebScreen()],
        ),
      ),
    );
  }
}
