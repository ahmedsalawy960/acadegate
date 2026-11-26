import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale/locale_extensions.dart';
import '../../core/locale/locale_service.dart';
import '../../core/storage/storage_service.dart';
import '../community/community_attachment_policy.dart';
import 'chat_media.dart';

Future<void> openChatUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class ChatDaySeparator extends StatelessWidget {
  final DateTime day;

  const ChatDaySeparator({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final isEnglish = LocaleService.instance.isEnglish;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            formatChatDayLabel(day, isEnglish: isEnglish),
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  final String text;
  final bool mine;
  final DateTime? createdAt;
  final ChatAttachment attachment;
  final String? senderName;
  final Color mineColor;
  final Color theirsColor;
  final Color? mineTextColor;
  final Color? theirsTextColor;
  final Color? timeColorMine;
  final Color? timeColorTheirs;
  final Widget? footerExtra;

  const ChatMessageBubble({
    super.key,
    required this.text,
    required this.mine,
    this.createdAt,
    this.attachment = const ChatAttachment(),
    this.senderName,
    this.mineColor = const Color(0xFF1A237E),
    this.theirsColor = const Color(0xFFECEFF1),
    this.mineTextColor,
    this.theirsTextColor,
    this.timeColorMine,
    this.timeColorTheirs,
    this.footerExtra,
  });

  @override
  Widget build(BuildContext context) {
    final isEnglish = LocaleService.instance.isEnglish;
    final onMine = mineTextColor ?? Colors.white;
    final onTheirs = theirsTextColor ?? Colors.black87;
    final fg = mine ? onMine : onTheirs;
    final timeFg = mine
        ? (timeColorMine ?? onMine.withValues(alpha: 0.75))
        : (timeColorTheirs ?? onTheirs.withValues(alpha: 0.55));
    final stamp = formatChatTimestamp(createdAt, isEnglish: isEnglish);

    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine ? mineColor : theirsColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((senderName ?? '').trim().isNotEmpty) ...[
              Text(
                senderName!.trim(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (attachment.hasMedia) ...[
              _AttachmentBody(
                attachment: attachment,
                foreground: fg,
                mine: mine,
              ),
              if (text.trim().isNotEmpty) const SizedBox(height: 6),
            ],
            if (text.trim().isNotEmpty)
              Text(
                text,
                style: TextStyle(color: fg, height: 1.35),
              ),
            if (footerExtra != null) ...[
              const SizedBox(height: 6),
              footerExtra!,
            ],
            if (stamp.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Text(
                  stamp,
                  style: TextStyle(fontSize: 10.5, color: timeFg),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentBody extends StatelessWidget {
  final ChatAttachment attachment;
  final Color foreground;
  final bool mine;

  const _AttachmentBody({
    required this.attachment,
    required this.foreground,
    required this.mine,
  });

  @override
  Widget build(BuildContext context) {
    final url = (attachment.url ?? '').trim();
    final name = (attachment.name ?? '').trim();

    switch (attachment.kind) {
      case ChatAttachmentKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => openChatUrl(url),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 180,
              errorBuilder: (context, error, stackTrace) => _LinkTile(
                icon: Icons.broken_image_outlined,
                title: context.t('تعذر عرض الصورة', 'Could not show image'),
                foreground: foreground,
                onTap: () => openChatUrl(url),
              ),
            ),
          ),
        );
      case ChatAttachmentKind.video:
        return _LinkTile(
          icon: Icons.play_circle_outline,
          title: name.isEmpty
              ? context.t('فيديو مرفق', 'Attached video')
              : name,
          foreground: foreground,
          onTap: () => openChatUrl(url),
        );
      case ChatAttachmentKind.file:
        return _LinkTile(
          icon: Icons.insert_drive_file_outlined,
          title: name.isEmpty
              ? context.t('ملف مرفق', 'Attached file')
              : name,
          foreground: foreground,
          onTap: () => openChatUrl(url),
        );
      case ChatAttachmentKind.location:
        return _LinkTile(
          icon: Icons.location_on_outlined,
          title: name.isEmpty
              ? context.t('موقع على الخريطة', 'Map location')
              : name,
          foreground: foreground,
          onTap: () => openChatUrl(url),
        );
      case ChatAttachmentKind.none:
        return const SizedBox.shrink();
    }
  }
}

class _LinkTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color foreground;
  final VoidCallback onTap;

  const _LinkTile({
    required this.icon,
    required this.title,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: foreground.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: foreground.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Icon(Icons.open_in_new, size: 16, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}

typedef ChatSendAttachment = Future<void> Function(ChatAttachment attachment);

/// شريط إدخال موحّد: نص + إيموجي + مرفقات.
class ChatComposerBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ChatSendAttachment? onSendAttachment;
  final Color accentColor;
  final String hintText;
  final List<Widget> leadingActions;

  /// Public community replies: only images and PDF up to 5 MB, no video,
  /// audio, other files or map links. Uploads go to community_uploads/.
  final bool restrictedAttachments;

  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
    this.onSendAttachment,
    this.accentColor = const Color(0xFF1A237E),
    this.hintText = '',
    this.leadingActions = const [],
    this.restrictedAttachments = false,
  });

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  bool _uploading = false;

  bool get _busy => widget.sending || _uploading;

  Future<void> _insertEmoji() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.t('اختر إيموجي', 'Pick an emoji'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: GridView.builder(
                    itemCount: kChatEmojiPalette.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemBuilder: (_, i) {
                      final e = kChatEmojiPalette[i];
                      return InkWell(
                        onTap: () => Navigator.pop(ctx, e),
                        borderRadius: BorderRadius.circular(8),
                        child: Center(
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (emoji == null || !mounted) return;
    final c = widget.controller;
    final text = c.text;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final next = text.replaceRange(start, end, emoji);
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _showAttachMenu() async {
    if (widget.onSendAttachment == null || _busy) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile({
          required IconData icon,
          required String title,
          required String value,
        }) {
          return ListTile(
            leading: Icon(icon),
            title: Text(title),
            onTap: () => Navigator.pop(ctx, value),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              tile(
                icon: Icons.photo_outlined,
                title: ctx.t('صورة', 'Photo'),
                value: 'image',
              ),
              if (!widget.restrictedAttachments)
                tile(
                  icon: Icons.videocam_outlined,
                  title: ctx.t('فيديو', 'Video'),
                  value: 'video',
                ),
              tile(
                icon: Icons.attach_file,
                title: widget.restrictedAttachments
                    ? ctx.t('ملف PDF', 'PDF file')
                    : ctx.t('ملف', 'File'),
                value: 'file',
              ),
              if (!widget.restrictedAttachments)
                tile(
                  icon: Icons.location_on_outlined,
                  title: ctx.t('موقع / رابط خريطة', 'Location / map link'),
                  value: 'location',
                ),
            ],
          ),
        );
      },
    );
    if (choice == null || !mounted) return;
    try {
      switch (choice) {
        case 'image':
          await _pickAndUploadImage();
        case 'video':
          await _pickAndUploadVideo();
        case 'file':
          await _pickAndUploadFile();
        case 'location':
          await _shareLocation();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _emit(ChatAttachment attachment) async {
    final cb = widget.onSendAttachment;
    if (cb == null) return;
    setState(() => _uploading = true);
    try {
      await cb(attachment);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final file = await StorageService.instance.pickImage();
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final url = widget.restrictedAttachments
        ? await StorageService.instance.uploadCommunityBytes(
            bytes: bytes,
            fileName: communityAttachmentExtension(file.name) == null
                ? 'image.jpg'
                : file.name,
          )
        : await StorageService.instance.uploadChatBytes(
            bytes: bytes,
            fileName: file.name,
            contentType: _guessImageMime(file.name),
          );
    await _emit(
      ChatAttachment(
        kind: ChatAttachmentKind.image,
        url: url,
        name: file.name,
        mime: _guessImageMime(file.name),
      ),
    );
  }

  Future<void> _pickAndUploadVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final url = await StorageService.instance.uploadChatBytes(
      bytes: bytes,
      fileName: file.name.isEmpty ? 'video.mp4' : file.name,
      contentType: 'video/mp4',
    );
    await _emit(
      ChatAttachment(
        kind: ChatAttachmentKind.video,
        url: url,
        name: file.name.isEmpty ? 'video.mp4' : file.name,
        mime: 'video/mp4',
      ),
    );
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: widget.restrictedAttachments ? FileType.custom : FileType.any,
      allowedExtensions: widget.restrictedAttachments ? const ['pdf'] : null,
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null) {
      if (!mounted) return;
      throw Exception(
        context.t(
          'تعذر قراءة الملف على هذا الجهاز',
          'Could not read the file on this device',
        ),
      );
    }
    final name = f.name;
    final mime = _guessFileMime(name);
    final url = widget.restrictedAttachments
        ? await StorageService.instance.uploadCommunityBytes(
            bytes: bytes,
            fileName: name,
          )
        : await StorageService.instance.uploadChatBytes(
            bytes: bytes,
            fileName: name,
            contentType: mime,
          );
    await _emit(
      ChatAttachment(
        kind: ChatAttachmentKind.file,
        url: url,
        name: name,
        mime: mime,
      ),
    );
  }

  Future<void> _shareLocation() async {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(ctx.t('إرفاق موقع', 'Attach location')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: ctx.t('وصف المكان (اختياري)', 'Place label (optional)'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: InputDecoration(
                  labelText: ctx.t(
                    'رابط خرائط Google / Apple',
                    'Google / Apple Maps link',
                  ),
                  hintText: 'https://maps.google.com/...',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('إرسال', 'Send')),
            ),
          ],
        );
      },
    );
    final url = urlCtrl.text.trim();
    final name = nameCtrl.text.trim();
    nameCtrl.dispose();
    urlCtrl.dispose();
    if (ok != true) return;
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('أدخل رابط الموقع أولاً', 'Enter a map link first'),
          ),
        ),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.t('رابط الموقع غير صالح', 'Invalid map link'),
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    final placeLabel = name.isEmpty
        ? context.t('موقع على الخريطة', 'Map location')
        : name;
    await _emit(
      ChatAttachment(
        kind: ChatAttachmentKind.location,
        url: url,
        name: placeLabel,
        mime: 'text/uri-list',
      ),
    );
  }

  String _guessImageMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  String _guessFileMime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt' => 'text/plain',
      'zip' => 'application/zip',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.hintText.isEmpty
        ? context.t('اكتب رسالة...', 'Type a message...')
        : widget.hintText;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ...widget.leadingActions,
            if (widget.onSendAttachment != null)
              IconButton(
                tooltip: context.t('مرفق', 'Attachment'),
                onPressed: _busy ? null : _showAttachMenu,
                icon: _uploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: widget.accentColor,
                        ),
                      )
                    : Icon(Icons.attach_file, color: widget.accentColor),
              ),
            IconButton(
              tooltip: context.t('إيموجي', 'Emoji'),
              onPressed: _busy ? null : _insertEmoji,
              icon: Icon(Icons.emoji_emotions_outlined, color: widget.accentColor),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 4,
                enabled: !_busy,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) {
                  if (!_busy) widget.onSend();
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton.filled(
              onPressed: _busy ? null : widget.onSend,
              style: IconButton.styleFrom(
                backgroundColor: widget.accentColor,
              ),
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
