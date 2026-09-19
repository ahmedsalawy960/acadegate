import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

/// عناصر مشتركة لصفحات السياسة والشروط.
class LegalDocScaffold extends StatelessWidget {
  const LegalDocScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF18181B),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 48),
        children: children,
      ),
    );
  }
}

class LegalIntro extends StatelessWidget {
  const LegalIntro({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
      ),
    );
  }
}

class LegalMeta extends StatelessWidget {
  const LegalMeta({
    super.key,
    required this.effectiveDate,
    required this.version,
  });

  final String effectiveDate;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        '$effectiveDate · $version',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12.5,
          height: 1.4,
        ),
      ),
    );
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF18181B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              height: 1.65,
              color: Colors.grey.shade800,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}
