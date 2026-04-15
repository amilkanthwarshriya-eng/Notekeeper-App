// lib/screens/drawing_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class DrawingScreen extends StatefulWidget {
  final Uint8List? existingSketch;
  const DrawingScreen({this.existingSketch, super.key});

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen>
    with SingleTickerProviderStateMixin {
  late SignatureController _controller;

  Color _selectedColor = const Color(0xFF1A1A2E);
  double _strokeWidth = 4.0;
  bool _isEraser = false;
  bool _isSaving = false;

  late AnimationController _toolbarAnim;
  bool _toolbarVisible = true;

  static const Color _canvasBg = Color(0xFFFDFBF7);

  final List<Color> _colorSwatches = const [
    Color(0xFF1A1A2E),
    Color(0xFFE63946),
    Color(0xFF2196F3),
    Color(0xFF2D6A4F),
    Color(0xFFFF9F1C),
    Color(0xFF7B2D8B),
    Color(0xFF795548),
    Color(0xFFE91E8C),
    Color(0xFF00BCD4),
    Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _initController();
    _toolbarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
  }

  void _initController() {
    final penColor = _isEraser ? _canvasBg : _selectedColor;
    final penWidth = _isEraser ? _strokeWidth * 2.5 : _strokeWidth;

    _controller = SignatureController(
      penStrokeWidth: penWidth,
      penColor: penColor,
      exportBackgroundColor: _canvasBg,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _toolbarAnim.dispose();
    super.dispose();
  }

  // Recreate controller when properties change (drawing will be lost)
  void _recreateController() {
    _controller.dispose();
    _initController();
    setState(() {});
  }

  void _setPenColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isEraser = false;
    });
    _recreateController();
  }

  void _setStrokeWidth(double width) {
    setState(() => _strokeWidth = width);
    _recreateController();
  }

  void _toggleEraser() {
    setState(() => _isEraser = !_isEraser);
    _recreateController();
  }

  void _undo() {
    _controller.undo();
    setState(() {});
  }

  void _clearCanvas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Canvas',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('This will erase your entire sketch.',
            style: TextStyle(color: Color(0xFFAAAAAA))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              _controller.clear();
              setState(() {});
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear',
                style: TextStyle(color: Color(0xFFE63946), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSketch() async {
    if (_controller.isEmpty) {
      _showSnack('Nothing to save — draw something first!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      Uint8List? data = await _controller.toPngBytes();

      if (data == null) {
        await Future.delayed(const Duration(milliseconds: 100));
        data = await _controller.toPngBytes();
      }

      if (data == null) {
        data = await _controller.toPngBytes(height: 1200, width: 1800);
      }

      if (!mounted) return;

      if (data == null || data.isEmpty) {
        setState(() => _isSaving = false);
        _showSnack('Export failed — please try again.');
        return;
      }

      setState(() => _isSaving = false);
      Navigator.pop(context, data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Error saving sketch: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2A2A3E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _toggleToolbar() {
    setState(() => _toolbarVisible = !_toolbarVisible);
    _toolbarVisible ? _toolbarAnim.forward() : _toolbarAnim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildCanvas()),
            SizeTransition(
              sizeFactor: _toolbarAnim,
              axisAlignment: -1,
              child: _buildToolbar(),
            ),
            _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        border: Border(bottom: BorderSide(color: Color(0xFF2A2A3E))),
      ),
      child: Row(
        children: [
          _TopBarBtn(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              if (_controller.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E1E2E),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Discard sketch?',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    content: const Text(
                        'Your drawing will be lost if you go back without saving.',
                        style: TextStyle(color: Color(0xFFAAAAAA))),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Keep drawing',
                            style: TextStyle(color: Color(0xFF6C63FF))),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.pop(context, null);
                        },
                        child: const Text('Discard',
                            style: TextStyle(color: Color(0xFFE63946))),
                      ),
                    ],
                  ),
                );
              } else {
                Navigator.pop(context, null);
              }
            },
          ),
          const SizedBox(width: 10),
          const Text('Canvas',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
          const Spacer(),
          _TopBarBtn(icon: Icons.undo_rounded, onTap: _undo, tooltip: 'Undo'),
          const SizedBox(width: 6),
          _TopBarBtn(
              icon: Icons.layers_clear_rounded,
              onTap: _clearCanvas,
              tooltip: 'Clear'),
          const SizedBox(width: 6),
          _TopBarBtn(
            icon: _toolbarVisible
                ? Icons.keyboard_arrow_down_rounded
                : Icons.keyboard_arrow_up_rounded,
            onTap: _toggleToolbar,
            tooltip: 'Toggle tools',
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
      decoration: BoxDecoration(
        color: _canvasBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            CustomPaint(
                painter: _DotGridPainter(), child: const SizedBox.expand()),
            Signature(controller: _controller, backgroundColor: Colors.transparent),
            if (_isEraser)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_fix_high, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Eraser active',
                            style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        border: Border(
          top: BorderSide(color: Color(0xFF2A2A3E)),
          bottom: BorderSide(color: Color(0xFF2A2A3E)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFF3A3A4E),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              GestureDetector(
                onTap: _toggleEraser,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isEraser
                        ? const Color(0xFF6C63FF).withOpacity(0.2)
                        : const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isEraser
                          ? const Color(0xFF6C63FF)
                          : const Color(0xFF3A3A4E),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isEraser ? Icons.auto_fix_high : Icons.edit_rounded,
                    color: _isEraser ? const Color(0xFF6C63FF) : Colors.white60,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: (_strokeWidth / 20 * 18).clamp(4.0, 18.0),
                    height: (_strokeWidth / 20 * 18).clamp(4.0, 18.0),
                    decoration: BoxDecoration(
                      color: _isEraser ? Colors.white38 : _selectedColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF6C63FF),
                    inactiveTrackColor: const Color(0xFF2A2A3E),
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
                    trackHeight: 3,
                    thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                  ),
                  child: Slider(
                    value: _strokeWidth,
                    min: 1,
                    max: 20,
                    onChanged: _setStrokeWidth,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${_strokeWidth.round()}px',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    textAlign: TextAlign.right),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _colorSwatches.map((color) {
              final bool selected = !_isEraser && _selectedColor == color;
              return GestureDetector(
                onTap: () => _setPenColor(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 34 : 26,
                  height: selected ? 34 : 26,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5),
                    boxShadow: selected
                        ? [
                      BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2)
                    ]
                        : [],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: const Color(0xFF0F0F1A),
      child: GestureDetector(
        onTap: _isSaving ? null : _saveSketch,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 52,
          decoration: BoxDecoration(
            gradient: _isSaving
                ? const LinearGradient(
                colors: [Color(0xFF3A3A5E), Color(0xFF3A3A5E)])
                : const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSaving
                ? []
                : [
              BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Center(
            child: _isSaving
                ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white60),
                ),
                SizedBox(width: 12),
                Text('Saving sketch...',
                    style: TextStyle(
                        color: Colors.white60,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            )
                : const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_alt_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Save Sketch',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _TopBarBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBBBBBB).withOpacity(0.35);
    const spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}