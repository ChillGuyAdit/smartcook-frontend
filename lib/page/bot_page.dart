import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:smartcook/config/api_config.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/token_service.dart';

class BotPage extends StatefulWidget {
  const BotPage({super.key});

  @override
  State<BotPage> createState() => _BotPageState();
}

class _BotPageState extends State<BotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/chat/history');
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    if (res.success && res.data != null) {
      final data = res.data;
      List? msgList;
      if (data is Map && data['messages'] != null) {
        msgList = data['messages'] is List ? data['messages'] as List : null;
      } else if (data is List) {
        msgList = data;
      }
      if (msgList != null) {
        for (final e in msgList) {
          if (e is Map<String, dynamic>) list.add(e);
        }
      }
    }
    setState(() {
      _messages = list;
      _loading = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _messages.add({'role': 'model', 'content': ''});
      _sending = true;
    });

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/chat/message-stream');
    final token = await TokenService.getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'x-api-key': ApiConfig.apiKey,
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode({'message': text});

    try {
      final client = http.Client();
      final response = await client.send(request).timeout(
        const Duration(seconds: 120),
        onTimeout: () => throw Exception('Timeout'),
      );
      if (!mounted) return;

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        String errMsg = 'Gagal mengirim';
        try {
          final j = jsonDecode(body) as Map?;
          if (j?['message'] != null) errMsg = j!['message'].toString();
        } catch (_) {}
        setState(() {
          _messages.removeLast();
          _sending = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
        }
        return;
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (!mounted) break;
        buffer += chunk;
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();
        for (final part in parts) {
          final line = part.split('\n').where((l) => l.startsWith('data: ')).firstOrNull;
          if (line == null) continue;
          final dataStr = line.substring(6).trim();
          if (dataStr == '[DONE]' || dataStr.isEmpty) continue;
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>?;
            if (data == null) continue;
            if (data['done'] == true && data['fullReply'] != null) {
              setState(() {
                if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
                  _messages.last['content'] = data['fullReply'].toString();
                }
              });
              break;
            }
            final delta = data['text']?.toString();
            if (delta != null && delta.isNotEmpty) {
              setState(() {
                if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
                  _messages.last['content'] =
                      (_messages.last['content']?.toString() ?? '') + delta;
                }
              });
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() => _sending = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeLast();
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim: ${e.toString()}')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final res = await ApiService.delete('/api/chat/history');
    if (!mounted) return;
    if (res.success) {
      setState(() => _messages = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Bot AI'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus riwayat?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _clearHistory();
                        },
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              "Tanya apa saja tentang masak",
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[index];
                          final isUser = m['role'] == 'user';
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? const Color(0xFF4CAF50)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.8),
                              child: isUser
                                  ? Text(
                                      m['content']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    )
                                  : MarkdownBody(
                                      data: m['content']?.toString() ?? '',
                                      styleSheet: MarkdownStyleSheet(
                                        p: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                          height: 1.4,
                                        ),
                                        listBullet: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        strong: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      shrinkWrap: true,
                                    ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
