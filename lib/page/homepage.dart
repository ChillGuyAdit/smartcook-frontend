import 'package:flutter/material.dart';
import 'reusable/bottom_navbar.dart';
import 'category.dart';
import 'kulkas.dart';
import 'masakan.dart';
import 'tambahkan_bahan.dart';

class homepage extends StatefulWidget {
  const homepage({super.key});

  @override
  State<homepage> createState() => _homepageState();
}

class _homepageState extends State<homepage> {
  int _selectedIndex = 0;
  // Variabel baru untuk melacak waktu makan yang dipilih
  String _selectedMealTime = "Breakfast";

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double cardWidth = screenWidth > 350 ? 260 : screenWidth * 0.85;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
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
                            children: const [
                              Text("Hallo, Smarty! ",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.black54)),
                              Icon(Icons.auto_awesome,
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
                      colors: [
                        const Color(0xFF4CAF50),
                        const Color(0xFF2E7D32)
                      ],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryPage(
                              categoryName: "Masakan Sehat\nRendah Kalori",
                              themeColors: [
                                Color(0xFF4CAF50),
                                Color(0xFF2E7D32)
                              ],
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
                      colors: [
                        const Color(0xFFFFA726),
                        const Color(0xFFEF6C00)
                      ],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryPage(
                              categoryName: "Masakan Nutrisi Seimbang",
                              themeColors: [
                                Color(0xFFFFA726),
                                Color(0xFFEF6C00)
                              ],
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
                      colors: [
                        const Color(0xFFEF5350),
                        const Color(0xFFC62828)
                      ],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CategoryPage(
                              categoryName: "Ala-Ala Masakan Barat",
                              themeColors: [
                                Color(0xFFEF5350),
                                Color(0xFFC62828)
                              ],
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
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4),
                          ),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const TambahkanBahanPage()),
                              );
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
                              children: const [
                                Text("1. Kentang (5)",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                SizedBox(height: 4),
                                Text("2. Wortel (10)",
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const KulkasPage()),
                              );
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
                      Icons.wb_twilight_rounded, "Breakfast", Colors.orange),
                  _buildModeFoodItem(
                      Icons.wb_sunny_rounded, "Lunch", Colors.green),
                  _buildModeFoodItem(
                      Icons.nights_stay_rounded, "Dinner", Colors.indigo),
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
                    children: const [
                      Text("Disimpan untukmu",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      SizedBox(height: 4),
                      Text("Bebas kacang!",
                          style:
                              TextStyle(fontSize: 14, color: Colors.black54)),
                    ],
                  ),
                  const Text("Lihat Semua",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600)),
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
                itemCount: 4,
                itemBuilder: (context, index) {
                  List<Color> cardColors = [
                    const Color(0xFF2A9D8F),
                    const Color(0xFFE76F51),
                    const Color(0xFFD4A373),
                    const Color(0xFF6A994E),
                  ];

                  String title =
                      index % 2 == 1 ? "Jagung Rebus" : "Spinach Soup";
                  String imagePath =
                      index % 2 == 1 ? 'image/corn.png' : 'image/soup.png';

                  return _buildSaveForYouCard(
                      title: title,
                      imagePath: imagePath,
                      color: cardColors[index % 4],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MasakanPage(
                              title: title,
                              imagePath: imagePath,
                              calories: "210 Kal",
                              time: "10-15m",
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

              _buildBigRecommendationCard(onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MasakanPage(
                      title: "Jagung Sayur Kentang Bowl",
                      imagePath: 'image/jagung_bowl.png',
                      calories: "220 Kal",
                      time: "10 menit",
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              _buildBigRecommendationCard(onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MasakanPage(
                      title: "Jagung Sayur Kentang Bowl",
                      imagePath: 'image/jagung_bowl.png',
                      calories: "220 Kal",
                      time: "10 menit",
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
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

  // --- NEW: DYNAMIC MEAL TIME SECTION ---
  Widget _buildMealTimeDynamicSection() {
    Color activeColor;
    IconData activeIcon;
    List<Map<String, String>> currentList;

    // Logika penentuan warna, icon, dan data list (Tetap sesuai code awal Anda)
    switch (_selectedMealTime) {
      case "Lunch":
        activeColor = Colors.orange.shade700;
        activeIcon = Icons.wb_sunny_rounded;
        currentList = [
          {"title": "Nasi Goreng Spesial", "img": "image/soup.png"},
          {"title": "Ayam Bakar Madu", "img": "image/corn.png"},
        ];
        break;
      case "Dinner":
        activeColor = Colors.indigo.shade900;
        activeIcon = Icons.nights_stay_rounded;
        currentList = [
          {"title": "Sop Ayam Hangat", "img": "image/soup.png"},
          {"title": "Steak Tempe", "img": "image/corn.png"},
        ];
        break;
      default: // Breakfast
        activeColor = Colors.amber.shade600;
        activeIcon = Icons.wb_twilight_rounded;
        currentList = [
          {"title": "Oatmeal Buah", "img": "image/soup.png"},
          {"title": "Roti Gandum Telur", "img": "image/corn.png"},
        ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Efek Animasi Icon di Tengah
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

        // List Card Makanan Horizontal
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            // Clip.none agar card "tembus" ke samping dan shadow tidak terpotong
            clipBehavior: Clip.none,
            // Padding horizontal 20 agar card pertama tidak menempel ke pinggir layar
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: currentList.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width:
                      210, // Lebar disesuaikan sedikit agar proporsional dengan tinggi baru
                  child: _buildSaveForYouCard(
                    title: currentList[index]["title"]!,
                    imagePath: currentList[index]["img"]!,
                    color: activeColor,
                    // Jika widget card Anda mendukung kustomisasi gaya teks/ikon:
                    // Gunakan warna putih pekat (Colors.white) untuk elemen kalori/waktu
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MasakanPage(
                            title: currentList[index]["title"]!,
                            imagePath: currentList[index]["img"]!,
                            calories: "180 Kal",
                            time: "15m",
                          ),
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

  Widget _buildModeFoodItem(IconData icon, String label, Color iconColor) {
    bool isSelected = _selectedMealTime == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMealTime = label;
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
    required Color color,
    double imageRight = 0,
    double imageBottom = 5,
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
                    maxLines: 1, // Membatasi hanya 1 baris
                    overflow: TextOverflow
                        .ellipsis, // Menambahkan "..." jika teks kepotong
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      Icon(Icons.access_time_rounded,
                          color: Colors.white, size: 12), // Warna putih pekat
                      SizedBox(width: 4),
                      Text(
                        "10-15m",
                        style: TextStyle(
                            color: Colors.white, // Warna putih pekat
                            fontWeight: FontWeight.w600, // Teks lebih tebal
                            fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.local_fire_department_rounded,
                          color: Colors.white, size: 12), // Warna putih pekat
                      SizedBox(width: 4),
                      Text(
                        "210 Kal",
                        style: TextStyle(
                            color: Colors.white, // Warna putih pekat
                            fontWeight: FontWeight.w600, // Teks lebih tebal
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
              child: Image.asset(imagePath, width: 75),
            )
          ],
        ),
      ),
    );
  }

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

  Widget _buildTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
        ],
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
