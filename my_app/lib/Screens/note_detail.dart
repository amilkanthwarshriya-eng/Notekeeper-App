// lib/screens/note_detail.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/note_model.dart';
import 'package:my_app/Screens/drawing_screen.dart';
import 'package:my_app/services/api_service.dart';

// ── Theme constants ───────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1E1E2E);
  static const surface2 = Color(0xFF252538);
  static const border = Color(0xFF2A2A3E);
  static const accent = Color(0xFF6C63FF);
  static const accentSoft = Color(0x266C63FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const red = Color(0xFFE63946);
  static const green = Color(0xFF2EC4B6);
  static const amber = Color(0xFFFF9F1C);
}

class NoteDetail extends StatefulWidget {
  final String appBarTitle;
  final Note? note;
  const NoteDetail(this.appBarTitle, {this.note, super.key});

  @override
  State<NoteDetail> createState() => NoteDetailState();
}

class NoteDetailState extends State<NoteDetail> {
  static const _priorities = ['High', 'Low'];
  static const _categories = [
    'Work', 'Personal', 'Study', 'Ideas', 'Important'
  ];

  late String appBarTitle;
  late String priority;
  late String category;
  bool isLoading = false;

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  bool isBold = false;
  bool isItalic = false;
  bool isUnderline = false;

  final List<String> _attachedImages = [];
  Uint8List? _sketchBytes;
  final ImagePicker _imagePicker = ImagePicker();
  final ApiService apiService = ApiService();

  // Priority / category color helpers
  Color get _priorityColor =>
      priority == 'High' ? _C.red : _C.green;

