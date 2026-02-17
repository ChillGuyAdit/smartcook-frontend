import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';

import 'masakan.dart';

class CategoryPage extends StatefulWidget {
  final String categoryName;
  final List<Color> themeColors;
  final String headerImagePath;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.themeColors,
    required this.headerImagePath,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  List<Map<String, dynamic>> _allFoodList = [];
  List<Map<String, dynamic>> _filteredFoodList = [];
  String _searchQuery = "";
  int _maxCalories = 500;
  int _maxTime = 45;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  String _categoryToParam() {
    final n = widget.categoryName.toLowerCase();
    if (n.contains("barat")) return "western";
    if (n.contains("sehat") || n.contains("rendah kalori")) return "healthy";
    if (n.contains("nutrisi") || n.contains("seimbang")) return "balanced";
    return "";
  }

  Future<void> _loadRecipes() async {
    setState(() => _loading = true);
    final category = _categoryToParam();
    final params = <String, String>{'page': '1', 'limit': '50'};
    if (category.isNotEmpty) params['category'] = category;
    final res = await ApiService.get('/api/recipes', queryParameters: params);
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
      _allFoodList = list;
      _filteredFoodList = List.from(_allFoodList);
      _loading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredFoodList = _allFoodList.where((food) {
        final title = food["title"]?.toString().toLowerCase() ?? '';
        final matchSearch =
            _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
        final calVal = food["nutrition_info"] is Map
            ? (food["nutrition_info"] as Map)["calories"]
            : food["cal"];
        final foodCal =
            calVal != null ? int.tryParse(calVal.toString()) ?? 0 : 0;
        final matchCal = foodCal <= _maxCalories;
        final prep = food["prep_time"] ?? 0;
        final cook = food["cook_time"] ?? 0;
        final totalTime = (prep is int ? prep : 0) + (cook is int ? cook : 0);
        final matchTime = totalTime <= _maxTime;
        return matchSearch && matchCal && matchTime;
      }).toList();
    });
  }

  // Fungsi untuk memunculkan Pop Up Filter di bawah Icon
  void _showFilterMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Filter Dismiss",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight, // Posisikan di kanan atas
          child: Container(
            margin: const EdgeInsets.only(
                top: 150, right: 20), // Atur jarak agar pas di bawah icon
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    )
                  ],
                ),
                // Gunakan StatefulBuilder agar UI +/- di dalam popup bisa berubah
                child: StatefulBuilder(
                  builder: (context, setPopupState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Filter Pencarian",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),

                        // --- FILTER KALORI ---
                        const Text("Maks. Kalori (Kal)",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.redAccent),
                              onPressed: () => setPopupState(() =>
                                  _maxCalories =
                                      (_maxCalories - 50).clamp(50, 1000)),
                            ),
                            Text("$_maxCalories",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => setPopupState(() =>
                                  _maxCalories =
                                      (_maxCalories + 50).clamp(50, 1000)),
                            ),
                          ],
                        ),

                        // --- FILTER WAKTU ---
                        const Text("Maks. Waktu (Menit)",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.redAccent),
                              onPressed: () => setPopupState(() =>
                                  _maxTime = (_maxTime - 5).clamp(5, 120)),
                            ),
                            Text("$_maxTime",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => setPopupState(() =>
                                  _maxTime = (_maxTime + 5).clamp(5, 120)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        // TOMBOL TERAPKAN
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: widget.themeColors[1],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _applyFilters(); // Terapkan filter ke list
                              Navigator.pop(context); // Tutup popup
                            },
                            child: const Text("Terapkan",
                                style: TextStyle(color: Colors.white)),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      // MENGGANTI Column MENJADI CustomScrollView AGAR HEADER BISA MENGECIL SAAT SCROLL
      body: CustomScrollView(
        slivers: [
          // --- HEADER DINAMIS (SLIVER APP BAR) ---
          SliverAppBar(
            pinned: true,
            expandedHeight: 200.0, // Tinggi saat keadaan terbuka full
            toolbarHeight: 80.0, // Tinggi minimum saat mengecil
            automaticallyImplyLeading:
                false, // Kita buat tombol back custom sendiri
            backgroundColor: widget.themeColors[0], // Fallback warna
            elevation: 0,
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Menghitung persentase scroll: 0.0 (Full Terbuka) -> 1.0 (Full Mengecil)
                final top = constraints.biggest.height;
                final safeArea = MediaQuery.of(context).padding.top;
                final maxHeight = 200.0 + safeArea;
                final minHeight = 80.0 + safeArea;

                double percent = ((maxHeight - top) / (maxHeight - minHeight))
                    .clamp(0.0, 1.0);

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.themeColors,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Gambar Transparan di Kanan Bawah (Menghilang perlahan saat scroll naik)
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Opacity(
                          opacity: (0.3 * (1 - percent)).clamp(0.0, 0.3),
                          child:
                              Image.asset(widget.headerImagePath, width: 120),
                        ),
                      ),

                      // Tombol Back Custom (Posisinya tetap fix)
                      Positioned(
                        top: safeArea + 16,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      // Konten Judul & Deskripsi (Bergerak secara dinamis)
                      Positioned(
                        // Bergerak dari bawah ke samping tombol back
                        left: 16 + (48 * percent),
                        top: (safeArea + 76) - (60 * percent),
                        // Melebar ke kanan saat header mengecil karena gambar sudah hilang
                        right: 120 - (104 * percent),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Teks Judul
                            Text(
                              widget.categoryName.replaceAll("\n", " "),
                              maxLines: percent > 0.5 ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                // Ukuran font mengecil sedikit saat di atas
                                fontSize: 22 - (4 * percent),
                                height: 1.2,
                              ),
                            ),
                            SizedBox(
                                height: 8 - (4 * percent)), // Spasi mengecil

                            // Teks Deskripsi (Tetap ada, namun opacity dan limit baris menyesuaikan)
                            Opacity(
                              opacity: 1.0 - (0.2 * percent),
                              child: Text(
                                "Kumpulan resep terbaik untuk kategori ${widget.categoryName.replaceAll("\n", " ").toLowerCase()}.",
                                // Berubah menjadi 1 baris (terpotong "...") saat header mengecil
                                maxLines: percent > 0.5 ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12 - (1 * percent),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // --- SEARCH & FILTER BAR ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  // Kolom Pencarian
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters(); // Langsung filter saat ngetik
                        },
                        decoration: InputDecoration(
                          hintText: "Cari resep...",
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14),
                          border: InputBorder.none,
                          icon:
                              Icon(Icons.search, color: widget.themeColors[1]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol Filter
                  GestureDetector(
                    onTap: () => _showFilterMenu(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.themeColors[1],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeColors[1].withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child:
                          const Icon(Icons.tune_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LIST MAKANAN ---
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: _loading
                ? const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : _filteredFoodList.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Text(
                              "Resep tidak ditemukan 😥\nCoba ubah filter atau pencarianmu.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final food = _filteredFoodList[index];
                            return _buildFoodListItem(food);
                          },
                          childCount: _filteredFoodList.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodListItem(Map<String, dynamic> food) {
    final recipeId = food["_id"]?.toString();
    final title = food["title"]?.toString() ?? "Resep";
    final imageUrl = food["image_url"]?.toString();
    final foodImage = food["image"]?.toString();
    final calVal = food["nutrition_info"] is Map
        ? (food["nutrition_info"] as Map)["calories"]
        : food["cal"];
    final cal = calVal?.toString() ?? "0";
    final prep = food["prep_time"] ?? 0;
    final cook = food["cook_time"] ?? 0;
    final timeStr = food["time"] ??
        "${(prep is int ? prep : 0) + (cook is int ? cook : 0)}m";
    return GestureDetector(
      onTap: () {
        if (recipeId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MasakanPage(recipeId: recipeId),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: widget.themeColors[0].withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.restaurant,
                            color: widget.themeColors[1]))
                    : (foodImage != null && foodImage.isNotEmpty
                        ? Image.asset(foodImage, fit: BoxFit.cover)
                        : Icon(Icons.restaurant, color: widget.themeColors[1])),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text("$cal Kal",
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(timeStr.toString(),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: widget.themeColors[1]),
            ),
          ],
        ),
      ),
    );
  }
}
