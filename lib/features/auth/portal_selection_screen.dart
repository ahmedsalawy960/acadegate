import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import 'portal_type.dart';
import 'user_account_service.dart';

class PortalSelectionScreen extends StatefulWidget {
  final Future<void> Function(String portal) onSelect;

  const PortalSelectionScreen({
    super.key,
    required this.onSelect,
  });

  @override
  State<PortalSelectionScreen> createState() => _PortalSelectionScreenState();
}

class _PortalSelectionScreenState extends State<PortalSelectionScreen> {
  String? _suggested;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    final account = await UserAccountService.instance.loadCurrentAccount();
    if (!mounted) return;
    setState(() {
      _suggested = PortalType.suggestedForRole(account?.role);
      _loading = false;
    });
  }

  Future<void> _choose(String portal) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSelect(portal);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isLoggedIn = FirebaseAuth.instance.currentUser != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A237E)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    const Icon(
                      Icons.hub_outlined,
                      size: 56,
                      color: Color(0xFF1A237E),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.portalChooseTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLoggedIn
                          ? l10n.portalChooseSubtitleLoggedIn
                          : l10n.portalChooseSubtitleGuest,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _PortalCard(
                      portal: PortalType.user,
                      title: l10n.portalUser,
                      subtitle: l10n.portalUserSubtitle,
                      icon: Icons.school_outlined,
                      accent: const Color(0xFF1565C0),
                      items: [
                        l10n.portalUserItem1,
                        l10n.portalUserItem2,
                        l10n.portalUserItem3,
                        l10n.portalUserItem4,
                      ],
                      isSuggested: _suggested == PortalType.user,
                      isLoading: _submitting,
                      enterLabel: l10n.portalEnter,
                      suggestedLabel: l10n.portalSuggestedBadge,
                      onTap: () => _choose(PortalType.user),
                    ),
                    const SizedBox(height: 16),
                    _PortalCard(
                      portal: PortalType.provider,
                      title: l10n.portalProvider,
                      subtitle: l10n.portalProviderSubtitleAlt,
                      icon: Icons.storefront_outlined,
                      accent: const Color(0xFF2E7D32),
                      items: [
                        l10n.portalProviderItem1,
                        l10n.portalProviderItem2,
                        l10n.portalProviderItem3,
                        l10n.portalProviderItem4,
                      ],
                      isSuggested: _suggested == PortalType.provider,
                      isLoading: _submitting,
                      enterLabel: l10n.portalEnter,
                      suggestedLabel: l10n.portalSuggestedBadge,
                      onTap: () => _choose(PortalType.provider),
                    ),
                    const SizedBox(height: 24),
                    if (_suggested != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: Color(0xFF1A237E),
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${l10n.portalSuggestedPrefix} ${L10nLookup.portalLabel(l10n, _suggested)}',
                                style: const TextStyle(
                                  color: Color(0xFF1A237E),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final String portal;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final List<String> items;
  final bool isSuggested;
  final bool isLoading;
  final String enterLabel;
  final String suggestedLabel;
  final VoidCallback onTap;

  const _PortalCard({
    required this.portal,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.items,
    required this.isSuggested,
    required this.isLoading,
    required this.enterLabel,
    required this.suggestedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: isSuggested ? 4 : 1,
      shadowColor: accent.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSuggested ? accent : Colors.grey.shade200,
              width: isSuggested ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 32),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSuggested)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        suggestedLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 16, color: accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward, size: 18),
                  label: Text(enterLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
