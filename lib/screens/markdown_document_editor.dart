import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../services/gemini_service.dart';
import '../widgets/animated_menu.dart';

class AISuggestion {
  final String title;
  final String description;
  final String command;
  final IconData icon;

  AISuggestion({
    required this.title,
    required this.description,
    required this.command,
    required this.icon,
  });
}

class MarkdownDocumentEditorScreen extends StatefulWidget {
  final RiverDocument document;
  final VoidCallback onDocumentUpdated;

  const MarkdownDocumentEditorScreen({
    super.key,
    required this.document,
    required this.onDocumentUpdated,
  });

  @override
  State<MarkdownDocumentEditorScreen> createState() => _MarkdownDocumentEditorScreenState();
}

class _MarkdownDocumentEditorScreenState extends State<MarkdownDocumentEditorScreen>
    with TickerProviderStateMixin {
  final DocumentService _documentService = DocumentService();
  final GeminiService _geminiService = GeminiService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  late RiverDocument _currentDocument;
  bool _hasChanges = false;
  bool _showAIOptions = false;
  bool _isPreviewMode = false;
  String _slashCommand = '';
  late AnimationController _animationController;
  late AnimationController _previewAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _previewAnimation;

  final List<AISuggestion> _aiSuggestions = [
    AISuggestion(
      title: 'Mejorar texto',
      description: 'River mejorará la gramática y estilo',
      command: 'mejorar',
      icon: Icons.auto_awesome,
    ),
    AISuggestion(
      title: 'Expandir idea',
      description: 'River expandirá el contenido actual',
      command: 'expandir',
      icon: Icons.open_in_full,
    ),
    AISuggestion(
      title: 'Buscar información',
      description: 'River buscará información relacionada',
      command: 'buscar',
      icon: Icons.search,
    ),
    AISuggestion(
      title: 'Agregar citas',
      description: 'River agregará referencias y citas',
      command: 'citas',
      icon: Icons.format_quote,
    ),
    AISuggestion(
      title: 'Crear estructura',
      description: 'River organizará el contenido',
      command: 'estructura',
      icon: Icons.view_list,
    ),
    AISuggestion(
      title: 'Resumir',
      description: 'River creará un resumen',
      command: 'resumir',
      icon: Icons.summarize,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentDocument = widget.document;
    _titleController.text = _currentDocument.title;
    _contentController.text = _currentDocument.content;
    
    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onContentChanged);
    
    // Configurar animaciones
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _previewAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _previewAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _previewAnimationController,
      curve: Curves.easeInOut,
    ));
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
    
    // Detectar comando /
    final text = _contentController.text;
    final cursorPosition = _contentController.selection.baseOffset;
    
    if (text.isNotEmpty && cursorPosition > 0) {
      final beforeCursor = text.substring(0, cursorPosition);
      final lastSlashIndex = beforeCursor.lastIndexOf('/');
      
      if (lastSlashIndex != -1 && lastSlashIndex == beforeCursor.length - 1) {
        // Mostrar opciones de IA
        setState(() {
          _showAIOptions = true;
          _slashCommand = '';
        });
        _animationController.forward();
      } else if (lastSlashIndex != -1 && beforeCursor.length > lastSlashIndex + 1) {
        // Filtrar opciones basado en el comando
        final command = beforeCursor.substring(lastSlashIndex + 1).toLowerCase();
        setState(() {
          _slashCommand = command;
          _showAIOptions = true;
        });
      } else {
        // Ocultar opciones
        if (_showAIOptions) {
          _animationController.reverse().then((_) {
            setState(() {
              _showAIOptions = false;
              _slashCommand = '';
            });
          });
        }
      }
    } else {
      if (_showAIOptions) {
        _animationController.reverse().then((_) {
          setState(() {
            _showAIOptions = false;
            _slashCommand = '';
          });
        });
      }
    }
  }

  void _togglePreview() {
    setState(() {
      _isPreviewMode = !_isPreviewMode;
    });
    
    if (_isPreviewMode) {
      _previewAnimationController.forward();
    } else {
      _previewAnimationController.reverse();
    }
  }

  Future<void> _applyAISuggestion(AISuggestion suggestion) async {
    // Ocultar opciones
    _animationController.reverse().then((_) {
      setState(() {
        _showAIOptions = false;
        _slashCommand = '';
      });
    });

    // Remover el comando / del texto
    final text = _contentController.text;
    final cursorPosition = _contentController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPosition);
    final lastSlashIndex = beforeCursor.lastIndexOf('/');
    
    if (lastSlashIndex != -1) {
      final newText = text.substring(0, lastSlashIndex) + text.substring(cursorPosition);
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(offset: lastSlashIndex);
    }

    // Configurar contexto del documento
    _geminiService.setDocumentContext(_currentDocument.title, _currentDocument.content);

    // Aplicar la sugerencia de IA
    try {
      String prompt = '';
      switch (suggestion.command) {
        case 'mejorar':
          prompt = 'Mejora la gramática, estilo y claridad del siguiente texto usando **markdown** para formato:';
          break;
        case 'expandir':
          prompt = 'Expande y desarrolla más el siguiente contenido usando **markdown** para estructura:';
          break;
        case 'buscar':
          prompt = 'Busca información relevante y actualizada sobre el siguiente tema y preséntala con **markdown**:';
          break;
        case 'citas':
          prompt = 'Agrega citas, referencias y fuentes para el siguiente contenido usando **markdown**:';
          break;
        case 'estructura':
          prompt = 'Reorganiza y estructura mejor el siguiente contenido usando **markdown** (# títulos, ## subtítulos, etc.):';
          break;
        case 'resumir':
          prompt = 'Crea un resumen conciso del siguiente contenido usando **markdown**:';
          break;
      }

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('River está ${suggestion.title.toLowerCase()}...'),
              ],
            ),
            backgroundColor: Colors.black,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      final response = await _geminiService.sendMessage(prompt);
      
      // Insertar la respuesta en el documento
      final currentText = _contentController.text;
      final cursorPos = _contentController.selection.baseOffset;
      final newText = currentText.substring(0, cursorPos) + 
                     '\n\n$response\n\n' + 
                     currentText.substring(cursorPos);
      
      _contentController.text = newText;
      _contentController.selection = TextSelection.collapsed(
        offset: cursorPos + response.length + 4,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${suggestion.title} completado'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
            fontFamily: 'Poppins',
          ),
        ),
        actions: [
          // Botón de preview
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.edit : Icons.preview,
              color: Colors.black,
            ),
            onPressed: _togglePreview,
            tooltip: _isPreviewMode ? 'Editar' : 'Vista previa',
          ),
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.black),
              onPressed: _saveDocument,
              tooltip: 'Guardar cambios',
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
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
                    fontFamily: 'Poppins',
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Título del documento',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),

              // Contenido del documento
              Expanded(
                child: _isPreviewMode ? _buildPreview() : _buildEditor(),
              ),
            ],
          ),

          // Opciones de IA
          if (_showAIOptions)
            Positioned(
              top: 100,
              left: 24,
              right: 24,
              child: AnimatedMenu(
                isOpen: _showAIOptions,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'River AI - Comandos disponibles',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...(_slashCommand.isEmpty 
                          ? _aiSuggestions 
                          : _aiSuggestions.where((suggestion) => 
                              suggestion.title.toLowerCase().contains(_slashCommand) ||
                              suggestion.description.toLowerCase().contains(_slashCommand)
                            )).map((suggestion) => _buildSuggestionTile(suggestion)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() {
    return Container(
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
          fontFamily: 'Poppins',
        ),
        decoration: const InputDecoration(
          hintText: 'Escribe aquí...\n\nFormato Markdown soportado:\n**negrita** *cursiva*\n# Título\n## Subtítulo\n- Lista\n1. Lista numerada\n\nPrueba escribir "/" para ver opciones de IA',
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Color(0xFF999999),
            fontSize: 16,
            height: 1.6,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return FadeTransition(
      opacity: _previewAnimation,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Markdown(
          data: _contentController.text.isEmpty 
              ? '*No hay contenido para mostrar*' 
              : _contentController.text,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            h2: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            h3: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            p: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            strong: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            em: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
            listBullet: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
            blockquote: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontFamily: 'Poppins',
            ),
            code: TextStyle(
              backgroundColor: Colors.grey[100],
              color: Colors.black,
              fontFamily: 'Poppins',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionTile(AISuggestion suggestion) {
    return InkWell(
      onTap: () => _applyAISuggestion(suggestion),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF5F5F5), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                suggestion.icon,
                color: Colors.black,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showSaveDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Documento modificado', style: TextStyle(fontFamily: 'Poppins')),
        content: const Text('¿Quieres guardar los cambios?', style: TextStyle(fontFamily: 'Poppins')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No guardar', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _animationController.dispose();
    _previewAnimationController.dispose();
    super.dispose();
  }
}
