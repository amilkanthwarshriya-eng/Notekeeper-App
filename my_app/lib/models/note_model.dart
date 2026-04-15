// lib/models/note_model.dart
class Note {
  int? id;
  String title;
  String description;
  String priority;
  String date;
  String category;

  // New fields for images and sketches
  // Images are stored as base64-encoded strings (comma-separated or as a List)
  List<String> imagePaths;
  // Sketch stored as a base64-encoded PNG
  String? sketchData;

  Note({
    this.id,
    required this.title,
    required this.description,
    required this.priority,
    required this.date,
    required this.category,
    this.imagePaths = const [],
    this.sketchData,
  });

  // Convert Note to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'priority': priority,
      'date': date,
      'category': category,
      'image_paths': imagePaths,
      'sketch_data': sketchData,
    };
  }

  // Create Note from JSON (API response)
  factory Note.fromJson(Map<String, dynamic> json) {
    // Handle image_paths which may be stored as a JSON array or null
    List<String> images = [];
    if (json['image_paths'] != null) {
      if (json['image_paths'] is List) {
        images = List<String>.from(json['image_paths']);
      }
    }

    return Note(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'Low',
      date: json['date'] ?? '',
      category: json['category'] ?? 'Personal',
      imagePaths: images,
      sketchData: json['sketch_data'],
    );
  }
}