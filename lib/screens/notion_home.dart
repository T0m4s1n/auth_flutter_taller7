import 'package:flutter/material.dart';
import '../models/document.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';
import 'markdown_document_editor.dart';
import 'enhanced_chat_sidebar.dart';
import '../widgets/animated_loading_card.dart';

class NotionHomeScreen extends StatefulWidget {
  const NotionHomeScreen({super.key});

  @override
  State<NotionHomeScreen> createState() => _NotionHomeScreenState();
}

class _NotionHomeScreenState extends State<NotionHomeScreen> 
    with TickerProviderStateMixin {
  final DocumentService _documentService = DocumentService();
  final TextEditingController _searchController = TextEditingController();
  List<RiverDocument> _documents = [];
  List<RiverDocument> _filteredDocuments = [];
  bool _isSearching = false;
  bool _isChatOpen = false;
  
  late AnimationController _chatAnimationController;
  late AnimationController _fabAnimationController;
  late Animation<double> _chatSlideAnimation;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    
    // Configurar animaciones
    _chatAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _chatSlideAnimation = Tween<double>(
      begin: 400.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _chatAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _fabAnimationController.forward();
  }

  void _loadDocuments() {
    setState(() {
      _documents = _documentService.getAllDocuments();
      _filteredDocuments = _documents;
    });
  }

  void _filterDocuments(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDocuments = _documents;
      } else {
        _filteredDocuments = _documentService.searchDocuments(query);
      }
    });
  }

  Future<void> _createNewDocument() async {
    try {
      final newDoc = await _documentService.createDocument();
      _loadDocuments();
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MarkdownDocumentEditorScreen(
              document: newDoc,
              onDocumentUpdated: _loadDocuments,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creando documento: $e')),
        );
      }
    }
  }

  void _openDocument(RiverDocument document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownDocumentEditorScreen(
          document: document,
          onDocumentUpdated: _loadDocuments,
        ),
      ),
    );
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
    
    if (_isChatOpen) {
      _chatAnimationController.forward();
    } else {
      _chatAnimationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Área principal de documentos
          Expanded(
            flex: _isChatOpen ? 2 : 3,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'River',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Barra de búsqueda con Expanded para evitar overflow
                        Expanded(
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFE5E5E5)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Buscar en documentos...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                hintStyle: TextStyle(
                                  color: Color(0xFF999999),
                                  fontSize: 14,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              onChanged: _filterDocuments,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Botón de logout temporal para testing
                        IconButton(
                          onPressed: () async {
                            await AuthService.signOut();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Sesión cerrada'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                          tooltip: 'Cerrar sesión',
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                  // Lista de documentos
                  Expanded(
                    child: _filteredDocuments.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.all(24),
                            itemCount: _filteredDocuments.length,
                            itemBuilder: (context, index) {
                              final document = _filteredDocuments[index];
                              return AnimatedLoadingCard(
                                delay: Duration(milliseconds: index * 100),
                                child: _buildDocumentCard(document),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),

          // Chat sidebar con animación
          if (_isChatOpen)
            AnimatedBuilder(
              animation: _chatSlideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_chatSlideAnimation.value, 0),
                  child: Container(
                    width: 400,
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                      ),
                    ),
                    child: const EnhancedChatSidebar(),
                  ),
                );
              },
            ),
        ],
      ),

      // Botón flotante para nuevo documento con animación
      floatingActionButton: AnimatedBuilder(
        animation: _fabScaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _fabScaleAnimation.value,
            child: FloatingActionButton(
              onPressed: _createNewDocument,
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        },
      ),

      // Botón flotante para chat
      bottomNavigationBar: Container(
        height: 60,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 24),
              child: IconButton(
                onPressed: _toggleChat,
                icon: Icon(
                  _isChatOpen ? Icons.close : Icons.chat,
                  color: Colors.black,
                ),
                tooltip: _isChatOpen ? 'Cerrar chat' : 'Abrir chat con River',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'No se encontraron documentos' : 'No hay documentos aún',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching ? 'Intenta con otros términos de búsqueda' : 'Crea tu primer documento',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(RiverDocument document) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E5E5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _openDocument(document),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      document.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(document.updatedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (document.content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getPreview(document.content),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (document.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: document.tags.map((tag) => _buildTag(tag)).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  String _getPreview(String content) {
    // Limpiar markdown básico para preview
    return content
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1')
        .trim();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Hoy';
    } else if (difference.inDays == 1) {
      return 'Ayer';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatAnimationController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
}
