// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/note_model.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  // ── Helper: throw a readable exception from any non-2xx response ────────
  Never _throwFromResponse(http.Response response, String action) {
    String detail = '';
    try {
      final body = json.decode(response.body);
      detail = body['detail'] ?? body['error'] ?? response.body;
    } catch (_) {
      detail = response.body;
    }
    throw Exception('$action failed (${response.statusCode}): $detail');
  }

  // GET all notes
  Future<List<Note>> getNotes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notes'));
      if (response.statusCode == 200) {
        return (json.decode(response.body) as List)
            .map((j) => Note.fromJson(j))
            .toList();
      }
      _throwFromResponse(response, 'Get notes');
    } catch (e) {
      throw Exception('Failed to load notes: $e');
    }
  }

  // POST create note
  Future<Note> createNote(Note note) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(note.toJson()),
      );
      if (response.statusCode == 201) {
        note.id = json.decode(response.body)['id'];
        return note;
      }
      _throwFromResponse(response, 'Create note');
    } catch (e) {
      // Re-throw with the real message intact
      rethrow;
    }
  }

  // PUT update note
  Future<void> updateNote(Note note) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notes/${note.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(note.toJson()),
      );
      if (response.statusCode != 200) {
        _throwFromResponse(response, 'Update note');
      }
    } catch (e) {
      rethrow;
    }
  }

  // DELETE note
  Future<void> deleteNote(int id) async {
    try {
      final response =
      await http.delete(Uri.parse('$baseUrl/notes/$id'));
      if (response.statusCode != 200) {
        _throwFromResponse(response, 'Delete note');
      }
    } catch (e) {
      rethrow;
    }
  }
}