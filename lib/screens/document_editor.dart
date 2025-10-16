import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/document_service.dart';

class DocumentEditorScreen extends StatefulWidget {
  final RiverDocument document;
  final VoidCallback onDocumentUpdated;

  const DocumentEditorScreen({
    super.key,
    required this.document,
    required this.onDocumentUpdated,
  });

  @override
  State<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends State<DocumentEditorScreen> {
  final DocumentService _documentService = DocumentService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late RiverDocument _currentDocument;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.document;
    _titleController.text = _currentDocument.title;
    _contentController.text = _currentDocument.content;
    
    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onContentChanged);
  }

  void _onTitleChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  void _onContentChanged() {
    setState(() {
      _hasChanges = true;
    });
  }

  Future<void> _saveDocument() async {
    try {
      final updatedDocument = _currentDocument.copyWith(
        title: _titleController.text.trim(),
        content: _contentController.text,
      );

      await _documentService.updateDocument(updatedDocument);
      setState(() {
        _currentDocument = updatedDocument;
        _hasChanges = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documento guardado'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar documento'),
        content: const Text('¿Estás seguro de que quieres eliminar este documento? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDocument();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument() async {
    try {
      await _documentService.deleteDocument(_currentDocument.id);
      widget.onDocumentUpdated();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error eliminando: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () async {
            if (_hasChanges) {
              final shouldSave = await _showSaveDialog();
              if (shouldSave == true) {
                await _saveDocument();
              }
            }
            if (mounted) Navigator.pop(context);
          },
        ),
        title: const Text(
          'River',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.black),
              onPressed: _saveDocument,
              tooltip: 'Guardar cambios',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'delete':
                  _showDeleteDialog();
                  break;
                case 'duplicate':
                  // TODO: Implementar duplicar
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Text('Duplicar'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Título del documento
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
              ),
            ),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: 'Título del documento',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Contenido del documento
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  hintText: 'Escribe aquí...\n\nPuedes usar Markdown:\n# Título\n## Subtítulo\n**Negrita**\n*Cursiva*\n- Lista\n1. Lista numerada',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Documento modificado'),
        content: const Text('¿Quieres guardar los cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No guardar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
