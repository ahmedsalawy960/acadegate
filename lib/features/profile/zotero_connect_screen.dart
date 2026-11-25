import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/theme/acadegate_theme.dart';
import '../academic_integrity/zotero_client.dart';
import '../academic_integrity/zotero_connection_store.dart';

/// Connect the user's own Zotero library (personal user ID + API key from
/// zotero.org/settings/keys). The key is stored on-device only and Zotero
/// calls go straight to api.zotero.org.
class ZoteroConnectScreen extends StatefulWidget {
  const ZoteroConnectScreen({super.key});

  @override
  State<ZoteroConnectScreen> createState() => _ZoteroConnectScreenState();
}

class _ZoteroConnectScreenState extends State<ZoteroConnectScreen> {
  final _userIdController = TextEditingController();
  final _apiKeyController = TextEditingController();

  ZoteroConnection? _connection;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final conn = await ZoteroConnectionStore.instance.read();
    if (!mounted) return;
    setState(() {
      _connection = conn;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final userId = _userIdController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (userId.isEmpty || apiKey.isEmpty) {
      setState(() {
        _error = context.t(
          'أدخل معرّف المستخدم ومفتاح API.',
          'Enter your user ID and API key.',
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ZoteroClient.instance
        .validate(userId: userId, apiKey: apiKey);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = context.t(
          'تعذّر الوصول للمكتبة. تحقق من المعرّف والمفتاح وصلاحيات القراءة.',
          'Could not read the library. Check the ID, key, and read permission.',
        );
      });
      return;
    }
    await ZoteroConnectionStore.instance
        .save(userId: userId, apiKey: apiKey);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _connection = ZoteroConnection(userId: userId, apiKey: apiKey);
    });
  }

  Future<void> _disconnect() async {
    setState(() => _busy = true);
    await ZoteroConnectionStore.instance.clear();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _connection = null;
      _userIdController.clear();
      _apiKeyController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('مكتبة Zotero', 'Zotero library')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AcadeGateColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _connection != null
                        ? _buildConnected()
                        : _buildForm(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.t(
                    'المفتاح يُحفظ على جهازك فقط، وتُستخدم المكتبة لإثراء نتائج البحث بمراجعك الخاصة.',
                    'The key is stored on this device only; your library enriches search with your own references.',
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AcadeGateColors.muted,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConnected() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.check_circle_outline,
              color: Colors.green),
          title: Text(context.t('المكتبة متصلة', 'Library connected')),
          subtitle: Text('User ID: ${_connection!.userId}'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _busy ? null : _disconnect,
            icon: const Icon(Icons.link_off, size: 18),
            label: Text(context.t('قطع الاتصال', 'Disconnect')),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.t(
            'أنشئ مفتاحًا من zotero.org/settings/keys بصلاحية القراءة، ثم أدخله هنا مع معرّف المستخدم الظاهر في نفس الصفحة.',
            'Create a read key at zotero.org/settings/keys, then enter it here with the user ID shown on the same page.',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _userIdController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.t('معرّف المستخدم', 'User ID'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _apiKeyController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: context.t('مفتاح API', 'API key'),
            border: const OutlineInputBorder(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: _busy ? null : _connect,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.link, size: 18),
            label: Text(context.t('ربط المكتبة', 'Connect library')),
          ),
        ),
      ],
    );
  }
}
