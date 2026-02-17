import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/page/masakan.dart';

class SavePage extends StatefulWidget {
  const SavePage({super.key});

  @override
  State<SavePage> createState() => _SavePageState();
}

class _SavePageState extends State<SavePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _savedRecipes = [];

  @override
  void initState() {
    super.initState();
    _fetchSavedRecipes();
  }

  Future<void> _fetchSavedRecipes() async {
    setState(() => _isLoading = true);
    final response = await ApiService.get('/api/favorites');

    if (mounted) {
      if (response.success && response.data is List) {
        final List<dynamic> data = response.data;
        setState(() {
          _savedRecipes = data.map((item) {
            // Struktur response biasanya:
            // [ { "_id": "favId", "user": "userId", "recipe": { ...detail resep... } }, ... ]
            if (item is Map && item.containsKey('recipe')) {
              return item['recipe'] as Map<String, dynamic>;
            }
            // Fallback jika struktur berbeda (misal langsung list recipe)
            return item as Map<String, dynamic>;
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _savedRecipes = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text(
          "Disimpan",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedRecipes.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchSavedRecipes,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    itemCount: _savedRecipes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final recipe = _savedRecipes[index];
                      return _buildRecipeCard(recipe);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.bookmark_outline_rounded, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Belum ada resep yang disimpan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final String title = recipe['title'] ?? 'Resep Tanpa Nama';
    final String imagePath = recipe['image_url'] ?? 'image/soup.png';
    // Ambil info nutrisi
    String calories = "0 Kal";
    if (recipe['nutrition_info'] is Map) {
      calories = "${recipe['nutrition_info']['calories'] ?? 0} Kal";
    }

    // Ambil waktu
    final int prepTime = recipe['prep_time'] ?? 0;
    final int cookTime = recipe['cook_time'] ?? 0;
    final String time = "${prepTime + cookTime}m";
    final String recipeId = recipe['_id'] ?? '';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MasakanPage(
              recipeId: recipeId,
            ),
          ),
        );
        _fetchSavedRecipes(); // Refresh saat kembali
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Gambar Resep
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 90,
                height: 90,
                child: imagePath.startsWith('http')
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child:
                              const Icon(Icons.restaurant, color: Colors.grey),
                        ),
                      )
                    : Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child:
                              const Icon(Icons.restaurant, color: Colors.grey),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            // Info Resep
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.local_fire_department_rounded,
                          calories, Colors.orange),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                          Icons.access_time_rounded, time, Colors.blueGrey),
                    ],
                  ),
                ],
              ),
            ),
            // Icon Panah
            Container(
              padding: const EdgeInsets.only(left: 8),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
