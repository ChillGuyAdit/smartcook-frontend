import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'masakan.dart';

class SavePage extends StatefulWidget {
  const SavePage({super.key});

  @override
  State<SavePage> createState() => _SavePageState();
}

class _SavePageState extends State<SavePage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/favorites');
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    if (res.success && res.data != null) {
      final data = res.data;
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) {
            final recipe = e['recipe'];
            if (recipe is Map<String, dynamic>) list.add(recipe);
          }
        }
      }
    }
    setState(() {
      _favorites = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_favorites.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.bookmark_border_rounded, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Belum ada resep tersimpan",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _favorites.length,
          itemBuilder: (context, index) {
            final r = _favorites[index];
            final id = r['_id']?.toString();
            final title = r['title']?.toString() ?? 'Resep';
            final imageUrl = r['image_url']?.toString();
            final cal = r['nutrition_info'] is Map
                ? (r['nutrition_info'] as Map)['calories']?.toString()
                : '0';
            final prep = r['prep_time'] ?? 0;
            final cook = r['cook_time'] ?? 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, size: 56))
                      : const Icon(Icons.restaurant, size: 56),
                ),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('$cal Kal • ${prep + cook}m'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: id != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MasakanPage(recipeId: id),
                          ),
                        ).then((_) => _load());
                      }
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
