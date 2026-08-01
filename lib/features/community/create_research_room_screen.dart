import 'package:flutter/material.dart';
import 'package:acadegate/core/widgets/acadegate_app_bar.dart';

import '../../core/locale/l10n_lookup.dart';
import '../../core/locale/locale_extensions.dart';
import 'community_data.dart';
import 'research_room_service.dart';

class CreateResearchRoomScreen extends StatefulWidget {
  const CreateResearchRoomScreen({super.key});

  @override
  State<CreateResearchRoomScreen> createState() =>
      _CreateResearchRoomScreenState();
}

class _CreateResearchRoomScreenState extends State<CreateResearchRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _categoryId;
  bool _usePassword = false;
  bool _obscurePassword = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final result = await ResearchRoomService.instance.createRoom(
      title: _titleController.text,
      description: _descriptionController.text,
      categoryId: _categoryId,
      isPasswordProtected: _usePassword,
      password: _usePassword ? _passwordController.text : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error!),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AcadeGateAppBar(
        title: Text(context.t('إنشاء غرفة بحثية', 'Create research room')),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.t(
                  'أنشئ غرفة لمناقشاتك البحثية. يمكنك حمايتها بكلمة مرور '
                  'ليستطع الدخول إليها من تعطيه كلمة المرور فقط.',
                  'Create a room for your research discussions. You can protect it with a password '
                  'so only those you share it with can enter.',
                ),
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.t('اسم الغرفة *', 'Room name *'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.t('مطلوب', 'Required')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.t('وصف الغرفة', 'Room description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: InputDecoration(
                  labelText: context.t(
                    'التخصص (اختياري)',
                    'Discipline (optional)',
                  ),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(context.t('عام / بدون تخصص', 'General / none')),
                  ),
                  ...communityRooms
                      .where((room) => room.id != 'general')
                      .map(
                        (room) => DropdownMenuItem(
                          value: room.id,
                          child: Text(L10nLookup.communityRoomTitle(room.id)),
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t(
                  'حماية الغرفة بكلمة مرور',
                  'Protect room with password',
                )),
                subtitle: Text(context.t(
                  'لن يدخلها إلا من يعرف كلمة المرور',
                  'Only those who know the password can enter',
                )),
                value: _usePassword,
                onChanged: (value) => setState(() => _usePassword = value),
              ),
              if (_usePassword) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: context.t('كلمة المرور *', 'Password *'),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? context.t('إظهار كلمة المرور', 'Show password')
                          : context.t('إخفاء كلمة المرور', 'Hide password'),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (!_usePassword) return null;
                    if (v == null || v.trim().length < 4) {
                      return context.t(
                        '4 أحرف على الأقل',
                        'At least 4 characters',
                      );
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(context.t('إنشاء الغرفة', 'Create room')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
