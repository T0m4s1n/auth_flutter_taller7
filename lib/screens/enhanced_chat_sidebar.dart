import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/gemini_service.dart';
import '../widgets/thinking_animation.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? type; // 'text', 'typing', 'error'

  ChatMessage({
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.type = 'text',
  }) : timestamp = timestamp ?? DateTime.now();
}

class EnhancedChatSidebar extends StatefulWidget {
  const EnhancedChatSidebar({super.key});

  @override
  State<EnhancedChatSidebar> createState() => _EnhancedChatSidebarState();
}

class _EnhancedChatSidebarState extends State<EnhancedChatSidebar>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final GeminiService _geminiService = GeminiService();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late AnimationController _typingAnimationController;
  late AnimationController _slideInController;
  late Animation<double> _slideInAnimation;

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    
    // Configurar animaciones
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _slideInController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    ));
    
    _slideInController.forward();
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(ChatMessage(
        content: '''¡Hola! Soy **River**, tu asistente IA. ¿En qué puedo ayudarte con tu documento?

💡 **Prueba preguntarme sobre:**
• **Mejorar** tu texto
• **Buscar** información
• **Agregar** citas
• **Crear** estructura

También puedes usar el comando **/** en el editor para opciones rápidas!''',
        isUser: false,
      ));
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      _messages.add(ChatMessage(
        content: userMessage,
        isUser: true,
      ));
      _isLoading = true;
    });

    _scrollToBottom();

    // Agregar mensaje de "River está escribiendo..."
    final typingMessage = ChatMessage(
      content: '',
      isUser: false,
      type: 'typing',
    );
    
    setState(() {
      _messages.add(typingMessage);
    });

    _scrollToBottom();

    try {
      final response = await _geminiService.sendMessage(userMessage);
      
      // Remover mensaje de typing y agregar respuesta
      setState(() {
        _messages.removeLast(); // Remover typing
        _messages.add(ChatMessage(
          content: response,
          isUser: false,
        ));
        _isLoading = false;
      });
      
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remover typing
        _messages.add(ChatMessage(
          content: 'Lo siento, hubo un error: $e',
          isUser: false,
          type: 'error',
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _geminiService.clearChatHistory();
    });
    _addWelcomeMessage();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideInController,
        curve: Curves.easeOutCubic,
      )),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header del chat con animación
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'River',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        Text(
                          'Asistente IA',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: _clearChat,
                    tooltip: 'Limpiar chat',
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),

            // Lista de mensajes
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildMessageBubble(_messages[index], index);
                },
              ),
            ),

            // Campo de entrada de mensaje
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE5E5E5), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Pregunta sobre tu documento...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          hintStyle: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: const TextStyle(fontFamily: 'Poppins'),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendMessage(),
                        enabled: !_isLoading,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isLoading ? Icons.hourglass_empty : Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _isLoading ? null : _sendMessage,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    if (message.type == 'typing') {
      return _buildTypingIndicator();
    }

    return AnimatedContainer(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Column(
            crossAxisAlignment: message.isUser 
                ? CrossAxisAlignment.end 
                : CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: message.type == 'error'
                      ? Colors.red.withOpacity(0.1)
                      : message.isUser
                          ? Colors.black
                          : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: message.type == 'error'
                      ? Border.all(color: Colors.red.withOpacity(0.3))
                      : null,
                ),
                child: message.isUser 
                    ? _buildUserMessage(message.content)
                    : _buildAIMessage(message.content, message.type == 'error'),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserMessage(String content) {
    return Text(
      content,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.4,
        fontFamily: 'Poppins',
      ),
    );
  }

  Widget _buildAIMessage(String content, bool isError) {
    return MarkdownBody(
      data: content,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontSize: 14,
          height: 1.4,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        strong: TextStyle(
          fontWeight: FontWeight.bold,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        em: TextStyle(
          fontStyle: FontStyle.italic,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        h1: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        h2: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        h3: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        listBullet: TextStyle(
          color: isError ? Colors.red[700] : Colors.black,
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        blockquote: TextStyle(
          color: isError ? Colors.red[600] : Colors.grey[600],
          fontSize: 14,
          fontFamily: 'Poppins',
        ),
        code: TextStyle(
          backgroundColor: isError ? Colors.red.withOpacity(0.1) : Colors.grey[100],
          color: isError ? Colors.red[700] : Colors.black,
          fontFamily: 'Poppins',
        ),
        codeblockDecoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'River está escribiendo',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 20,
              height: 20,
              child: AnimatedBuilder(
                animation: _typingAnimationController,
                builder: (context, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final animationValue = (_typingAnimationController.value - index * 0.3) % 1.0;
                      final opacity = (1.0 - (animationValue * 2 - 1).abs()).clamp(0.0, 1.0);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400]?.withOpacity(opacity),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    _slideInController.dispose();
    super.dispose();
  }
}
