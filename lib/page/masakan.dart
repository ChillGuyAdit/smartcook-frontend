import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MasakanPage extends StatefulWidget {
  final String? recipeId;
  final String? title;
  final String? imagePath;
  final String? calories;
  final String? time;

  const MasakanPage({
    super.key,
    this.recipeId,
    this.title,
    this.imagePath,
    this.calories,
    this.time,
  });

  @override
  State<MasakanPage> createState() => _MasakanPageState();
}

class _MasakanPageState extends State<MasakanPage> {
  bool isSaved = false;
  bool _loading = true;
  List<Map<String, dynamic>> _ingredients = [];
  List<dynamic> _steps = [];
  String _displayTitle = '';
  String _displayImage = '';
  String _displayCalories = '0 Kal';
  String _displayTime = '0m';
  static const String _fallbackAsset = 'image/jagung_bowl.png';

  ImageProvider _resolveImageProvider() {
    final s = _displayImage.trim();
    if (s.isEmpty) return const AssetImage(_fallbackAsset);
    if (s.startsWith('http')) return NetworkImage(s);
    return AssetImage(s);
  }

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      _loadRecipe();
      _checkFavorite();
    } else {
      _displayTitle = widget.title ?? 'Resep';
      _displayImage = widget.imagePath ?? 'image/soup.png';
      _displayCalories = widget.calories ?? '0 Kal';
      _displayTime = widget.time ?? '0m';
      _loading = false;
    }
  }

  Future<void> _loadRecipe() async {
    final res = await ApiService.get('/api/recipes/${widget.recipeId}');
    if (!mounted) return;
    if (res.success && res.data != null) {
      final r = res.data as Map<String, dynamic>;
      await OfflineCacheService.saveRecipe(r);
      setState(() {
        _displayTitle = r['title']?.toString() ?? 'Resep';
        _displayImage = r['image_url']?.toString() ?? 'image/soup.png';
        final cal = r['nutrition_info'] is Map
            ? (r['nutrition_info'] as Map)['calories']?.toString()
            : '0';
        _displayCalories = '${cal} Kal';
        final prep = r['prep_time'] ?? 0;
        final cook = r['cook_time'] ?? 0;
        _displayTime = '${prep + cook}m';
        _ingredients = (r['ingredients'] as List?)
                ?.map((e) => e is Map
                    ? Map<String, dynamic>.from(e)
                    : <String, dynamic>{'name': e.toString()})
                .toList() ??
            [];
        _steps = (r['steps'] as List?)
                ?.map((e) {
                  if (e is String) return e;
                  if (e is Map) return (e['instruction'] ?? e['text'] ?? '').toString();
                  return e.toString();
                })
                .toList() ??
            [];
        _loading = false;
      });
    } else {
      // Offline fallback: coba load dari cache device
      final cached = widget.recipeId != null
          ? await OfflineCacheService.getRecipeById(widget.recipeId!)
          : null;
      if (cached != null) {
        setState(() {
          _displayTitle = cached['title']?.toString() ?? 'Resep';
          _displayImage = cached['image_url']?.toString() ?? 'image/soup.png';
          final cal = cached['nutrition_info'] is Map
              ? (cached['nutrition_info'] as Map)['calories']?.toString()
              : '0';
          _displayCalories = '${cal} Kal';
          final prep = cached['prep_time'] ?? 0;
          final cook = cached['cook_time'] ?? 0;
          _displayTime = '${prep + cook}m';
          _ingredients = (cached['ingredients'] as List?)
                  ?.map((e) => e is Map
                      ? Map<String, dynamic>.from(e)
                      : <String, dynamic>{'name': e.toString()})
                  .toList() ??
              [];
          _steps = (cached['steps'] as List?)
                  ?.map((e) {
                    if (e is String) return e;
                    if (e is Map) {
                      return (e['instruction'] ?? e['text'] ?? '').toString();
                    }
                    return e.toString();
                  })
                  .toList() ??
              [];
          _loading = false;
        });
        return;
      }

      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Gagal memuat resep')),
        );
      }
    }
  }

  Future<void> _checkFavorite() async {
    final res = await ApiService.get('/api/favorites');
    if (!mounted) return;
    if (res.success && res.data is List) {
      final list = res.data as List;
      final found = list.any((e) {
        final r = e is Map ? e['recipe'] : null;
        final id = r is Map ? r['_id'] : null;
        return id?.toString() == widget.recipeId;
      });
      setState(() => isSaved = found);
    }
  }

  Future<void> _toggleSave() async {
    if (widget.recipeId == null) {
      setState(() => isSaved = !isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isSaved ? "Resep disimpan!" : "Resep dihapus dari simpanan")),
      );
      return;
    }
    if (isSaved) {
      final res = await ApiService.delete('/api/favorites/${widget.recipeId}');
      if (!mounted) return;
      if (res.success) {
        setState(() => isSaved = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resep dihapus dari simpanan")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Gagal menghapus')),
        );
      }
    } else {
      final res = await ApiService.post(
        '/api/favorites/${widget.recipeId}',
        useAuth: true,
      );
      if (!mounted) return;
      if (res.success) {
        setState(() => isSaved = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Resep berhasil disimpan!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.message ?? 'Gagal menyimpan')),
        );
      }
    }
  }

  Future<void> _launchYoutube(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER DENGAN EFEK BLUR ---
            Stack(
              children: [
                // 1. Background Gambar yang di-Blur
                Container(
                  height: 320,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: _resolveImageProvider(),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                      child: Container(
                        // Lapisan gelap agar teks putih terbaca jelas
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),

                // 2. Konten Header (Tombol, Teks, dan Gambar Circle)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        // Tombol Back & Save
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
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
                                    size: 20),
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleSave,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isSaved
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  color: isSaved ? Colors.orange : Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // Informasi Teks (Kiri) & Gambar Circle (Kanan)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Sisi Kiri: Judul, Waktu, Kalori
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _displayTitle,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      _buildGlassBadge(
                                        icon: Icons.access_time_rounded,
                                        text: _displayTime,
                                      ),
                                      _buildGlassBadge(
                                        icon:
                                            Icons.local_fire_department_rounded,
                                        text: _displayCalories,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Sisi Kanan: Gambar Masakan Circle
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                                image: DecorationImage(
                                  image: _resolveImageProvider(),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // --- KONTEN BAWAH (Bahan & Cara Membuat) ---
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Bahan yang dibutuhkan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // List Bahan
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: _ingredients.isEmpty
                            ? [
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Text('Tidak ada data bahan',
                                      style: TextStyle(color: Colors.black54)),
                                )
                              ]
                            : _ingredients.map((bahan) {
                                final nama = bahan['name'] ??
                                    bahan['nama'] ??
                                    bahan['ingredient_name'] ??
                                    bahan.toString();
                                final qty = bahan['quantity'] ?? bahan['qty'];
                                final text = qty != null
                                    ? '$nama ($qty)'
                                    : nama.toString();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          text,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87),
                                        ),
                                      ),
                                      const Icon(Icons.circle,
                                          color: Colors.green, size: 12),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Button Cari Bahan
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon:
                            const Icon(Icons.shopping_cart_outlined, size: 20),
                        label: const Text(
                          "Cari Bahan yang Kurang",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Bagian Cara Membuat
                    const Text(
                      "Cara Membuat",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // List Langkah
                    Column(
                      children: _steps.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Tidak ada langkah',
                                    style: TextStyle(color: Colors.black54)),
                              )
                            ]
                          : List.generate(_steps.length, (index) {
                              final step = _steps[index];
                              final text =
                                  step is String ? step : step.toString();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50)
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: const TextStyle(
                                          color: Color(0xFF2E7D32),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          text,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                    ),
                    const SizedBox(height: 15),

                    // TOMBOL YOUTUBE (TAMBAHAN BARU)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _launchYoutube(
                            "https://www.youtube.com/results?search_query=resep+$_displayTitle"),
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            size: 20),
                        label: const Text(
                          "Lihat Tutorial di YouTube",
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              const Color(0xFFFF0000), // Warna khas YouTube
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 20),

                    // REKOMENDASI MAKANAN (TAMBAHAN BARU)
                    const Text(
                      "Rekomendasi Lainnya",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5 Card Rekomendasi
                    Column(
                      children: List.generate(5, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildBigRecommendationCard(onTap: () {
                            // Logic klik rekomendasi
                          }),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // Widget bantuan untuk membuat badge (waktu/kalori)
  Widget _buildGlassBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // Widget Big Recommendation Card
  Widget _buildBigRecommendationCard({VoidCallback? onTap}) {
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
                  Image.asset(
                    'image/jagung_bowl.png', // Sesuaikan path ini
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
                  const Text("Jagung Sayur Kentang Bowl",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  const Text(
                    "Cocok Untuk Diet, Diabetes, rendah gula, tinggi serat",
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag("Aman Untuk Diabetes", const Color(0xFFE8F5E9),
                          const Color(0xFF2E7D32)),
                      _buildTag("Bebas Kacang", const Color(0xFFFFF3E0),
                          const Color(0xFFE65100)),
                      _buildTag("Pakai Blender", const Color(0xFFE3F2FD),
                          const Color(0xFF1565C0)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 18, color: Colors.orange),
                      const Text(" 220 Kal",
                          style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 15),
                      const Icon(Icons.access_time_rounded,
                          size: 18, color: Colors.blueGrey),
                      const Text(" 10 menit",
                          style: TextStyle(
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

  // Widget Tag bantuan untuk Big Card
  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
