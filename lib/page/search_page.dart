import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _query = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _query = query;
    });
    final res = await ApiService.get(
      '/api/recipes/search',
      queryParameters: {'q': query},
    );
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    if (res.success && res.data != null) {
      final data = res.data;
      if (data is List) {
        list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else if (data is Map && data['recipes'] is List) {
        list = (data['recipes'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
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
                onSubmitted: _search,
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
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.search_rounded,
                                      size: 80, color: Colors.grey),
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
                                                  const Icon(Icons.restaurant,
                                                      size: 56))
                                          : const Icon(Icons.restaurant,
                                              size: 56),
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
}