  IconData get _categoryIcon {
    switch (category) {
      case 'Work': return Icons.work_outline_rounded;
      case 'Study': return Icons.school_outlined;
      case 'Ideas': return Icons.lightbulb_outline_rounded;
      case 'Important': return Icons.star_outline_rounded;
      default: return Icons.person_outline_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    appBarTitle = widget.appBarTitle;
    if (widget.note != null) {
      titleController.text = widget.note!.title;
      descriptionController.text = widget.note!.description;
      priority = widget.note!.priority;
      category = widget.note!.category;
      _attachedImages.addAll(widget.note!.imagePaths);
      if (widget.note!.sketchData?.isNotEmpty == true) {
        _sketchBytes = base64Decode(widget.note!.sketchData!);
      }
    } else {
      priority = 'Low';
      category = 'Personal';
    }
  }

  // ── Image helpers ─────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
          source: source, imageQuality: 75, maxWidth: 1200, maxHeight: 1200);
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      setState(() => _attachedImages.add(base64Encode(bytes)));
    } catch (e) {
      _showAlert('Error', 'Failed to pick image: $e');
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(2))),
              _SheetTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
              ),
              _SheetTile(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _viewImageFullscreen(String b64) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          Center(child: InteractiveViewer(child: Image.memory(base64Decode(b64)))),
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.close, color: Colors.white, size: 22),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Sketch helpers ────────────────────────────────────────────────────────
  Future<void> _openDrawing() async {
    final result = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => DrawingScreen(existingSketch: _sketchBytes)),
    );
    if (result != null) setState(() => _sketchBytes = result);
  }

  void _removeSketch() {
    showDialog(
      context: context,
      builder: (ctx) => _DarkDialog(
        title: 'Remove Sketch',
        message: 'Are you sure you want to remove the sketch?',
        confirmLabel: 'Remove',
        confirmColor: _C.red,
        onConfirm: () { setState(() => _sketchBytes = null); Navigator.of(ctx).pop(); },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // ── Save / Delete ─────────────────────────────────────────────────────────
  Future<void> _saveNote() async {
    if (titleController.text.isEmpty) {
      _showAlert('Missing Title', 'Please enter a title for your note.'); return;
    }
    if (descriptionController.text.isEmpty) {
      _showAlert('Missing Content', 'Please write something in the description.'); return;
    }
    setState(() => isLoading = true);
    try {
      final note = Note(
        id: widget.note?.id,
        title: titleController.text,
        description: descriptionController.text,
        priority: priority,
        date: DateTime.now().toString().split(' ')[0],
        category: category,
        imagePaths: List<String>.from(_attachedImages),
        sketchData: _sketchBytes != null ? base64Encode(_sketchBytes!) : null,
      );
      if (widget.note == null) {
        await apiService.createNote(note);
      } else {
        await apiService.updateNote(note);
      }
      setState(() => isLoading = false);
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => isLoading = false);
      _showAlert('Error', 'Failed to save note: $e');
    }
  }

  void _deleteNote() {
    if (widget.note == null) { Navigator.pop(context); return; }
    showDialog(
      context: context,
      builder: (ctx) => _DarkDialog(
        title: 'Delete Note',
        message: 'This note will be permanently deleted.',
        confirmLabel: 'Delete',
        confirmColor: _C.red,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          setState(() => isLoading = true);
          try {
            await apiService.deleteNote(widget.note!.id!);
            setState(() => isLoading = false);
            Navigator.pop(context, true);
          } catch (e) {
            setState(() => isLoading = false);
            _showAlert('Error', 'Failed to delete: $e');
          }
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  // ── Formatting ────────────────────────────────────────────────────────────
  TextStyle _textStyle() {
    var s = const TextStyle(color: _C.textPrimary, fontSize: 15, height: 1.6);
    if (isBold) s = s.copyWith(fontWeight: FontWeight.bold);
    if (isItalic) s = s.copyWith(fontStyle: FontStyle.italic);
    if (isUnderline) s = s.copyWith(decoration: TextDecoration.underline);
    return s;
  }

  void _insertFormatting(String type) {
    final text = descriptionController.text;
    final start = descriptionController.selection.baseOffset;
    final end = descriptionController.selection.extentOffset;
    if (start < 0 || end > text.length || start == end) return;
    final sel = text.substring(start, end);
    final fmt = type == 'bold' ? '**$sel**'
        : type == 'italic' ? '*$sel*'
        : '_${sel}_';
    descriptionController.text = text.replaceRange(start, end, fmt);
    descriptionController.selection =
        TextSelection.collapsed(offset: start + fmt.length);
  }

  void _insertBullet() {
    final text = descriptionController.text;
    int pos = descriptionController.selection.baseOffset;
    if (pos < 0) pos = text.length;
    final newText = '${text.substring(0, pos)}\n• ${text.substring(pos)}';
    descriptionController.text = newText;
    descriptionController.selection =
        TextSelection.collapsed(offset: pos + 3);
  }

  // ── Back confirm ──────────────────────────────────────────────────────────
  void _confirmBack() {
    final dirty = (titleController.text.isNotEmpty || descriptionController.text.isNotEmpty) &&
        (widget.note == null ||
            titleController.text != widget.note!.title ||
            descriptionController.text != widget.note!.description ||
            priority != widget.note!.priority ||
            category != widget.note!.category ||
            _attachedImages.length != widget.note!.imagePaths.length ||
            (_sketchBytes != null && widget.note!.sketchData == null));
    if (dirty) {
      showDialog(
        context: context,
        builder: (ctx) => _DarkDialog(
          title: 'Discard Changes?',
          message: 'Your unsaved changes will be lost.',
          confirmLabel: 'Discard',
          confirmColor: _C.amber,
          onConfirm: () { Navigator.of(ctx).pop(); Navigator.pop(context); },
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _showAlert(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => _DarkDialog(
        title: title,
        message: msg,
        confirmLabel: 'OK',
        confirmColor: _C.accent,
        onConfirm: () => Navigator.of(ctx).pop(),
        onCancel: null,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (!didPop) _confirmBack(); },
      child: Theme(
        data: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: _C.bg,
          colorScheme: const ColorScheme.dark(primary: _C.accent),
        ),
        child: Scaffold(
          backgroundColor: _C.bg,
          body: isLoading
              ? const Center(
              child: CircularProgressIndicator(color: _C.accent))
              : CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildMetaRow(),
                    const SizedBox(height: 16),
                    _buildTitleField(),
                    const SizedBox(height: 16),
                    _buildDescriptionCard(),
                    const SizedBox(height: 16),
                    _buildPhotosCard(),
                    const SizedBox(height: 16),
                    _buildSketchCard(),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
          bottomNavigationBar: isLoading ? null : _buildBottomBar(),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: _C.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: _confirmBack,
      ),
      title: Text(
        appBarTitle,
        style: const TextStyle(
            color: _C.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: 0.3),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.border),
      ),
    );
  }

  Widget _buildMetaRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          // Priority chip
          _DropChip<String>(
            value: priority,
            items: _priorities,
            color: _priorityColor,
            icon: priority == 'High'
                ? Icons.keyboard_double_arrow_up_rounded
                : Icons.keyboard_double_arrow_down_rounded,
            onChanged: (v) => setState(() => priority = v!),
          ),
          const SizedBox(width: 10),
          // Category chip
          _DropChip<String>(
            value: category,
            items: _categories,
            color: _C.accent,
            icon: _categoryIcon,
            onChanged: (v) => setState(() => category = v!),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: titleController,
        style: const TextStyle(
            color: _C.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          hintText: 'Note title...',
          hintStyle: TextStyle(color: _C.textSecondary, fontSize: 20, fontWeight: FontWeight.w700),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formatting toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _C.border)),
            ),
            child: Row(
              children: [
                _FmtBtn(
                  icon: Icons.format_bold,
                  active: isBold,
                  onTap: () { setState(() => isBold = !isBold); _insertFormatting('bold'); },
                ),
                _FmtBtn(
                  icon: Icons.format_italic,
                  active: isItalic,
                  onTap: () { setState(() => isItalic = !isItalic); _insertFormatting('italic'); },
                ),
                _FmtBtn(
                  icon: Icons.format_underline,
                  active: isUnderline,
                  onTap: () { setState(() => isUnderline = !isUnderline); _insertFormatting('underline'); },
                ),
                _FmtBtn(
                  icon: Icons.format_list_bulleted_rounded,
                  active: false,
                  onTap: _insertBullet,
                ),
                const SizedBox(width: 4),
                Container(width: 1, height: 20, color: _C.border),
                const SizedBox(width: 4),
                _FmtBtn(
                  icon: Icons.format_clear_rounded,
                  active: false,
                  onTap: () => setState(() { isBold = false; isItalic = false; isUnderline = false; }),
                ),
              ],
            ),
          ),
          // Text area
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: descriptionController,
              style: _textStyle(),
              maxLines: null,
              minLines: 6,
              decoration: const InputDecoration(
                hintText: 'Start writing your note...',
                hintStyle: TextStyle(color: _C.textSecondary, fontSize: 15),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard() {
    return _SectionCard(
      title: 'Photos',
      icon: Icons.photo_library_outlined,
      action: _ActionBtn(label: 'Add Photo', icon: Icons.add_photo_alternate_outlined, onTap: _showImageSourceSheet),
      child: _attachedImages.isEmpty
          ? _EmptyHint(icon: Icons.image_outlined, label: 'No photos yet')
          : SizedBox(
        height: 112,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _attachedImages.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (ctx, i) {
            final bytes = base64Decode(_attachedImages[i]);
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => _viewImageFullscreen(_attachedImages[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(bytes,
                        width: 104, height: 104, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _attachedImages.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 13),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSketchCard() {
    return _SectionCard(
      title: 'Sketch',
      icon: Icons.gesture_rounded,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionBtn(
            label: _sketchBytes == null ? 'Draw' : 'Edit',
            icon: _sketchBytes == null ? Icons.draw_outlined : Icons.edit_outlined,
            onTap: _openDrawing,
          ),
          if (_sketchBytes != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _removeSketch,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _C.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _C.red.withOpacity(0.3))),
                child: const Icon(Icons.delete_outline, color: _C.red, size: 16),
              ),
            ),
          ],
        ],
      ),
      child: _sketchBytes == null
          ? _EmptyHint(icon: Icons.draw_outlined, label: 'No sketch yet — tap Draw')
          : GestureDetector(
        onTap: _openDrawing,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(_sketchBytes!,
              width: double.infinity, height: 180, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: _C.surface,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          // Delete
          if (widget.note != null)
            GestureDetector(
              onTap: _deleteNote,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _C.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.red.withOpacity(0.3)),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _C.red, size: 22),
              ),
            ),
          if (widget.note != null) const SizedBox(width: 12),
          // Save
          Expanded(
            child: GestureDetector(
              onTap: _saveNote,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _C.accent.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Save Note',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            letterSpacing: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable dark dialog ──────────────────────────────────────────────────────
class _DarkDialog extends StatelessWidget {
  final String title, message, confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  const _DarkDialog({
    required this.title, required this.message,
    required this.confirmLabel, required this.confirmColor,
    required this.onConfirm, required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Text(message,
          style: const TextStyle(color: Color(0xFFAAAAAA))),
      actions: [
        if (onCancel != null)
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
        TextButton(
          onPressed: onConfirm,
          child: Text(confirmLabel,
              style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ── Drop-down chip (priority / category) ─────────────────────────────────────
class _DropChip<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final Color color;
  final IconData icon;
  final ValueChanged<T?> onChanged;
  const _DropChip({
    required this.value, required this.items,
    required this.color, required this.icon, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          dropdownColor: const Color(0xFF1E1E2E),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          icon: Icon(Icons.expand_more_rounded, color: color, size: 18),
          items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Row(children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(item.toString()),
              ]))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget action;
  final Widget child;
  const _SectionCard({
    required this.title, required this.icon,
    required this.action, required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: const Color(0xFF8888AA)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF8888AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8)),
                const Spacer(),
                action,
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF2A2A3E)),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ── Small action button ───────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Empty-state hint ──────────────────────────────────────────────────────────
class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyHint({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(children: [
          Icon(icon, size: 36, color: const Color(0xFF3A3A5E)),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF5A5A7E), fontSize: 13)),
        ]),
      ),
    );
  }
}

// ── Bottom-sheet tile ─────────────────────────────────────────────────────────
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
      ),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      onTap: onTap,
    );
  }
}

// ── Formatting button ─────────────────────────────────────────────────────────
class _FmtBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FmtBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 34, height: 34,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF6C63FF).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: active ? const Color(0xFF6C63FF) : const Color(0xFF6666AA)),
      ),
    );
  }
}