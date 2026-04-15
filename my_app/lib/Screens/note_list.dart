// lib/screens/note_list.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:my_app/screens/note_detail.dart';
import 'package:my_app/models/note_model.dart';
import 'package:my_app/services/api_service.dart';

// ── Theme constants ───────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1E1E2E);
  static const surface2 = Color(0xFF252538);
  static const border = Color(0xFF2A2A3E);
  static const accent = Color(0xFF6C63FF);
  static const textPrimary = Color(0xFFF0F0FF);
  static const textSecondary = Color(0xFF8888AA);
  static const red = Color(0xFFE63946);
  static const green = Color(0xFF2EC4B6);
  static const amber = Color(0xFFFF9F1C);
}

class NoteList extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => NoteListState();
}

class NoteListState extends State<NoteList> {
  List<Note> allNotes = [];
  List<Note> filteredNotes = [];
  bool isLoading = true;
  final ApiService apiService = ApiService();

  final TextEditingController searchController = TextEditingController();
  String selectedCategory = 'All';
  String sortBy = 'date';
  bool sortAscending = false;

  final List<String> categories = [
    'All', 'Work', 'Personal', 'Study', 'Ideas', 'Important'
  ];

  // Category colors
  Color _catColor(String cat) {
    switch (cat) {
      case 'Work': return const Color(0xFF2196F3);
      case 'Study': return const Color(0xFF9C27B0);
      case 'Ideas': return const Color(0xFFFF9800);
      case 'Important': return const Color(0xFFE91E63);
      case 'Personal': return _C.green;
      default: return _C.accent;
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
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
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => isLoading = true);
    try {
      final loaded = await apiService.getNotes();
      setState(() { allNotes = loaded; _filterNotes(); isLoading = false; });
    } catch (e) {
      setState(() => isLoading = false);
      _showError('Failed to load notes: $e');
    }
  }

  void _filterNotes() {
    final term = searchController.text.toLowerCase();
    setState(() {
      filteredNotes = allNotes.where((n) {
        if (selectedCategory != 'All' && n.category != selectedCategory) return false;
        if (term.isNotEmpty) {
          return n.title.toLowerCase().contains(term) ||
              n.description.toLowerCase().contains(term);
        }
        return true;
      }).toList();
      _sortNotes();
    });
  }

