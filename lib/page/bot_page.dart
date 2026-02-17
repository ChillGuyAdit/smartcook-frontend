import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:smartcook/config/api_config.dart';
import 'package:smartcook/page/masakan.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/service/token_service.dart';

class BotPage extends StatefulWidget {
  const BotPage({super.key});

  @override
  State<BotPage> createState() => _BotPageState();
}

class _BotPageState extends State<BotPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _streamingOrTyping = false; // true sampai stream + animasi ketik selesai

  // State untuk animasi mengetik
  String _bufferedContent = '';
  String _displayedContent = '';
  bool _isTyping = false;
  Timer? _typingTimer;
  static const int _typingIntervalMs = 100;

  // State untuk recipe embeds: Map<messageIndex, List<recipes>>
  Map<int, List<Map<String, dynamic>>> _recipeEmbeds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/chat/history');
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    Map<int, List<Map<String, dynamic>>> embeds = {};
    if (res.success && res.data != null) {
      final data = res.data;
      List? msgList;
      if (data is Map && data['messages'] != null) {
        msgList = data['messages'] is List ? data['messages'] as List : null;
      } else if (data is List) {
        msgList = data;
      }
      if (msgList != null) {
        for (int i = 0; i < msgList.length; i++) {
          final e = msgList[i];
          if (e is Map<String, dynamic>) {
            list.add(e);
            if (e['role'] == 'model') {
              final recipeEmbedsRaw = e['recipe_embeds'];
              if (recipeEmbedsRaw != null) {
                List<Map<String, dynamic>> recipes = [];
                if (recipeEmbedsRaw is List) {
                  recipes = recipeEmbedsRaw
                      .map((r) {
                        if (r is Map) {
                          return Map<String, dynamic>.from(r);
                        }
                        return <String, dynamic>{};
                      })
                      .where((r) => r.isNotEmpty)
                      .toList();
                }
                if (recipes.isNotEmpty) {
                  embeds[i] = recipes;
                }
              }
            }
          }
        }
      }
    }
    setState(() {
      _messages = list;
      _recipeEmbeds = embeds;
      _loading = false;
    });
  }

  void _startTypingAnimation() {
    if (_isTyping) return;
    _isTyping = true;
    if (_displayedContent.isEmpty) _displayedContent = '';

    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(
      const Duration(milliseconds: _typingIntervalMs),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (_bufferedContent.length <= _displayedContent.length) {
          timer.cancel();
          _isTyping = false;
          if (mounted) {
            setState(() {
              _sending = false;
              _streamingOrTyping = false;
            });
          }
          return;
        }
        final remaining = _bufferedContent.substring(_displayedContent.length);
        if (remaining.isEmpty) return;

        // Ambil chunk karakter dengan mempertahankan semua karakter termasuk spasi, newline, dan markdown
        // Menggunakan chunk size yang lebih kecil untuk animasi yang lebih halus
        // Chunk size sekitar 30-50 karakter per tick memberikan efek ketik yang natural
        const chunkSize = 50;
        final toAdd = remaining.length > chunkSize
            ? remaining.substring(0, chunkSize)
            : remaining;

        if (toAdd.isEmpty) return;

        setState(() {
          _displayedContent += toAdd;
          if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
            _messages.last['content'] = _displayedContent;
          }
        });
        _scrollToBottom();
      },
    );
  }

  void _stopTypingAnimation() {
    _typingTimer?.cancel();
    _typingTimer = null;
    _isTyping = false;
    if (_bufferedContent.length > _displayedContent.length) {
      setState(() {
        _displayedContent = _bufferedContent;
        if (_messages.isNotEmpty && _messages.last['role'] == 'model') {
          _messages.last['content'] = _displayedContent;
        }
      });
    }
  }

  static const double _scrollThreshold = 100;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - _scrollThreshold) {
        _scrollController.animateTo(
          pos.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _streamingOrTyping) return;
    _controller.clear();

    _stopTypingAnimation();
    _bufferedContent = '';
    _displayedContent = '';

    final userMessage = {'role': 'user', 'content': text};
    final modelMessage = {'role': 'model', 'content': ''};
    setState(() {
      _messages.add(userMessage);
      _messages.add(modelMessage);
      _sending = true;
      _streamingOrTyping = true;
    });
    final modelMessageIndex = _messages.length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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
          _recipeEmbeds.remove(modelMessageIndex);
          _sending = false;
          _streamingOrTyping = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errMsg)));
        }
        return;
      }

      String buffer = '';
      bool firstChunkReceived = false;

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        if (!mounted) break;
        buffer += chunk;
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();

        for (final part in parts) {
          if (part.trim().isEmpty) continue;

          // Parse SSE format: "data: {...}"
          final lines = part.split('\n');
          String? dataLine;
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              dataLine = line.substring(6).trim();
              break;
            }
          }

          if (dataLine == null || dataLine.isEmpty || dataLine == '[DONE]')
            continue;

          try {
            final data = jsonDecode(dataLine) as Map<String, dynamic>?;
            if (data == null) continue;

            // Heartbeat: jangan ubah _sending/_streamingOrTyping; tombol tetap disabled
            if (data['status'] == 'connected') continue;

            // Handle error
            if (data['error'] != null) {
              throw Exception(data['error'].toString());
            }

            // Handle recipe embed
            if (data['type'] == 'recipe_embed' && data['recipes'] != null) {
              final recipes = (data['recipes'] as List?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  [];
              if (recipes.isNotEmpty && mounted) {
                setState(() {
                  _recipeEmbeds[modelMessageIndex] = recipes;
                });
              }
              continue;
            }

            // Done: set buffer saja; timer tetap jalan sampai tampil semua pelan-pelan
            if (data['done'] == true && data['fullReply'] != null) {
              _bufferedContent = data['fullReply'].toString();
              if (!_isTyping) _startTypingAnimation();
              break;
            }

            // Handle text chunk: tambahkan ke buffer
            final delta = data['text']?.toString();
            if (delta != null && delta.isNotEmpty) {
              _bufferedContent += delta;

              // Mulai animasi mengetik setelah chunk pertama
              if (!firstChunkReceived) {
                firstChunkReceived = true;
                _startTypingAnimation();
              }
            }
          } catch (e) {
            // Skip jika parsing gagal (bisa jadi chunk terpotong)
            continue;
          }
        }
      }

      if (mounted && !_isTyping) {
        setState(() {
          _sending = false;
          _streamingOrTyping = false;
        });
        _scrollToBottom();
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _loadHistory();
        });
      }
    } catch (e) {
      if (!mounted) return;
      _stopTypingAnimation();
      setState(() {
        _messages.removeLast();
        _recipeEmbeds.remove(modelMessageIndex);
        _sending = false;
        _streamingOrTyping = false;
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
      setState(() {
        _messages = [];
        _recipeEmbeds = {};
      });
    }
  }

  Widget _buildRecipeEmbedCard(Map<String, dynamic> recipe) {
    const String fallbackAsset = 'image/jagung_bowl.png';
    final id = recipe['_id']?.toString();
    final title = recipe['title']?.toString() ?? 'Resep';
    final imageUrl = recipe['image_url']?.toString();
    final cal = recipe['nutrition_info'] is Map
        ? (recipe['nutrition_info'] as Map)['calories']?.toString()
        : '0';
    final prep = recipe['prep_time'] ?? 0;
    final cook = recipe['cook_time'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    fallbackAsset,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                )
              : Image.asset(
                  fallbackAsset,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('$cal Kal • ${prep + cook}m'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: id != null
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MasakanPage(recipeId: id),
                  ),
                );
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (OfflineManager.isOffline.value) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('SmartChef'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'SmartChef tidak tersedia saat offline.\nSilakan sambungkan internet untuk melanjutkan.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('SmartChef'),
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
                                  fontSize: 16, color: Colors.black54),
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
                          final recipeEmbeds = _recipeEmbeds[index];

                          if (isUser) {
                            return Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
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
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.8),
                                child: Text(
                                  m['content']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: MarkdownBody(
                                        key: ValueKey(
                                            '${index}_${m['content']?.toString().length ?? 0}'),
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
                                    if (recipeEmbeds != null &&
                                        recipeEmbeds.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ...recipeEmbeds.map((recipe) =>
                                          _buildRecipeEmbedCard(recipe)),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }
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
                      onSubmitted: (_) {
                        if (!_sending && !_streamingOrTyping) _sendMessage();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed:
                        (_sending || _streamingOrTyping) ? null : _sendMessage,
                    icon: (_sending || _streamingOrTyping)
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
