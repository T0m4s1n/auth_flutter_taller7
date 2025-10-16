import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document.dart';

class DocumentService {
  static const String _storageKey = 'river_documents';
  List<RiverDocument> _documents = [];

  DocumentService() {
    _loadDocuments();
  }

  // Cargar documentos desde SharedPreferences
  Future<void> _loadDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final documentsJson = prefs.getStringList(_storageKey) ?? [];
      
      if (documentsJson.isEmpty) {
        // Crear documentos de ejemplo si no hay ninguno
        _documents = [
          RiverDocument(
            id: '1',
            title: 'Bienvenido a River',
            content: '¡Hola! Este es tu primer documento en River. Puedes empezar escribiendo aquí...\n\n## Características:\n- Editor tipo Notion\n- Chat con IA contextual\n- Soporte para imágenes\n- Búsqueda inteligente',
            tags: ['inicio', 'river'],
          ),
          RiverDocument(
            id: '2',
            title: 'Notas de la reunión',
            content: '## Puntos principales\n\n- Tema 1: Discusión importante\n- Tema 2: Decisiones tomadas\n- Tema 3: Próximos pasos\n\n## Acciones:\n1. Revisar propuesta\n2. Contactar cliente\n3. Preparar presentación',
            tags: ['trabajo', 'reunión'],
          ),
        ];
        await _saveDocuments();
      } else {
        _documents = documentsJson
            .map((json) => RiverDocument.fromJson(jsonDecode(json)))
            .toList();
      }
    } catch (e) {
      print('Error cargando documentos: $e');
      _documents = [];
    }
  }

  // Obtener todos los documentos
  List<RiverDocument> getAllDocuments() {
    return List.from(_documents);
  }

  // Obtener documento por ID
  RiverDocument? getDocumentById(String id) {
    try {
      return _documents.firstWhere((doc) => doc.id == id);
    } catch (e) {
      return null;
    }
  }

  // Crear nuevo documento
  Future<RiverDocument> createDocument({
    String? title,
    String? content,
    List<String>? tags,
  }) async {
    final newDocument = RiverDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Nuevo documento',
      content: content ?? '',
      tags: tags ?? [],
    );

    _documents.insert(0, newDocument);
    await _saveDocuments();
    return newDocument;
  }

  // Actualizar documento
  Future<void> updateDocument(RiverDocument document) async {
    final index = _documents.indexWhere((doc) => doc.id == document.id);
    if (index != -1) {
      _documents[index] = document;
      await _saveDocuments();
    }
  }

  // Eliminar documento
  Future<void> deleteDocument(String id) async {
    _documents.removeWhere((doc) => doc.id == id);
    await _saveDocuments();
  }

  // Buscar documentos
  List<RiverDocument> searchDocuments(String query) {
    if (query.isEmpty) return _documents;

    final lowercaseQuery = query.toLowerCase();
    return _documents.where((doc) {
      return doc.title.toLowerCase().contains(lowercaseQuery) ||
             doc.content.toLowerCase().contains(lowercaseQuery) ||
             doc.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  // Obtener documentos por tag
  List<RiverDocument> getDocumentsByTag(String tag) {
    return _documents.where((doc) => doc.tags.contains(tag)).toList();
  }

  // Obtener todos los tags únicos
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final doc in _documents) {
      allTags.addAll(doc.tags);
    }
    return allTags.toList()..sort();
  }

  // Guardar documentos en SharedPreferences
  Future<void> _saveDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final documentsJson = _documents
          .map((doc) => jsonEncode(doc.toJson()))
          .toList();
      await prefs.setStringList(_storageKey, documentsJson);
      print('Documentos guardados: ${_documents.length}');
    } catch (e) {
      print('Error guardando documentos: $e');
    }
  }

  // Duplicar documento
  Future<RiverDocument> duplicateDocument(String id) async {
    final original = getDocumentById(id);
    if (original == null) {
      throw Exception('Documento no encontrado');
    }

    final duplicated = RiverDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '${original.title} (Copia)',
      content: original.content,
      tags: List.from(original.tags),
      coverImage: original.coverImage,
    );

    _documents.insert(0, duplicated);
    await _saveDocuments();
    return duplicated;
  }
}
