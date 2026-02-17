import 'package:flutter/material.dart';
import 'package:smartcook/helper/color.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';

class TambahkanBahanPage extends StatefulWidget {
  const TambahkanBahanPage({super.key});

  @override
  State<TambahkanBahanPage> createState() => _TambahkanBahanPageState();
}

class _TambahkanBahanPageState extends State<TambahkanBahanPage> {
  String selectedCategory = '';
  bool _saving = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> _hiddenIngredientKeys = [];

  // Data dengan field: 'id', 'name', 'count', 'isSelected'
  final Map<String, List<Map<String, dynamic>>> bahanData = {
    'Protein': [
      {
        'title': 'Protein Hewani',
        'color': Color(0xFFFFC107), // Amber
        'items': [
          {
            'id': 'ayam-utuh',
            'name': 'Ayam utuh',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'dada-ayam',
            'name': 'Dada ayam',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'paha-ayam',
            'name': 'Paha ayam',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'sayap-ayam',
            'name': 'Sayap ayam',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'daging-bebek',
            'name': 'Daging bebek',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'daging-sapi',
            'name': 'Daging sapi',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'daging-giling',
            'name': 'Daging giling',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'iga-sapi',
            'name': 'Iga sapi',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'daging-kambing',
            'name': 'Daging kambing',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'daging-domba',
            'name': 'Daging domba',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'telur-ayam',
            'name': 'Telur ayam',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'telur-bebek',
            'name': 'Telur bebek',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'telur-puyuh',
            'name': 'Telur Puyuh',
            'count': 0,
            'isSelected': false
          },
          {'id': 'sosis', 'name': 'Sosis', 'count': 0, 'isSelected': false},
          {'id': 'bakso', 'name': 'Bakso', 'count': 0, 'isSelected': false},
          {'id': 'nugget', 'name': 'Nugget', 'count': 0, 'isSelected': false},
          {'id': 'kornet', 'name': 'Kornet', 'count': 0, 'isSelected': false},
        ]
      },
      {
        'title': 'Protein Seafood',
        'color': Color(0xFF26A69A), // Teal
        'items': [
          {
            'id': 'ikan-lele',
            'name': 'Ikan lele',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'ikan-gurame',
            'name': 'Ikan gurame',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'ikan-patin',
            'name': 'Ikan patin',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'ikan-mas',
            'name': 'Ikan mas',
            'count': 0,
            'isSelected': false
          },
          {'id': 'salmon', 'name': 'Salmon', 'count': 0, 'isSelected': false},
          {'id': 'tongkol', 'name': 'Tongkol', 'count': 0, 'isSelected': false},
          {'id': 'kembung', 'name': 'Kembung', 'count': 0, 'isSelected': false},
          {
            'id': 'tenggiri',
            'name': 'Tenggiri',
            'count': 0,
            'isSelected': false
          },
          {'id': 'tuna', 'name': 'Tuna', 'count': 0, 'isSelected': false},
          {'id': 'kakap', 'name': 'Kakap', 'count': 0, 'isSelected': false},
          {'id': 'teri', 'name': 'Teri', 'count': 0, 'isSelected': false},
          {
            'id': 'ikan-asin',
            'name': 'Ikan asin',
            'count': 0,
            'isSelected': false
          },
          {'id': 'udang', 'name': 'Udang', 'count': 0, 'isSelected': false},
          {
            'id': 'kepiting',
            'name': 'Kepiting',
            'count': 0,
            'isSelected': false
          },
          {'id': 'lobster', 'name': 'Lobster', 'count': 0, 'isSelected': false},
          {
            'id': 'cumi-cumi',
            'name': 'Cumi-cumi',
            'count': 0,
            'isSelected': false
          },
          {'id': 'sotong', 'name': 'Sotong', 'count': 0, 'isSelected': false},
          {'id': 'gurita', 'name': 'Gurita', 'count': 0, 'isSelected': false},
          {'id': 'kerang', 'name': 'Kerang', 'count': 0, 'isSelected': false},
        ]
      },
      {
        'title': 'Protein Nabati',
        'color': Color(0xFF33691E), // Dark Green
        'items': [
          {'id': 'tempe', 'name': 'Tempe', 'count': 0, 'isSelected': false},
          {'id': 'tahu', 'name': 'Tahu', 'count': 0, 'isSelected': false},
          {'id': 'oncom', 'name': 'Oncom', 'count': 0, 'isSelected': false},
          {
            'id': 'kacang-tanah',
            'name': 'Kacang tanah',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'kacang-hijau',
            'name': 'Kacang hijau',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'kacang-merah',
            'name': 'Kacang merah',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'kacang-kedelai',
            'name': 'Kacang kedelai',
            'count': 0,
            'isSelected': false
          },
          {'id': 'edamame', 'name': 'Edamame', 'count': 0, 'isSelected': false},
          {'id': 'jamur', 'name': 'Jamur', 'count': 0, 'isSelected': false},
          {'id': 'wijen', 'name': 'Wijen', 'count': 0, 'isSelected': false},
        ]
      },
    ],
    'Karbo': [
      {
        'title': 'Karbohidrat',
        'color': Colors.brown,
        'items': [
          {'id': 'beras', 'name': 'Beras', 'count': 0, 'isSelected': false},
          {'id': 'kentang', 'name': 'Kentang', 'count': 0, 'isSelected': false},
          {'id': 'ubi', 'name': 'Ubi', 'count': 0, 'isSelected': false},
          {'id': 'jagung', 'name': 'Jagung', 'count': 0, 'isSelected': false},
        ]
      }
    ],
    'Sayur': [
      {
        'title': 'Sayur - Mayur',
        'color': Colors.green,
        'items': [
          {'id': 'bayam', 'name': 'Bayam', 'count': 0, 'isSelected': false},
          {
            'id': 'kangkung',
            'name': 'Kangkung',
            'count': 0,
            'isSelected': false
          },
          {'id': 'wortel', 'name': 'Wortel', 'count': 0, 'isSelected': false},
          {'id': 'brokoli', 'name': 'Brokoli', 'count': 0, 'isSelected': false},
        ]
      }
    ],
    'Bumbu': [
      {
        'title': 'Bumbu Dapur',
        'color': Colors.orange[800],
        'items': [
          {
            'id': 'bawang-merah',
            'name': 'Bawang Merah',
            'count': 0,
            'isSelected': false
          },
          {
            'id': 'bawang-putih',
            'name': 'Bawang Putih',
            'count': 0,
            'isSelected': false
          },
          {'id': 'cabai', 'name': 'Cabai', 'count': 0, 'isSelected': false},
          {'id': 'garam', 'name': 'Garam', 'count': 0, 'isSelected': false},
        ]
      }
    ],
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    _hiddenIngredientKeys =
        await OfflineCacheService.getHiddenIngredientKeys();
    _applyHiddenToBahanData();
    await _loadGlobalIngredients();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadGlobalIngredients() async {
    final cached = await OfflineCacheService.getGlobalIngredients();
    if (cached.isNotEmpty) {
      _mergeGlobalIngredients(cached);
    }
    if (!mounted) {
      return;
    }
    final res = await ApiService.get('/api/ingredients', useAuth: false);
    if (!mounted) return;
    if (!res.success || res.data is! List) {
      return;
    }
    final list = (res.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    _mergeGlobalIngredients(list);
    await OfflineCacheService.saveGlobalIngredients(list);
  }

  void _mergeGlobalIngredients(List<Map<String, dynamic>> list) {
    for (final ing in list) {
      final name = ing['name']?.toString() ?? '';
      final cat = ing['category']?.toString() ?? '';
      if (name.isEmpty || cat.isEmpty) continue;
      final label = _mapBackendToLabel(cat);
      final groups = bahanData[label];
      if (groups == null || groups.isEmpty) continue;
      final items = groups.first['items'] as List<dynamic>? ?? [];
      final lower = name.toLowerCase();
      final key = _buildHiddenKey(name, cat);
      if (_hiddenIngredientKeys.contains(key)) continue;
      final exists = items.any((raw) {
        final m = raw as Map;
        return (m['name']?.toString().toLowerCase() ?? '') == lower;
      });
      if (exists) continue;
      items.add({
        'id': lower.replaceAll(RegExp(r'\s+'), '-'),
        'name': name,
        'count': 0,
        'isSelected': false,
        'isCustom': true,
      });
      groups.first['items'] = items;
    }
  }

  void _applyHiddenToBahanData() {
    if (_hiddenIngredientKeys.isEmpty) return;
    for (final entry in bahanData.entries) {
      final label = entry.key;
      final groups = entry.value;
      for (final group in groups) {
        final items = group['items'] as List<dynamic>? ?? [];
        items.removeWhere((raw) {
          final m = raw as Map;
          final name = m['name']?.toString() ?? '';
          final backend = _mapCategoryToBackend(label);
          final key = _buildHiddenKey(name, backend);
          return _hiddenIngredientKeys.contains(key);
        });
        group['items'] = items;
      }
    }
  }

  String _buildHiddenKey(String name, String backendCategory) {
    return '${name.trim().toLowerCase()}|$backendCategory';
  }

  String _mapBackendToLabel(String backend) {
    switch (backend) {
      case 'protein':
        return 'Protein';
      case 'karbo':
        return 'Karbo';
      case 'sayur':
        return 'Sayur';
      case 'bumbu':
        return 'Bumbu';
      default:
        return backend;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double baseWidth = 430;
    double scale = screenWidth / baseWidth;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tambahkan Bahan',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22 * scale,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20 * scale),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Cari atau ketik nama bahan baru (mis. \"Daun bawang\")',
                        hintStyle: const TextStyle(color: Colors.grey),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addManualIngredient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor().utama,
                      padding: EdgeInsets.symmetric(
                          horizontal: 10 * scale, vertical: 10 * scale),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18, color: Colors.white),
                    label: Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30 * scale),
              Text(
                'Berdasarkan Kategori:',
                style: TextStyle(
                    fontSize: 18 * scale, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 20 * scale),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryItem(
                      'Protein', 'image/protein.png', scale, AppColor().utama),
                  _buildCategoryItem(
                      'Karbo', 'image/karbo.png', scale, Colors.brown),
                  _buildCategoryItem(
                      'Sayur', 'image/sayur.png', scale, Colors.green),
                  _buildCategoryItem(
                      'Bumbu', 'image/bumbu.png', scale, Colors.orange),
                ],
              ),
              SizedBox(height: 30 * scale),
              if (_searchController.text.trim().isNotEmpty &&
                  selectedCategory.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12 * scale),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bahan baru: "${_searchController.text.trim()}" akan disimpan sebagai ${selectedCategory.toLowerCase()}.',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Daftar:',
                style: TextStyle(
                    fontSize: 18 * scale, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 15 * scale),
              if (selectedCategory.isNotEmpty) ..._buildListCards(scale),
              SizedBox(height: 24 * scale),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _simpanSemua,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor().utama,
                    padding: EdgeInsets.symmetric(vertical: 16 * scale),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _saving
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Simpan ke Kulkas',
                          style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
              SizedBox(height: 50 * scale),
            ],
          ),
        ),
      ),
    );
  }

  String _mapCategoryToBackend(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('protein')) return 'protein';
    if (c.contains('karbo')) return 'karbo';
    if (c.contains('sayur')) return 'sayur';
    if (c.contains('bumbu')) return 'bumbu';
    return cat.toLowerCase();
  }

  void _addManualIngredient() {
    final name = _searchController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi nama bahan terlebih dahulu')),
      );
      return;
    }
    if (selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori bahan terlebih dahulu')),
      );
      return;
    }

    final categoryKey = selectedCategory;
    final groups = bahanData[categoryKey];
    if (groups == null || groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori tidak valid')),
      );
      return;
    }
    final items = groups.first['items'] as List<dynamic>? ?? [];
    final lower = name.toLowerCase();
    final alreadyExists = items.any((raw) {
      final m = raw as Map;
      return (m['name']?.toString().toLowerCase() ?? '') == lower;
    });
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bahan sudah ada di daftar kategori ini')),
      );
      return;
    }

    final newItem = {
      'id': lower.replaceAll(RegExp(r'\s+'), '-'),
      'name': name,
      'count': 1,
      'isSelected': true,
      'isCustom': true,
    };

    setState(() {
      items.add(newItem);
      groups.first['items'] = items;
      _searchController.clear();
    });
  }

  Future<void> _simpanSemua() async {
    final toSave = <Map<String, dynamic>>[];
    for (final entry in bahanData.entries) {
      final category = entry.key;
      for (final group in entry.value) {
        final items = group['items'] as List<dynamic>? ?? [];
        for (final i in items) {
          final item = Map<String, dynamic>.from(i as Map);
          if (item['isSelected'] == true) {
            final count = item['count'] is int ? item['count'] as int : int.tryParse(item['count'].toString()) ?? 0;
            if (count > 0) {
              toSave.add({
                'name': item['name'],
                'category': _mapCategoryToBackend(category),
                'quantity': count,
                'unit': 'pcs',
              });
            }
          }
        }
      }
    }

    if (toSave.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Tidak ada bahan yang dikirim ke kulkas. Perubahan daftar tersimpan.')),
      );
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);

    // Jika sudah diketahui offline, langsung antrikan semua operasi dan beri feedback.
    if (OfflineManager.isOffline.value) {
      for (final item in toSave) {
        await OfflineCacheService.addPendingOperation(
          method: 'POST',
          path: '/api/fridge',
          body: {
            'ingredient_name': item['name'],
            'category': item['category'],
            'quantity': item['quantity'],
            'unit': item['unit'],
          },
        );
      }
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${toSave.length} bahan akan disimpan ke kulkas saat online'),
        ),
      );
      Navigator.pop(context);
      return;
    }

    int ok = 0;
    String? lastError;
    for (final item in toSave) {
      final res = await ApiService.post(
        '/api/fridge',
        body: {
          'ingredient_name': item['name'],
          'category': item['category'],
          'quantity': item['quantity'],
          'unit': item['unit'],
        },
        useAuth: true,
      );
      if (res.success) {
        ok++;
      } else if (OfflineManager.isOffline.value) {
        // Fallback: anggap offline, antrikan operasi dan lanjut
        await OfflineCacheService.addPendingOperation(
          method: 'POST',
          path: '/api/fridge',
          body: {
            'ingredient_name': item['name'],
            'category': item['category'],
            'quantity': item['quantity'],
            'unit': item['unit'],
          },
        );
      } else if (lastError == null && res.message != null) {
        lastError = res.message;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == 0 && toSave.isNotEmpty && !OfflineManager.isOffline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            lastError?.isNotEmpty == true
                ? 'Gagal menyimpan: $lastError'
                : 'Gagal menyimpan. Pastikan sudah login.',
          ),
        ),
      );
    } else if (ok > 0 && ok < toSave.length && !OfflineManager.isOffline.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$ok dari ${toSave.length} bahan berhasil disimpan.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${toSave.length} bahan diproses ke kulkas')),
      );
    }
    Navigator.pop(context);
  }

  Widget _buildCategoryItem(
      String label, String imagePath, double scale, Color activeColor) {
    bool isSelected = selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (selectedCategory == label) {
            selectedCategory = '';
          } else {
            selectedCategory = label;
          }
        });
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60 * scale,
                height: 60 * scale,
                child: Image.asset(imagePath,
                    color: isSelected ? activeColor : Colors.grey),
              ),
              if (isSelected)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColor().utama,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(Icons.check,
                        size: 10 * scale, color: Colors.white),
                  ),
                ),
            ],
          ),
          SizedBox(height: 8 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 14 * scale,
              color: isSelected ? activeColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildListCards(double scale) {
    List<Map<String, dynamic>> subCategories = bahanData[selectedCategory]!;
    List<Widget> cards = [];

    for (var subCat in subCategories) {
      cards.add(_buildSingleCard(
        scale: scale,
        title: subCat['title'],
        headerColor: subCat['color'],
        items: subCat['items'],
      ));
      cards.add(SizedBox(height: 20 * scale));
    }
    return cards;
  }

  Widget _buildSingleCard({
    required double scale,
    required String title,
    required Color headerColor,
    required List<Map<String, dynamic>> items,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.all(15 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20 * scale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.push_pin, color: Colors.white),
            ],
          ),
          SizedBox(height: 15 * scale),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nama', style: TextStyle(color: Colors.white70)),
                Text('Total', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          SizedBox(height: 5 * scale),
          ListView.builder(
            physics: NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 4 * scale),
                child: Row(
                  children: [
                    // Area Klik Luas (Radio + Nama)
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            items[index]['isSelected'] =
                                !items[index]['isSelected'];
                          });
                        },
                        child: Row(
                          children: [
                            Icon(
                              items[index]['isSelected']
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: Colors.white,
                              size: 20 * scale,
                            ),
                            SizedBox(width: 10 * scale),
                            Expanded(
                              // Memastikan teks tidak overflow dan area klik penuh
                              child: Text(
                                '${index + 1}. ${items[index]['name']}',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16 * scale),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(width: 10 * scale),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showQuantityDialog(context, items[index]);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale, vertical: 4 * scale),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white70),
                            ),
                            child: Text(
                              '${items[index]['count']} item',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14 * scale,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () async {
                            final name = items[index]['name']?.toString() ?? '';
                            final backendCategory = _mapCategoryToBackend(
                                selectedCategory);
                            final key = _buildHiddenKey(
                                name, backendCategory);
                            await OfflineCacheService
                                .addHiddenIngredientKey(key);
                            setState(() {
                              _hiddenIngredientKeys.add(key);
                              items.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: 20 * scale),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _simpanSemua(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: headerColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: EdgeInsets.symmetric(vertical: 12 * scale),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                    fontSize: 18 * scale, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fungsi untuk menampilkan Pop-up Dialog Angka
  void _showQuantityDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Menggunakan StatefulBuilder agar dialog bisa refresh statenya sendiri
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              title: Text(
                'Jumlah ${item['name']}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (item['count'] > 0) {
                        setStateDialog(() {
                          item['count']--;
                        });
                        // Update state parent page juga
                        this.setState(() {});
                      }
                    },
                    icon:
                        Icon(Icons.remove_circle, color: Colors.red, size: 32),
                  ),
                  SizedBox(width: 20),
                  Text(
                    '${item['count']}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      setStateDialog(() {
                        item['count']++;
                      });
                      this.setState(() {});
                    },
                    icon: Icon(Icons.add_circle, color: Colors.green, size: 32),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Selesai',
                    style: TextStyle(color: AppColor().utama, fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
