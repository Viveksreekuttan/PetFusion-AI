import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // 🔐 Load API key from .env
  static final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  // Gemini 2.5 Flash model
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash";

  // --- 1. CHAT STREAM (For AI Assistant - Generative Motion) ---
  // Returns a Stream<String> that yields text chunks as they are generated
  static Stream<String> getChatStream({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String message,
  }) async* {
    try {
      List<Map<String, dynamic>> contents = [];
      
      // Setup Context
      contents.add({"role": "user", "parts": [{"text": "SYSTEM INSTRUCTION: $systemPrompt"}]});
      contents.add({"role": "model", "parts": [{"text": "Understood."}]});
      
      // Add History
      for (var msg in history) {
        contents.add({
          "role": msg['sender'] == 'user' ? "user" : "model",
          "parts": [{"text": msg['text']}]
        });
      }
      // Add Current Message
      contents.add({"role": "user", "parts": [{"text": message}]});

      final body = jsonEncode({
        "contents": contents,
        "generationConfig": {"temperature": 0.5, "maxOutputTokens": 2000}
      });

      // Request with alt=sse for streaming
      final url = Uri.parse("$_baseUrl:streamGenerateContent?key=$_apiKey&alt=sse");
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = body;

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        yield "Error: ${response.statusCode}";
        return;
      }

      // Parse Server-Sent Events (SSE)
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr == '[DONE]') break;

          try {
            final json = jsonDecode(jsonStr);
            if (json['candidates'] != null && json['candidates'].isNotEmpty) {
              final parts = json['candidates'][0]['content']['parts'];
              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'];
                if (text != null) yield text; // Yield chunk
              }
            }
          } catch (e) {
            // Ignore parsing errors for intermediate chunks
          }
        }
      }
      client.close();
    } catch (e) {
      yield "Connection error: $e";
    }
  }

  // --- 2. SINGLE RESPONSE (For Symptom Page) ---
  // Returns a Future<String> (waits for full response)
  static Future<String> getChatResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String message, 
  }) async {
    try {
      List<Map<String, dynamic>> contents = [];
      contents.add({"role": "user", "parts": [{"text": "SYSTEM INSTRUCTION: $systemPrompt"}]});
      contents.add({"role": "model", "parts": [{"text": "Understood."}]});

      for (var msg in history) {
        contents.add({
          "role": msg['sender'] == 'user' ? "user" : "model",
          "parts": [{"text": msg['text']}]
        });
      }
      contents.add({"role": "user", "parts": [{"text": message}]});

      final body = jsonEncode({
        "contents": contents,
        "generationConfig": {"temperature": 0.5, "maxOutputTokens": 2000}
      });

      final response = await http.post(
        Uri.parse("$_baseUrl:generateContent?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['candidates'] != null && decoded['candidates'].isNotEmpty) {
           return decoded['candidates'][0]['content']['parts'][0]['text'];
        }
        return "No response.";
      }
      return "Error: ${response.statusCode}";
    } catch (e) {
      return "Connection error: $e";
    }
  }

  // --- 3. IMAGE ANALYSIS (For X-Ray Page) ---
  static Future<String> analyzeImage({
    required File imageFile,
    required String prompt,
  }) async {
    try {
      print("🔍 [Gemini] Starting image analysis...");
      print("📸 [Gemini] Image path: ${imageFile.path}");
      
      // Read image bytes
      List<int> imageBytes = await imageFile.readAsBytes();
      print("✅ [Gemini] Image bytes read: ${imageBytes.length} bytes");
      
      // Encode to base64
      String base64Image = base64Encode(imageBytes);
      print("✅ [Gemini] Base64 encoded: ${base64Image.length} chars");

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {"inline_data": {"mime_type": "image/jpeg", "data": base64Image}}
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.4, 
          "maxOutputTokens": 1500
        }
      });

      print("🌐 [Gemini] Sending request to API...");
      
      final response = await http.post(
        Uri.parse("$_baseUrl:generateContent?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Gemini API request timed out after 60 seconds');
        },
      );

      print("📡 [Gemini] Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print("✅ [Gemini] Response decoded successfully");
        
        if (decoded['candidates'] != null && decoded['candidates'].isNotEmpty) {
          final text = decoded['candidates'][0]['content']['parts'][0]['text'];
          print("✅ [Gemini] Text extracted: ${text.length} chars");
          return text;
        }
        
        print("⚠️ [Gemini] No candidates in response: ${response.body}");
        return "AI could not interpret image. No candidates returned.";
      }
      
      print("❌ [Gemini] Error ${response.statusCode}: ${response.body}");
      return "Error ${response.statusCode}: ${response.body}";
      
    } on TimeoutException catch (e) {
      print("⏱️ [Gemini] Timeout: $e");
      throw Exception("Gemini API timeout: $e");
    } on SocketException catch (e) {
      print("🌐 [Gemini] Network error: $e");
      throw Exception("Network error. Check your internet connection: $e");
    } catch (e, stackTrace) {
      print("❌ [Gemini] Exception: $e");
      print("📋 [Gemini] Stack trace: $stackTrace");
      throw Exception("Gemini API error: $e");
    }
  }

  // --- 4. AUDIO ANALYSIS (For Audio Page) ---
  // ⭐️ NEW: Audio analysis using Gemini's audio capabilities
  static Future<String> analyzeAudio({
    required File audioFile,
    required String prompt,
    required String petName,
  }) async {
    try {
      print("🔍 [Gemini] Starting audio analysis...");
      print("🎵 [Gemini] Audio path: ${audioFile.path}");
      
      // Read audio bytes
      List<int> audioBytes = await audioFile.readAsBytes();
      print("✅ [Gemini] Audio bytes read: ${audioBytes.length} bytes");
      
      // Encode to base64
      String base64Audio = base64Encode(audioBytes);
      print("✅ [Gemini] Base64 encoded: ${base64Audio.length} chars");

      // Determine MIME type based on file extension
      String mimeType = 'audio/mp4'; // Default for .m4a
      final extension = audioFile.path.split('.').last.toLowerCase();
      if (extension == 'mp3') {
        mimeType = 'audio/mp3';
      } else if (extension == 'wav') {
        mimeType = 'audio/wav';
      } else if (extension == 'ogg') {
        mimeType = 'audio/ogg';
      }

      print("🎵 [Gemini] MIME type: $mimeType");

      final body = jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
              {
                "inline_data": {
                  "mime_type": mimeType,
                  "data": base64Audio
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.3,
          "maxOutputTokens": 2000
        }
      });

      print("🌐 [Gemini] Sending audio request to API...");
      
      final response = await http.post(
        Uri.parse("$_baseUrl:generateContent?key=$_apiKey"),
        headers: {"Content-Type": "application/json"},
        body: body,
      ).timeout(
        const Duration(seconds: 90), // Longer timeout for audio
        onTimeout: () {
          throw TimeoutException('Gemini API request timed out after 90 seconds');
        },
      );

      print("📡 [Gemini] Response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print("✅ [Gemini] Response decoded successfully");
        
        if (decoded['candidates'] != null && decoded['candidates'].isNotEmpty) {
          final text = decoded['candidates'][0]['content']['parts'][0]['text'];
          print("✅ [Gemini] Text extracted: ${text.length} chars");
          return text;
        }
        
        print("⚠️ [Gemini] No candidates in response: ${response.body}");
        return "AI could not analyze the audio. Please try with a different recording.";
      }
      
      print("❌ [Gemini] Error ${response.statusCode}: ${response.body}");
      
      // Parse error message if available
      try {
        final errorDecoded = jsonDecode(response.body);
        if (errorDecoded['error'] != null && errorDecoded['error']['message'] != null) {
          return "Error: ${errorDecoded['error']['message']}";
        }
      } catch (e) {
        // Continue to generic error
      }
      
      return "Error ${response.statusCode}: Unable to analyze audio. Please ensure the audio file is valid.";
      
    } on TimeoutException catch (e) {
      print("⏱️ [Gemini] Timeout: $e");
      throw Exception("Analysis timeout. Please try with a shorter audio clip.");
    } on SocketException catch (e) {
      print("🌐 [Gemini] Network error: $e");
      throw Exception("Network error. Please check your internet connection.");
    } catch (e, stackTrace) {
      print("❌ [Gemini] Exception: $e");
      print("📋 [Gemini] Stack trace: $stackTrace");
      throw Exception("Audio analysis error: $e");
    }
  }
}