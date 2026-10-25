import 'package:flutter/material.dart';
import 'package:smartcook/models/recipe.dart';
import 'package:smartcook/service/recipe_repository.dart';

import '../core/theme/app_theme_colors.dart';
import '../core/theme/shadows.dart';
import 'masakan.dart';
import 'reusable/net_image.dart';
import '../core/l10n/strings.dart';

class CategoryPage extends StatefulWidget {
  final String categoryName;
  final List<Color> themeColors;
  final String headerImagePath;
  final Future<List<Recipe>> Function()? loader;

  const CategoryPage({
    super.key,
    required this.categoryName,
    required this.themeColors,
    required this.headerImagePath,
    this.loader,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List<Recipe>> _future;
  String _searchQuery = "";
  int _maxCalories = 500;
  int _maxTime = 45;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Recipe>> _fetch() => (widget.loader ??
      () => RecipeRepository.fetchByCategory(_categoryToParam()))();

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  String _categoryToParam() {
    final n = widget.categoryName.toLowerCase();
    if (n.contains("barat")) return "western";
    if (n.contains("sehat") || n.contains("rendah kalori")) return "healthy";
    if (n.contains("nutrisi") || n.contains("seimbang")) return "balanced";
    return "";
  }

  /// Title shown to the user. `categoryName` itself stays Indonesian because
  /// [_categoryToParam] derives the API filter from it.
  String _displayName(BuildContext context) {
    switch (_categoryToParam()) {
      case 'healthy':
        return context.s.catTitleHealthy;
      case 'balanced':
        return context.s.catTitleBalanced;
      case 'western':
        return context.s.catTitleWestern;
      default:
        return widget.categoryName.replaceAll("\n", " ");
    }
  }

  void _applyFilters() {
    setState(() {});
  }

  List<Recipe> _filter(List<Recipe> all) {
    final query = _searchQuery.toLowerCase();
    return all.where((r) {
      final matchSearch = query.isEmpty || r.title.toLowerCase().contains(query);
      return matchSearch &&
          r.calories <= _maxCalories &&
          r.totalMinutes <= _maxTime;
    }).toList();
  }

  // Fungsi untuk memunculkan Pop Up Filter di bawah Icon
  void _showFilterMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.s.filterDismiss,
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
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: context.floatShadow,
                ),
                // Gunakan StatefulBuilder agar UI +/- di dalam popup bisa berubah
                child: StatefulBuilder(
                  builder: (context, setPopupState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.s.searchFilter,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: context.colors.textPrimary)),
                        const Divider(),

                        // --- FILTER KALORI ---
                        Text(context.s.maxCaloriesLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary)),
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
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: context.colors.textPrimary)),
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
                        Text(context.s.maxTimeLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary)),
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
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: context.colors.textPrimary)),
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
                            child: Text(context.s.apply,
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
      backgroundColor: context.colors.background,
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
                              color: Colors.white.withValues(alpha: 0.2),
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
                                context.s.categoryBlurb(_displayName(context).toLowerCase()),
                                // Berubah menjadi 1 baris (terpotong "...") saat header mengecil
                                maxLines: percent > 0.5 ? 1 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
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
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: context.softShadow,
                      ),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters(); // Langsung filter saat ngetik
                        },
                        decoration: InputDecoration(
                          hintText: context.s.searchRecipes,
                          hintStyle: TextStyle(
                              color: context.colors.textDisabled,
                              fontSize: 14),
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
                            color: widget.themeColors[1]
                                .withValues(alpha: 0.3),
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
            sliver: FutureBuilder<List<Recipe>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Column(
                          children: [
                            Text(
                              context.s.recipesLoadFailed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: context.colors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _reload,
                              child: Text(context.s.updateRetry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final foods = _filter(snapshot.data ?? const <Recipe>[]);
                if (foods.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Text(
                          context.s.recipesNotFound,
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: context.colors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildFoodListItem(foods[index]),
                    childCount: foods.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodListItem(Recipe food) {
    final recipeId = food.id;
    final title = food.title;
    final imageUrl = food.imageUrl;
    final cal = food.calories.toString();
    final timeStr = "${food.totalMinutes}m";
    return GestureDetector(
      onTap: () {
        if (recipeId.isNotEmpty) {
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
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.softShadow,
        ),
        child: Row(
          children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: widget.themeColors[0].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: imageUrl.isNotEmpty
                    ? NetImage(imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.restaurant,
                            color: widget.themeColors[1]))
                    : Icon(Icons.restaurant, color: widget.themeColors[1]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(context.s.kcal(cal),
                          style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textSecondary)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time_rounded,
                          size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 4),
                      Text(timeStr,
                          style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.surfaceVariant,
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