  void _sortNotes() {
    filteredNotes.sort((a, b) {
      int c;
      switch (sortBy) {
        case 'title': c = a.title.compareTo(b.title); break;
        case 'priority':
          c = (a.priority == 'High' ? 1 : 0)
              .compareTo(b.priority == 'High' ? 1 : 0);
          break;
        default: c = b.date.compareTo(a.date); break;
      }
      return sortAscending ? c : -c;
    });
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Error',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(msg, style: const TextStyle(color: _C.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK',
                style: TextStyle(color: _C.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _C.bg,
        colorScheme: const ColorScheme.dark(primary: _C.accent),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: isLoading
            ? const Center(child: CircularProgressIndicator(color: _C.accent))
            : CustomScrollView(
          slivers: [
            _buildSliverHeader(),
            _buildSearchBar(),
            _buildCategoryBar(),
            _buildSortBar(),
            filteredNotes.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState())
                : SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _buildNoteCard(filteredNotes[i]),
                  childCount: filteredNotes.length,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: _C.surface,
      elevation: 0,
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _C.border)),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.sticky_note_2_outlined,
                  color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            const Text('Notes',
                style: TextStyle(
                    color: _C.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22)),
            const SizedBox(width: 10),
            if (!isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${filteredNotes.length}',
                    style: const TextStyle(
                        color: _C.accent, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF1E1E2E)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Container(
          decoration: BoxDecoration(
            color: _C.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
          ),
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: _C.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search notes...',
              hintStyle: const TextStyle(color: _C.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: _C.textSecondary, size: 20),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: _C.textSecondary, size: 18),
                onPressed: () {
                  searchController.clear();
                  _filterNotes();
                },
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: categories.length,
          itemBuilder: (ctx, i) {
            final cat = categories[i];
            final selected = selectedCategory == cat;
            final color = cat == 'All' ? _C.accent : _catColor(cat);
            return GestureDetector(
              onTap: () => setState(() { selectedCategory = cat; _filterNotes(); }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                decoration: BoxDecoration(
                  color: selected ? color.withOpacity(0.2) : _C.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? color : _C.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (cat != 'All') ...[
                      Icon(_catIcon(cat), size: 12,
                          color: selected ? color : _C.textSecondary),
                      const SizedBox(width: 5),
                    ],
                    Text(cat,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? color : _C.textSecondary)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Row(
          children: [
            const Text('Sort',
                style: TextStyle(color: _C.textSecondary, fontSize: 12)),
            const SizedBox(width: 8),
            ...[
              ('date', 'Date'),
              ('title', 'Title'),
              ('priority', 'Priority'),
            ].map((e) {
              final selected = sortBy == e.$1;
              return GestureDetector(
                onTap: () => setState(() { sortBy = e.$1; _sortNotes(); }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? _C.accent.withOpacity(0.15) : _C.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? _C.accent : _C.border),
                  ),
                  child: Text(e.$2,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? _C.accent : _C.textSecondary)),
                ),
              );
            }),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() { sortAscending = !sortAscending; _sortNotes(); }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _C.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Icon(
                  sortAscending
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 14,
                  color: _C.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    final bool hasImages = note.imagePaths.isNotEmpty;
    final bool hasSketch = note.sketchData?.isNotEmpty == true;
    final Color catColor = _catColor(note.category);

    Uint8List? thumb;
    if (hasImages) {
      try { thumb = base64Decode(note.imagePaths.first); } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: InkWell(
        onTap: () => _navigateToDetail('Edit Note', note),
        borderRadius: BorderRadius.circular(16),
        splashColor: _C.accent.withOpacity(0.08),
        highlightColor: _C.accent.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail or priority indicator
              thumb != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(thumb,
                    width: 48, height: 48, fit: BoxFit.cover),
              )
                  : Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: catColor.withOpacity(0.25)),
                ),
                child: Icon(_catIcon(note.category),
                    color: catColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + priority dot
                    Row(
                      children: [
                        Expanded(
                          child: Text(note.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _C.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                        ),
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: note.priority == 'High'
                                ? _C.red : _C.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Date + category
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 11, color: _C.textSecondary),
                        const SizedBox(width: 4),
                        Text(note.date,
                            style: const TextStyle(
                                color: _C.textSecondary, fontSize: 11)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(note.category,
                              style: TextStyle(
                                  color: catColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Description preview
                    Text(note.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _C.textSecondary,
                            fontSize: 12,
                            height: 1.5)),
                    // Attachment badges
                    if (hasImages || hasSketch) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (hasImages)
                            _Badge(
                                icon: Icons.photo_rounded,
                                label: '${note.imagePaths.length}',
                                color: const Color(0xFF2196F3)),
                          if (hasImages && hasSketch)
                            const SizedBox(width: 6),
                          if (hasSketch)
                            const _Badge(
                                icon: Icons.gesture_rounded,
                                label: 'Sketch',
                                color: Color(0xFF9C27B0)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Action column
              Column(
                children: [
                  _CardBtn(
                    icon: Icons.edit_outlined,
                    color: _C.accent,
                    onTap: () => _navigateToDetail('Edit Note', note),
                  ),
                  const SizedBox(height: 6),
                  _CardBtn(
                    icon: Icons.delete_outline_rounded,
                    color: _C.red.withOpacity(0.7),
                    onTap: () => _showDeleteDialog(note),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool isFiltered =
        searchController.text.isNotEmpty || selectedCategory != 'All';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.search_off_rounded : Icons.note_add_outlined,
              size: 36, color: _C.accent.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No matching notes' : 'No notes yet',
            style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Try adjusting your search or filters'
                : 'Tap + to create your first note',
            style: const TextStyle(color: _C.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _C.accent.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _navigateToDetail('Add Note', null),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text('New Note',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    );
  }

  void _showDeleteDialog(Note note) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Note',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Delete "${note.title}"?',
            style: const TextStyle(color: _C.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel',
                style: TextStyle(color: _C.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => isLoading = true);
              try {
                await apiService.deleteNote(note.id!);
                await _loadNotes();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _C.surface2,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: const Row(children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: _C.green, size: 16),
                      SizedBox(width: 8),
                      Text('Note deleted',
                          style: TextStyle(color: Colors.white)),
                    ]),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                setState(() => isLoading = false);
                _showError('Failed to delete note: $e');
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: _C.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(String title, Note? note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetail(title, note: note)),
    ).then((r) { if (r != null) _loadNotes(); });
  }
}

// ── Small card action button ──────────────────────────────────────────────────
class _CardBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CardBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }
}

// ── Attachment badge ──────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}