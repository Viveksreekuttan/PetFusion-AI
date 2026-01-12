import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ⭐️ Renders **bold** text
import '../services/gemini_service.dart';
import '../services/ai_prompts.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechEnabled = false;
  
  // ⭐️ Streaming & State Variables
  bool _isGenerating = false;
  String _streamedResponse = ""; 
  String? _currentChatId; // Readable ID for the document

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onError: (val) => print('Speech Error: $val'),
        onStatus: (val) {
          if (mounted && (val == 'done' || val == 'notListening')) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (e) { print("Init error: $e"); }
  }

  void _listen() async {
    if (!_speechEnabled) return;
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => _controller.text = val.recognizedWords));
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  // --- DRAWER ACTIONS ---
  void _startNewChat() {
    setState(() {
      _currentChatId = null;
      _controller.clear();
      _isGenerating = false;
      _streamedResponse = "";
    });
    if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
  }

  void _loadChat(String chatId) {
    setState(() {
      _currentChatId = chatId;
      _controller.clear();
      _isGenerating = false;
      _streamedResponse = "";
    });
    Navigator.pop(context);
  }

  // --- ID GENERATOR ---
  String _generateReadableId(String text) {
    String safeText = text.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim().replaceAll(' ', '_');
    if (safeText.length > 20) safeText = safeText.substring(0, 20);
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6); 
    return "${safeText}_$timestamp";
  }

  // --- ⭐️ SEND MESSAGE LOGIC ---
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    // ⭐️ FIX: Use UID instead of Email to prevent permission errors
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _controller.clear();
    setState(() {
      _isGenerating = true;
      _streamedResponse = "";
    });

    try {
      DocumentReference chatRef;

      // 1. Create or Get Chat Document
      if (_currentChatId == null) {
        String readableId = _generateReadableId(text);
        
        // Path: users/{uid}/aichats/{readableId}
        chatRef = _firestore.collection('users').doc(uid).collection('aichats').doc(readableId);
        
        await chatRef.set({
          'title': text,
          'createdAt': FieldValue.serverTimestamp(),
          'messages': [
            {'sender': 'user', 'text': text, 'timestamp': DateTime.now().toString()}
          ]
        });
        
        setState(() => _currentChatId = readableId);
      } else {
        chatRef = _firestore.collection('users').doc(uid).collection('aichats').doc(_currentChatId);
        
        await chatRef.update({
          'messages': FieldValue.arrayUnion([
            {'sender': 'user', 'text': text, 'timestamp': DateTime.now().toString()}
          ])
        });
      }

      // 2. Stream Gemini Response
      final stream = GeminiService.getChatStream(
        systemPrompt: AiPrompts.veterinaryAssistant,
        history: [], 
        message: text,
      );

      String fullResponse = "";
      await for (final chunk in stream) {
        if (!mounted) return;
        fullResponse += chunk;
        setState(() {
          _streamedResponse += chunk;
        });
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.minScrollExtent);
        }
      }

      // 3. Save Final Response to Database
      await chatRef.update({
        'messages': FieldValue.arrayUnion([
          {'sender': 'bot', 'text': fullResponse, 'timestamp': DateTime.now().toString()}
        ])
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _streamedResponse = "";
        });
      }
    }
  }

  // --- DRAWER UI ---
  Widget _buildDrawer(bool isDark) {
    final uid = _auth.currentUser?.uid;
    
    return Drawer(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, bottom: 20),
            width: double.infinity,
            color: Theme.of(context).primaryColor,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text("Chat History", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                 SizedBox(height: 5),
                 Text("Your previous consultations", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Colors.green, radius: 16, child: Icon(Icons.add, color: Colors.white, size: 20)),
            title: const Text("Start New Chat", style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: () { Navigator.pop(context); _startNewChat(); },
          ),
          const Divider(),
          Expanded(
            child: uid == null ? const SizedBox() : StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').doc(uid).collection('aichats').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final chats = snapshot.data!.docs;
                if (chats.isEmpty) return Center(child: Text("No history yet", style: TextStyle(color: Colors.grey[600])));
                
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final data = chats[index].data() as Map<String, dynamic>;
                    final chatId = chats[index].id;
                    final isSelected = chatId == _currentChatId;
                    
                    return Container(
                      color: isSelected ? Colors.grey.withOpacity(0.1) : null,
                      child: ListTile(
                        leading: Icon(Icons.chat_bubble_outline, color: isSelected ? Theme.of(context).primaryColor : Colors.grey),
                        title: Text(data['title'] ?? chatId, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(chatId, style: TextStyle(fontSize: 10, color: Colors.grey[400])), 
                        onTap: () => _loadChat(chatId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      drawer: _buildDrawer(isDark),
      appBar: AppBar(
        title: const Text('AI Assistant'),
        elevation: 1,
        actions: [
          IconButton(icon: const Icon(Icons.edit_square), tooltip: "New Chat", onPressed: _startNewChat),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // --- CHAT AREA ---
          Expanded(
            child: _currentChatId == null
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.auto_awesome, size: 64, color: primaryColor.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("Start a new consultation", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                ]))
              : StreamBuilder<DocumentSnapshot>(
                  stream: _firestore.collection('users').doc(uid).collection('aichats').doc(_currentChatId).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Center(child: Text("Error loading chat"));
                    
                    List<dynamic> messages = [];
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      messages = data['messages'] ?? [];
                    }

                    final reversedMessages = messages.reversed.toList();

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Stick to bottom
                      padding: const EdgeInsets.all(16),
                      itemCount: reversedMessages.length + (_isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        
                        // Streaming Bubble
                        if (_isGenerating && index == 0) {
                          return _buildStreamingBubble(_streamedResponse, isDark);
                        }
                        
                        final docIndex = _isGenerating ? index - 1 : index;
                        final msgData = reversedMessages[docIndex] as Map<String, dynamic>;
                        
                        return _buildMessageBubble(
                          text: msgData['text'] ?? '',
                          isUser: msgData['sender'] == 'user',
                          color: primaryColor,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
          ),
          
          // --- INPUT AREA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Row(children: [
              IconButton(icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.redAccent : Colors.grey), onPressed: _listen),
              const SizedBox(width: 8),
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                child: TextField(
                  controller: _controller, textCapitalization: TextCapitalization.sentences, enabled: !_isGenerating,
                  decoration: InputDecoration(hintText: _isListening ? 'Listening...' : 'Type message...', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                  onSubmitted: (_) => _sendMessage(),
                ),
              )),
              const SizedBox(width: 12),
              GestureDetector(onTap: _isGenerating ? null : _sendMessage, child: CircleAvatar(radius: 24, backgroundColor: _isGenerating ? Colors.grey : primaryColor, child: const Icon(Icons.send, color: Colors.white, size: 20))),
            ]),
          ),
        ],
      ),
    );
  }

  // --- MARKDOWN BUBBLES ---
  Widget _buildStreamingBubble(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        ),
        child: text.isEmpty 
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey[600])),
                const SizedBox(width: 8), Text("Thinking...", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic))
              ])
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }

  Widget _buildMessageBubble({required String text, required bool isUser, required Color color, required bool isDark}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: isUser ? color : (isDark ? Colors.grey[800] : Colors.grey[300]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero, bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: isUser 
            ? Text(text, style: const TextStyle(fontSize: 16, color: Colors.white))
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                  strong: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
      ),
    );
  }
}