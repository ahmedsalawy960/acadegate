import 'package:flutter/material.dart';

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
    final error = await ResearchRoomService.instance.createRoom(
      title: _titleController.text,
      description: _descriptionController.text,
      categoryId: _categoryId,
      isPasswordProtected: _usePassword,
      password: _usePassword ? _passwordController.text : null,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء غرفة بحثية'),
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
              const Text(
                'أنشئ غرفة لمناقشاتك البحثية. يمكنك حمايتها بكلمة مرور '
                'ليستطع الدخول إليها من تعطيه كلمة المرور فقط.',
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'اسم الغرفة *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف الغرفة',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'التخصص (اختياري)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('عام')),
                  ...communityRooms.map(
                    (room) => DropdownMenuItem(
                      value: room.id,
                      child: Text(room.title),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حماية الغرفة بكلمة مرور'),
                subtitle: const Text('لن يدخلها إلا من يعرف كلمة المرور'),
                value: _usePassword,
                onChanged: (value) => setState(() => _usePassword = value),
              ),
              if (_usePassword) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (!_usePassword) return null;
                    if (v == null || v.trim().length < 4) {
                      return '4 أحرف على الأقل';
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
                    : const Text('إنشاء الغرفة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
