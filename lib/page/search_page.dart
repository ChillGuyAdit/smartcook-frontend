import 'dart:async';
import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';

import 'masakan.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _query = '';
  List<String> _recent = [];
  Timer? _debounce;
  bool _isOfflineFallback = false;
  static const String _fallbackAsset = 'image/jagung_bowl.png';

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    final list = await OfflineCacheService.getRecentQueries(limit: 20);
    if (!mounted) return;
    setState(() => _recent = list);
  }

  Future<void> _applyCachedForTyping(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _query = '';
        _loading = false;
        _isOfflineFallback = false;
      });
      return;
    }

    final key = 'search_${_norm(q)}';
    final cached = await OfflineCacheService.getRecipeList(key);
    final byTitle = cached.isNotEmpty
        ? cached
        : await OfflineCacheService.searchCachedByTitle(q);
    if (!mounted) return;
    setState(() {
      _query = q;
      _results = byTitle;
      _loading = false;
      _isOfflineFallback = byTitle.isNotEmpty;
    });
  }

  Future<void> _backgroundRefreshExisting(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final res = await ApiService.get(
      '/api/recipes/query',
      queryParameters: {'q': q},
    );
    if (!mounted) return;
    if (res.success && res.data is Map) {
      final data = res.data as Map;
      final results = data['results'];
      if (results is List) {
        final list = results
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final key = 'search_${_norm(q)}';
        await OfflineCacheService.saveRecipeList(key, list);
        setState(() {
          _results = list;
          _isOfflineFallback = false;
        });
      }
    }
  }

  Future<void> _submitGenerate(String q) async {
    final query = q.trim();
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _query = query;
      _isOfflineFallback = false;
    });

    // Generate + simpan (server)
    final res = await ApiService.get(
      '/api/recipes/ai-search',
      queryParameters: {'q': query},
    );
    if (!mounted) return;

    List<Map<String, dynamic>> list = [];
    if (res.success && res.data != null) {
      final data = res.data;
      if (data is Map) {
        final results = data['results'];
        if (results is List) {
          list =
              results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        } else if (data['generated'] is Map) {
          list = [Map<String, dynamic>.from(data['generated'] as Map)];
        }
      } else if (data is List) {
        list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } else {
      // Offline fallback: pakai cache yang ada
      await _applyCachedForTyping(query);
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final key = 'search_${_norm(query)}';
    await OfflineCacheService.saveRecipeList(key, list);
    await OfflineCacheService.addRecentQuery(query);
    await _loadRecents();

    setState(() {
      _results = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Cari resep...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) async {
                  await _applyCachedForTyping(v);
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 350), () {
                    _backgroundRefreshExisting(v);
                  });
                },
                onSubmitted: _submitGenerate,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty && _query.isNotEmpty
                      ? Center(
                          child: Text(
                            'Tidak ada hasil untuk "$_query"',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        )
                      : _results.isEmpty
                          ? _buildRecentSection()
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final r = _results[index];
                                final id = r['_id']?.toString();
                                final title = r['title']?.toString() ?? 'Resep';
                                final imageUrl = r['image_url']?.toString();
                                final cal = r['nutrition_info'] is Map
                                    ? (r['nutrition_info'] as Map)['calories']
                                        ?.toString()
                                    : '0';
                                final prep = r['prep_time'] ?? 0;
                                final cook = r['cook_time'] ?? 0;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: imageUrl != null &&
                                              imageUrl.isNotEmpty
                                          ? Image.network(imageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Image.asset(_fallbackAsset,
                                                      width: 56,
                                                      height: 56,
                                                      fit: BoxFit.cover))
                                          : Image.asset(_fallbackAsset,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover),
                                    ),
                                    title: Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle:
                                        Text('$cal Kal • ${prep + cook}m'),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16),
                                    onTap: id != null
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    MasakanPage(recipeId: id),
                                              ),
                                            );
                                          }
                                        : null,
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 4),
        const Text('Pencarian terbaru',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (_recent.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(height: 40),
                Icon(Icons.search_rounded, size: 80, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "Cari resep favoritmu",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recent.take(20).map((q) {
              return ActionChip(
                label: Text(q),
                onPressed: () {
                  _controller.text = q;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  _applyCachedForTyping(q);
                  _backgroundRefreshExisting(q);
                },
              );
            }).toList(),
          ),
        if (_isOfflineFallback)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'Menampilkan data dari cache (offline)',
              style: TextStyle(color: Colors.black45, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
