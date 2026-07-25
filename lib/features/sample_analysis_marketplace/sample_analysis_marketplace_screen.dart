import 'package:flutter/material.dart';

import '../smart_labs/smart_labs_screen.dart';

/// Redirects to the unified labs hub (sample analysis tab).
@Deprecated('Use SmartLabsScreen instead')
class SampleAnalysisMarketplaceScreen extends StatelessWidget {
  const SampleAnalysisMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartLabsScreen(initialTab: SmartLabsTab.sampleAnalysis);
  }
}
