import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final GenerativeModel _model;
  final List<Content> _chatHistory = [];
  String _currentDocumentContext = '';
  String _currentDocumentTitle = '';

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? 'AIzaSyBK12U2OhKEDWRfqZmZrFN0O079ydphikU';
    
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1000, // Límite para plan gratuito
        topP: 0.8,
        topK: 40,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );
  }

  // Establecer contexto del documento actual
  void setDocumentContext(String title, String content) {
    _currentDocumentTitle = title;
    _currentDocumentContext = content;
  }

  // Limpiar contexto del documento
  void clearDocumentContext() {
    _currentDocumentTitle = '';
    _currentDocumentContext = '';
  }

  Future<String> sendMessage(String userMessage) async {
    try {
      // Crear prompt contextualizado
      final contextualPrompt = _buildContextualPrompt(userMessage);
      
      print('Enviando mensaje a River...');
      print('Mensaje: $userMessage');
      print('Contexto: $_currentDocumentTitle');

      // Generar respuesta
      final response = await _model.generateContent([Content.text(contextualPrompt)]);
      
      final responseText = response.text ?? 'No se recibió respuesta de River';
      
      print('Respuesta de River: $responseText');
      
      return responseText;
    } catch (e) {
      print('Error en sendMessage: $e');
      
      // Manejo específico de errores
      if (e.toString().contains('not found') || e.toString().contains('not supported')) {
        throw Exception('❌ Modelo no disponible. Verifica que tu API key tenga acceso a Gemini Pro.');
      } else if (e.toString().contains('API_KEY_INVALID') || e.toString().contains('Invalid API key')) {
        throw Exception('❌ API Key inválida. Verifica tu clave de API de Google Gemini.');
      } else if (e.toString().contains('quota') || e.toString().contains('limit')) {
        throw Exception('❌ Cuota excedida. Has alcanzado el límite del plan gratuito.');
      } else if (e.toString().contains('safety')) {
        throw Exception('❌ Contenido bloqueado por políticas de seguridad.');
      } else {
        throw Exception('❌ Error al comunicarse con River: $e');
      }
    }
  }

  // Construir prompt contextualizado
  String _buildContextualPrompt(String userMessage) {
    final buffer = StringBuffer();
    
    // Prompt base del sistema
    buffer.writeln('Eres River, un asistente IA especializado en ayudar con la escritura y edición de documentos.');
    buffer.writeln('Tu función es ayudar al usuario a mejorar, expandir, investigar y enriquecer el contenido de sus documentos.');
    buffer.writeln();
    
    // Contexto del documento actual
    if (_currentDocumentTitle.isNotEmpty) {
      buffer.writeln('DOCUMENTO ACTUAL:');
      buffer.writeln('Título: $_currentDocumentTitle');
      if (_currentDocumentContext.isNotEmpty) {
        buffer.writeln('Contenido:');
        buffer.writeln(_currentDocumentContext);
      }
      buffer.writeln();
    }
    
    // Instrucciones específicas
    buffer.writeln('INSTRUCCIONES:');
    buffer.writeln('- Puedes buscar información en Google y proporcionar fuentes');
    buffer.writeln('- Puedes sugerir mejoras al texto');
    buffer.writeln('- Puedes agregar citas y referencias');
    buffer.writeln('- Puedes crear listas, títulos y estructura');
    buffer.writeln('- Puedes explicar conceptos complejos');
    buffer.writeln('- Siempre proporciona contenido útil y bien estructurado');
    buffer.writeln('- Si necesitas buscar información específica, menciona que harías una búsqueda en Google');
    buffer.writeln('- Responde en español y de manera conversacional');
    buffer.writeln();
    
    // Mensaje del usuario
    buffer.writeln('MENSAJE DEL USUARIO:');
    buffer.writeln(userMessage);
    
    return buffer.toString();
  }

  // Limpiar historial de chat
  void clearChatHistory() {
    _chatHistory.clear();
    print('Historial de chat limpiado');
  }

  // Obtener número de mensajes en el historial
  int get messageCount => _chatHistory.length;

  // Método para verificar conexión
  Future<bool> testConnection() async {
    try {
      final response = await sendMessage('Hola, responde solo con "Hola" para confirmar la conexión.');
      return response.isNotEmpty && response.toLowerCase().contains('hola');
    } catch (e) {
      print('Error en testConnection: $e');
      return false;
    }
  }

  // Método para obtener información del modelo
  String getModelInfo() {
    return 'Modelo: Gemini 2.0 Flash (Gratuito)\nMáximo de tokens: 1000\nTemperatura: 0.7';
  }
}