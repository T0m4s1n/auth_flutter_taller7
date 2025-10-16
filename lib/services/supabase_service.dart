import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient? _client;
  
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception('Supabase no está inicializado. Llama a SupabaseService.initialize() primero.');
    }
    return _client!;
  }
  
  static Future<void> initialize() async {
    try {
      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
      
      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception('SUPABASE_URL o SUPABASE_ANON_KEY no están configurados en .env');
      }
      
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      
      _client = Supabase.instance.client;
      print('✅ Supabase inicializado correctamente');
    } catch (e) {
      print('❌ Error inicializando Supabase: $e');
      rethrow;
    }
  }
  
  // Métodos para operaciones de documentos
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await client
          .from('documents')
          .select()
          .order('updated_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo documentos: $e');
      return [];
    }
  }
  
  static Future<Map<String, dynamic>?> getDocument(String id) async {
    try {
      final response = await client
          .from('documents')
          .select()
          .eq('id', id)
          .single();
      return response;
    } catch (e) {
      print('Error obteniendo documento $id: $e');
      return null;
    }
  }
  
  static Future<String?> createDocument({
    required String title,
    String content = '',
  }) async {
    try {
      final response = await client
          .from('documents')
          .insert({
            'title': title,
            'content': content,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      return response['id'];
    } catch (e) {
      print('Error creando documento: $e');
      return null;
    }
  }
  
  static Future<bool> updateDocument({
    required String id,
    String? title,
    String? content,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      
      await client
          .from('documents')
          .update(updates)
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error actualizando documento $id: $e');
      return false;
    }
  }
  
  static Future<bool> deleteDocument(String id) async {
    try {
      await client
          .from('documents')
          .delete()
          .eq('id', id);
      
      return true;
    } catch (e) {
      print('Error eliminando documento $id: $e');
      return false;
    }
  }
  
  // Métodos para operaciones de mensajes de chat
  static Future<List<Map<String, dynamic>>> getMessages(String documentId) async {
    try {
      final response = await client
          .from('messages')
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo mensajes para documento $documentId: $e');
      return [];
    }
  }
  
  static Future<String?> createMessage({
    required String documentId,
    required String content,
    required String role, // 'user' o 'assistant'
  }) async {
    try {
      final response = await client
          .from('messages')
          .insert({
            'document_id': documentId,
            'content': content,
            'role': role,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();
      
      return response['id'];
    } catch (e) {
      print('Error creando mensaje: $e');
      return null;
    }
  }
  
  static Future<bool> deleteMessages(String documentId) async {
    try {
      await client
          .from('messages')
          .delete()
          .eq('document_id', documentId);
      
      return true;
    } catch (e) {
      print('Error eliminando mensajes para documento $documentId: $e');
      return false;
    }
  }
  
  // =====================================================
  // STORAGE METHODS FOR IMAGES
  // =====================================================
  
  /// Upload image to storage bucket
  static Future<String?> uploadImage({
    required String documentId,
    required String userId,
    required String fileName,
    required List<int> imageBytes,
    String? mimeType,
  }) async {
    try {
      final filePath = '$userId/$documentId/$fileName';
      final uint8List = Uint8List.fromList(imageBytes);
      
      await client.storage
          .from('document-images')
          .uploadBinary(filePath, uint8List);
      
      // Get public URL
      final publicUrl = client.storage
          .from('document-images')
          .getPublicUrl(filePath);
      
      // Save image metadata to database
      await createDocumentImage(
        documentId: documentId,
        userId: userId,
        imageUrl: publicUrl,
        fileName: fileName,
        fileSize: imageBytes.length,
        mimeType: mimeType,
      );
      
      return publicUrl;
    } catch (e) {
      print('Error subiendo imagen: $e');
      return null;
    }
  }
  
  /// Create document image record
  static Future<bool> createDocumentImage({
    required String documentId,
    required String userId,
    required String imageUrl,
    required String fileName,
    int? fileSize,
    String? mimeType,
  }) async {
    try {
      await client
          .from('document_images')
          .insert({
            'document_id': documentId,
            'user_id': userId,
            'image_url': imageUrl,
            'file_name': fileName,
            'file_size': fileSize,
            'mime_type': mimeType,
          });
      
      return true;
    } catch (e) {
      print('Error creando registro de imagen: $e');
      return false;
    }
  }
  
  /// Get images for a document
  static Future<List<Map<String, dynamic>>> getDocumentImages(String documentId) async {
    try {
      final response = await client
          .from('document_images')
          .select()
          .eq('document_id', documentId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error obteniendo imágenes del documento $documentId: $e');
      return [];
    }
  }
  
  /// Delete image from storage and database
  static Future<bool> deleteImage(String imageId, String filePath) async {
    try {
      // Delete from storage
      await client.storage
          .from('document-images')
          .remove([filePath]);
      
      // Delete from database
      await client
          .from('document_images')
          .delete()
          .eq('id', imageId);
      
      return true;
    } catch (e) {
      print('Error eliminando imagen: $e');
      return false;
    }
  }
  
  /// Delete all images for a document
  static Future<bool> deleteAllDocumentImages(String documentId) async {
    try {
      // Get all images for the document
      final images = await getDocumentImages(documentId);
      
      // Delete from storage
      final filePaths = images.map((img) {
        final url = img['image_url'] as String;
        return url.split('/').last; // Extract filename from URL
      }).toList();
      
      if (filePaths.isNotEmpty) {
        await client.storage
            .from('document-images')
            .remove(filePaths);
      }
      
      // Delete from database
      await client
          .from('document_images')
          .delete()
          .eq('document_id', documentId);
      
      return true;
    } catch (e) {
      print('Error eliminando imágenes del documento $documentId: $e');
      return false;
    }
  }
  
  // =====================================================
  // USER PROFILE METHODS
  // =====================================================
  
  /// Get user profile
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      return response;
    } catch (e) {
      print('Error obteniendo perfil de usuario $userId: $e');
      return null;
    }
  }
  
  /// Update user profile
  static Future<bool> updateUserProfile({
    required String userId,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      
      await client
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      
      return true;
    } catch (e) {
      print('Error actualizando perfil de usuario $userId: $e');
      return false;
    }
  }
  
  // =====================================================
  // UTILITY METHODS
  // =====================================================
  
  /// Get current user ID
  static String? get currentUserId => client.auth.currentUser?.id;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUserId != null;
  
  /// Get public URL for storage file
  static String getStoragePublicUrl(String filePath) {
    return client.storage
        .from('document-images')
        .getPublicUrl(filePath);
  }
}
