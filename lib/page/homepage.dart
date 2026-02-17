import 'package:flutter/material.dart';
import 'reusable/bottom_navbar.dart';
import 'category.dart';
import 'kulkas.dart';
import 'masakan.dart';
import 'tambahkan_bahan.dart';
import 'search_page.dart';
import 'bot_page.dart';
import 'save_page.dart';
import 'profile_page.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';

class homepage extends StatefulWidget {
  const homepage({super.key});

  @override
  State<homepage> createState() => _homepageState();
}

class _homepageState extends State<homepage> {
  int _selectedIndex = 0;
  String _selectedMealTime = "breakfast";
  String _userName = 'Smarty';
  List<String> _userAllergies = [];
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _fridgePreview = [];
  List<Map<String, dynamic>> _recommendations = [];
  Map<String, List<Map<String, dynamic>>> _byMeal = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrapAndLoadData();
  }

  /// Langkah 1: tampilkan dulu data yang sudah ada di cache (jika ada),
  /// supaya home tidak lama kosong setelah login.
  /// Langkah 2: baru refresh dari API di background dan update UI.
  Future<void> _bootstrapAndLoadData() async {
    setState(() => _loading = true);

    // --- BOOTSTRAP DARI CACHE (cepat, tanpa nunggu jaringan) ---
    final cachedFavorites =
        await OfflineCacheService.getRecipeList('home_favorites_preview');
    final cachedRecs =
        await OfflineCacheService.getRecipeList('home_recommendations');
    final cachedBreakfast =
        await OfflineCacheService.getRecipeList('by_meal_breakfast');
    final cachedLunch =
        await OfflineCacheService.getRecipeList('by_meal_lunch');
    final cachedDinner =
        await OfflineCacheService.getRecipeList('by_meal_dinner');

    final hasAnyCache = cachedFavorites.isNotEmpty ||
        cachedRecs.isNotEmpty ||
        cachedBreakfast.isNotEmpty ||
        cachedLunch.isNotEmpty ||
        cachedDinner.isNotEmpty;

    if (mounted && hasAnyCache) {
      setState(() {
        _favorites = cachedFavorites;
        _recommendations = cachedRecs;
        _byMeal['breakfast'] = cachedBreakfast;
        _byMeal['lunch'] = cachedLunch;
        _byMeal['dinner'] = cachedDinner;
        _loading = false;
      });
    }

    // --- REFRESH ONLINE DI BACKGROUND ---
    await _loadData(fromBootstrap: hasAnyCache);
  }

  Future<void> _loadData({bool fromBootstrap = false}) async {
    if (!fromBootstrap) {
      // Jika tidak ada cache sama sekali, tampilkan loader sampai request pertama selesai
      setState(() => _loading = true);
    }

    final profileRes = await ApiService.get('/api/user/profile');
    final favRes =
        await ApiService.get('/api/favorites', queryParameters: {'limit': '4'});
    final fridgeRes = await ApiService.get('/api/fridge');
    final recRes = await ApiService.get('/api/recipes/recommendations',
        queryParameters: {'limit': '5'});
    final breakfastRes =
        await ApiService.get('/api/recipes/by-meal/breakfast');
    final lunchRes = await ApiService.get('/api/recipes/by-meal/lunch');
    final dinnerRes = await ApiService.get('/api/recipes/by-meal/dinner');

    final maybeOffline = !profileRes.success &&
        (profileRes.statusCode == null ||
            (profileRes.message ?? '').contains('koneksi'));

    if (!mounted) return;
    final profile = profileRes.data as Map<String, dynamic>?;
    if (profile != null) {
      if (profile['name'] != null) {
        _userName = profile['name'].toString();
      }
      final allergiesRaw = profile['allergies'];
      if (allergiesRaw is List) {
        _userAllergies = allergiesRaw
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        _userAllergies = [];
      }
    }

    // Parse online
    final favoritesOnline = _parseRecipeList(favRes.data);
    final fridgeOnline = _parseFridgeList(fridgeRes.data);
    final recOnline = _parseRecipeList(recRes.data);
    final breakfastOnline = _parseRecipeList(breakfastRes.data);
    final lunchOnline = _parseRecipeList(lunchRes.data);
    final dinnerOnline = _parseRecipeList(dinnerRes.data);

    // Cache jika berhasil (offline fallback)
    if (favoritesOnline.isNotEmpty) {
      await OfflineCacheService.saveRecipeList('home_favorites_preview', favoritesOnline);
    }
    if (recOnline.isNotEmpty) {
      await OfflineCacheService.saveRecipeList('home_recommendations', recOnline);
    }
    if (breakfastOnline.isNotEmpty) {
      await OfflineCacheService.saveRecipeList('by_meal_breakfast', breakfastOnline);
    }
    if (lunchOnline.isNotEmpty) {
      await OfflineCacheService.saveRecipeList('by_meal_lunch', lunchOnline);
    }
    if (dinnerOnline.isNotEmpty) {
      await OfflineCacheService.saveRecipeList('by_meal_dinner', dinnerOnline);
    }

    // Jika offline/failed, fallback ke cache
    final favorites = favoritesOnline.isNotEmpty
        ? favoritesOnline
        : await OfflineCacheService.getRecipeList('home_favorites_preview');
    final recs = recOnline.isNotEmpty
        ? recOnline
        : await OfflineCacheService.getRecipeList('home_recommendations');
    final breakfast = breakfastOnline.isNotEmpty
        ? breakfastOnline
        : await OfflineCacheService.getRecipeList('by_meal_breakfast');
    final lunch = lunchOnline.isNotEmpty
        ? lunchOnline
        : await OfflineCacheService.getRecipeList('by_meal_lunch');
    final dinner = dinnerOnline.isNotEmpty
        ? dinnerOnline
        : await OfflineCacheService.getRecipeList('by_meal_dinner');

    setState(() {
      OfflineManager.setOffline(maybeOffline);
      _favorites = favorites;
      _fridgePreview =
          fridgeOnline; // untuk kulkas, belum dicache (lebih dinamis)
      _recommendations = recs;
      _byMeal['breakfast'] = breakfast;
      _byMeal['lunch'] = lunch;
      _byMeal['dinner'] = dinner;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> _parseRecipeList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) {
        if (e is Map<String, dynamic>) {
          final recipe = e['recipe'] ?? e;
          if (recipe is Map<String, dynamic>) return recipe;
          return <String, dynamic>{};
        }
        return <String, dynamic>{};
      }).where((e) => e.isNotEmpty && e['_id'] != null).toList();
    }
    return [];
  }

  List<Map<String, dynamic>> _parseFridgeList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return [];
  }

  String _buildAllergySubtitle() {
    if (_userAllergies.isEmpty) {
      return 'Disesuaikan dengan preferensi kesehatanmu';
    }
    if (_userAllergies.length == 1) {
      return 'Aman untuk alergi: ${_userAllergies.first}';
    }
    final joined = _userAllergies.join(', ');
    return 'Aman untuk alergi: $joined';
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth > 350 ? 260 : screenWidth * 0.85;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: _selectedIndex == 0
          ? _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildHomeContent(screenWidth, cardWidth)
          : _buildOtherPages(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildOtherPages() {
    switch (_selectedIndex) {
      case 1:
        return const SearchPage();
      case 2:
        return const BotPage();
      case 3:
        return const SavePage();
      case 4:
        return const ProfilePage();
      default:
        return const Center(child: Text("Halaman tidak ditemukan"));
    }
  }

  Widget _buildHomeContent(double screenWidth, double cardWidth) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundImage: AssetImage('image/mainLogo.jpg'),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Hallo, $_userName! ",
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.black54)),
                            const Icon(Icons.auto_awesome,
                                color: Colors.amber, size: 16),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text("Masak apa hari ini?",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      size: 26, color: Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // --- CATEGORY SECTION ---
            const Text("Kategori selera memasak",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 15),
            SizedBox(
              height: 160,
              child: ListView(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryCard(
                    title: "Masakan Sehat\nRendah Kalori\nTinggi Nutrisi",
                    imagePath: 'image/broccoli.png',
                    cardWidth: cardWidth,
                    colors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryPage(
                            categoryName: "Masakan Sehat\nRendah Kalori",
                            themeColors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                            headerImagePath: 'image/broccoli.png',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCategoryCard(
                    title: "Masakan Dengan\nNutrisi Seimbang",
                    imagePath: 'image/balanced_food.png',
                    cardWidth: cardWidth,
                    colors: [const Color(0xFFFFA726), const Color(0xFFEF6C00)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryPage(
                            categoryName: "Masakan Nutrisi Seimbang",
                            themeColors: [Color(0xFFFFA726), Color(0xFFEF6C00)],
                            headerImagePath: 'image/balanced_food.png',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildCategoryCard(
                    title: "Ala-Ala\nMasakan Barat",
                    imagePath: 'image/burger.png',
                    cardWidth: cardWidth,
                    colors: [const Color(0xFFEF5350), const Color(0xFFC62828)],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CategoryPage(
                            categoryName: "Ala-Ala Masakan Barat",
                            themeColors: [Color(0xFFEF5350), Color(0xFFC62828)],
                            headerImagePath: 'image/burger.png',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // --- FRIDGE SECTION ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
                image: DecorationImage(
                  image: const AssetImage('image/bg_kulkas.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.4),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Apa saja isi kulkas mu?",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            )),
                        const SizedBox(height: 8),
                        const Text(
                          "Temukan berbagai resep makanan berdasarkan bahan yang kamu miliki",
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 15),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const TambahkanBahanPage()),
                            ).then((_) => _loadData());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white30)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_circle_outline,
                                    size: 20, color: Colors.white),
                                SizedBox(width: 8),
                                Text("Tambahkan Bahan",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(Icons.kitchen_outlined,
                            color: Colors.white70, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 0; i < _fridgePreview.take(2).length; i++) ...[
                                if (i > 0) const SizedBox(height: 4),
                                Text(
                                  "${i + 1}. ${_fridgePreview[i]['ingredient_name'] ?? 'Bahan'} (${_fridgePreview[i]['quantity'] ?? '-'})",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                              ],
                              if (_fridgePreview.isEmpty)
                                const Text("Belum ada bahan",
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const KulkasPage()),
                            ).then((_) => _loadData());
                          },
                          child: const Text(
                            "Lihat Semua >",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 35),

            // --- MEAL MODE SECTION (UPDATED) ---
            const Center(
                child: Text("Pilih Waktu Makan",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildModeFoodItem(
                    Icons.wb_twilight_rounded, "Breakfast", "breakfast", Colors.orange),
                _buildModeFoodItem(
                    Icons.wb_sunny_rounded, "Lunch", "lunch", Colors.green),
                _buildModeFoodItem(
                    Icons.nights_stay_rounded, "Dinner", "dinner", Colors.indigo),
              ],
            ),

            const SizedBox(height: 20),
            // Animasi dan List Makanan Berdasarkan Waktu
            _buildMealTimeDynamicSection(),

            const SizedBox(height: 35),

            // --- SAVE FOR YOU SECTION ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Disimpan untukmu",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(
                      _buildAllergySubtitle(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavePage(),
                      ),
                    ).then((_) => _loadData());
                  },
                  child: const Text("Lihat Semua",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
              ),
              itemCount: _favorites.length,
              itemBuilder: (context, index) {
                List<Color> cardColors = [
                  const Color(0xFF2A9D8F),
                  const Color(0xFFE76F51),
                  const Color(0xFFD4A373),
                  const Color(0xFF6A994E),
                ];
                final r = _favorites[index];
                final title = r['title']?.toString() ?? 'Resep';
                final imageUrl = r['image_url']?.toString();
                final cal = r['nutrition_info'] is Map
                    ? (r['nutrition_info'] as Map)['calories']?.toString() ?? '0'
                    : '0';
                final prep = r['prep_time'] ?? 0;
                final cook = r['cook_time'] ?? 0;
                final timeStr = '${prep + cook}m';
                return _buildSaveForYouCard(
                    title: title,
                    imagePath: imageUrl != null ? '' : 'image/soup.png',
                    imageUrl: imageUrl,
                    color: cardColors[index % 4],
                    calories: '${cal} Kal',
                    time: timeStr,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MasakanPage(
                            recipeId: r['_id']?.toString(),
                          ),
                        ),
                      );
                    });
              },
            ),
            const SizedBox(height: 35),

            // --- RECOMMENDATION SECTION ---
            const Text("5 Rekomendasi Masakan",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 15),

            ...(_recommendations.map((r) {
              final id = r['_id']?.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildBigRecommendationCard(
                  title: r['title']?.toString() ?? 'Resep',
                  imageUrl: r['image_url']?.toString(),
                  subtitle: r['description']?.toString(),
                  calories: r['nutrition_info'] is Map
                      ? (r['nutrition_info'] as Map)['calories']?.toString()
                      : null,
                  time: (r['prep_time'] ?? 0) + (r['cook_time'] ?? 0),
                  onTap: id == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MasakanPage(recipeId: id),
                            ),
                          );
                        },
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTimeDynamicSection() {
    Color activeColor;
    IconData activeIcon;
    switch (_selectedMealTime) {
      case "lunch":
        activeColor = Colors.orange.shade700;
        activeIcon = Icons.wb_sunny_rounded;
        break;
      case "dinner":
        activeColor = Colors.indigo.shade900;
        activeIcon = Icons.nights_stay_rounded;
        break;
      default:
        activeColor = Colors.amber.shade600;
        activeIcon = Icons.wb_twilight_rounded;
    }
    final currentList = _byMeal[_selectedMealTime] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child));
            },
            child: Column(
              key: ValueKey(_selectedMealTime),
              children: [
                Icon(activeIcon, color: activeColor.withOpacity(0.8), size: 40),
                const SizedBox(height: 5),
                Container(
                  height: 3,
                  width: 40,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: currentList.length,
            itemBuilder: (context, index) {
              final r = currentList[index];
              final id = r['_id']?.toString();
              final title = r['title']?.toString() ?? 'Resep';
              final imageUrl = r['image_url']?.toString();
              final prep = r['prep_time'] ?? 0;
              final cook = r['cook_time'] ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 210,
                  child: _buildSaveForYouCard(
                    title: title,
                    imagePath: imageUrl == null ? 'image/soup.png' : '',
                    imageUrl: imageUrl,
                    color: activeColor,
                    calories: null,
                    time: '${prep + cook}m',
                    onTap: id == null
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MasakanPage(recipeId: id),
                              ),
                            );
                          },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildModeFoodItem(IconData icon, String label, String mealKey, Color iconColor) {
    bool isSelected = _selectedMealTime == mealKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMealTime = mealKey;
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? iconColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? iconColor.withOpacity(0.3)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon,
                color: isSelected ? Colors.white : iconColor, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 13,
                  color: isSelected ? iconColor : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildSaveForYouCard({
    required String title,
    required String imagePath,
    String? imageUrl,
    required Color color,
    double imageRight = 0,
    double imageBottom = 5,
    String? calories,
    String? time,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        time ?? "10-15m",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        calories ?? "210 Kal",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ],
              ),
            ),
            Positioned(
              right: imageRight,
              bottom: imageBottom,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 75, height: 75, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.restaurant, color: Colors.white54, size: 40))
                  : Image.asset(imagePath.isNotEmpty ? imagePath : 'image/soup.png', width: 75),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBigRecommendationCard({
    String? title,
    String? imageUrl,
    String? subtitle,
    String? calories,
    int? time,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                children: [
                  imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            color: Colors.grey.shade200,
                            child: Image.asset('image/jagung_bowl.png',
                                fit: BoxFit.cover),
                          ),
                        )
                      : Image.asset(
                          'image/jagung_bowl.png',
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.star_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text("Cocok Untukmu",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title ?? "Resep",
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle ?? "",
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 18, color: Colors.orange),
                      Text(" ${calories ?? '0'} Kal",
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 15),
                      const Icon(Icons.access_time_rounded,
                          size: 18, color: Colors.blueGrey),
                      Text(" ${time ?? 0} menit",
                          style: const TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Colors.orange, size: 20),
                      ),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required String title,
    required String imagePath,
    required List<Color> colors,
    required double cardWidth,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colors[1].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.3)),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: Colors.amberAccent, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bookmark_outline_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ],
                  )
                ],
              ),
            ),
            Positioned(
              right: 10,
              bottom: 5,
              child: Image.asset(
                imagePath,
                width: 95,
                fit: BoxFit.contain,
              ),
            )
          ],
        ),
      ),
    );
  }
}
