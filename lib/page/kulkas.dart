import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';

import 'tambahkan_bahan.dart';

class KulkasPage extends StatefulWidget {
  const KulkasPage({super.key});

  @override
  State<KulkasPage> createState() => _KulkasPageState();
}

class _KulkasPageState extends State<KulkasPage> {
  List<Map<String, dynamic>> _fridgeItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  String _searchQuery = "";
  int _maxStock = 500;
  String _sortOption = "Terbanyak";
  String _expiredFilterOption = "Semua";
  bool _loading = true;

  final List<Color> _themeColors = [
    const Color(0xFF4CAF50),
    const Color(0xFF1B5E20),
  ];

  @override
  void initState() {
    super.initState();
    _loadFridge();
  }

  Future<void> _loadFridge() async {
    setState(() => _loading = true);
    final res = await ApiService.get('/api/fridge');
    if (!mounted) return;
    List<Map<String, dynamic>> list = [];
    if (res.success && res.data != null) {
      final data = res.data;
      if (data is List) {
        for (final e in data) {
          final item = Map<String, dynamic>.from(e as Map);
          DateTime exp = DateTime.now().add(const Duration(days: 7));
          try {
            final ed = item['expired_date']?.toString();
            if (ed != null && ed.isNotEmpty) exp = DateTime.parse(ed);
          } catch (_) {}
          list.add({
            'id': item['_id']?.toString(),
            'name': item['ingredient_name'] ?? item['name'] ?? 'Bahan',
            'qty': item['quantity'] ?? item['qty'] ?? 0,
            'expiredDate': exp,
            'unit': item['unit'],
          });
        }
      }
    }
    setState(() {
      _fridgeItems = list;
      _loading = false;
    });
    _applyFilters();
  }

  // Menghitung sisa hari
  int _getDaysDiff(DateTime expiredDate) {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final exp = DateTime(expiredDate.year, expiredDate.month, expiredDate.day);
    return exp.difference(today).inDays;
  }

  // Teks Tanggal Kadaluarsa
  String _getExpiredText(int diffDays) {
    if (diffDays < 0) return "Sudah Kadaluarsa";
    if (diffDays == 0) return "Hari ini";
    if (diffDays == 1) return "Besok";
    return "$diffDays Hari lagi";
  }

  // Warna Teks Kadaluarsa
  Color _getExpiredColor(int diffDays) {
    if (diffDays < 0) return Colors.red;
    if (diffDays <= 3)
      return Colors.orange.shade800; // Peringatan jika < 3 hari
    return Colors.green;
  }

  void _applyFilters() {
    setState(() {
      _filteredItems = _fridgeItems.where((item) {
        final matchSearch = item['name']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
        final q = item['qty'] is int
            ? item['qty'] as int
            : int.tryParse(item['qty'].toString()) ?? 0;
        final matchStock = q <= _maxStock;
        final exp = item['expiredDate'];
        final diffDays = exp is DateTime ? _getDaysDiff(exp) : 0;
        bool matchExpired = true;
        if (_expiredFilterOption == "Kadaluarsa") {
          matchExpired = diffDays < 0;
        } else if (_expiredFilterOption == "< 3 Hari") {
          matchExpired = diffDays >= 0 && diffDays <= 3;
        } else if (_expiredFilterOption == "< 7 Hari") {
          matchExpired = diffDays >= 0 && diffDays <= 7;
        }
        return matchSearch && matchStock && matchExpired;
      }).toList();

      if (_sortOption == "Terbanyak") {
        _filteredItems.sort((a, b) {
          final qa = a['qty'] is int
              ? a['qty'] as int
              : int.tryParse(a['qty'].toString()) ?? 0;
          final qb = b['qty'] is int
              ? b['qty'] as int
              : int.tryParse(b['qty'].toString()) ?? 0;
          return qb.compareTo(qa);
        });
      } else {
        _filteredItems.sort((a, b) {
          final qa = a['qty'] is int
              ? a['qty'] as int
              : int.tryParse(a['qty'].toString()) ?? 0;
          final qb = b['qty'] is int
              ? b['qty'] as int
              : int.tryParse(b['qty'].toString()) ?? 0;
          return qa.compareTo(qb);
        });
      }
    });
  }

  // Pop Up Notifikasi Cantik (Auto-close)
  void _showSuccessPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.of(context).pop();
        });
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 60),
                const SizedBox(height: 15),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(dynamic id, String itemName) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Colors.redAccent, size: 40),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Hapus Bahan?",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 10),
                Text(
                  "Yakin ingin menghapus '$itemName' dari kulkasmu?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Batal",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteItem(id);
                      },
                      child: const Text(
                        "Ya, Hapus",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Fungsi untuk memunculkan Pop Up Filter (Diperbarui dengan Filter Expired)
  void _showFilterMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Filter Dismiss",
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 150, right: 20),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280, // Sedikit dilebarkan agar chip filter muat
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
                child: StatefulBuilder(
                  builder: (context, setPopupState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Urutkan & Filter",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(),

                        // --- SORTING STOK ---
                        const Text("Urutkan Berdasarkan",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setPopupState(
                                    () => _sortOption = "Terbanyak"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _sortOption == "Terbanyak"
                                        ? _themeColors[0]
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Terbanyak",
                                    style: TextStyle(
                                      color: _sortOption == "Terbanyak"
                                          ? Colors.white
                                          : Colors.black54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setPopupState(
                                    () => _sortOption = "Terdikit"),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _sortOption == "Terdikit"
                                        ? _themeColors[0]
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    "Terdikit",
                                    style: TextStyle(
                                      color: _sortOption == "Terdikit"
                                          ? Colors.white
                                          : Colors.black54,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // --- FILTER KADALUARSA (BARU) ---
                        const Text("Filter Kadaluarsa",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            "Semua",
                            "Kadaluarsa",
                            "< 3 Hari",
                            "< 7 Hari"
                          ].map((opt) {
                            final isSelected = _expiredFilterOption == opt;
                            return ChoiceChip(
                              label: Text(opt,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                              selected: isSelected,
                              selectedColor: _themeColors[0],
                              backgroundColor: Colors.grey.shade100,
                              showCheckmark: false,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              onSelected: (val) {
                                setPopupState(() => _expiredFilterOption = opt);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // --- FILTER MAKSIMAL STOK ---
                        const Text("Maksimal Stok",
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.redAccent),
                              onPressed: () => setPopupState(() =>
                                  _maxStock = (_maxStock - 10).clamp(5, 1000)),
                            ),
                            Text("$_maxStock",
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => setPopupState(() =>
                                  _maxStock = (_maxStock + 10).clamp(5, 1000)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // TOMBOL TERAPKAN
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E1E1E),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              _applyFilters();
                              Navigator.pop(context);
                            },
                            child: const Text("Terapkan",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
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

  // Bottom Modal Sheet HANYA untuk Edit
  void _showEditForm(dynamic id) {
    final existingItem =
        _fridgeItems.firstWhere((element) => element['id'] == id);
    _nameController.text = existingItem['name'].toString();
    _qtyController.text = existingItem['qty'].toString();

    showModalBottomSheet(
      context: context,
      elevation: 5,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          top: 25,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 25,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Bahan Kulkas',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Nama Bahan',
                labelStyle: const TextStyle(color: Colors.black54),
                prefixIcon:
                    const Icon(Icons.restaurant_menu, color: Color(0xFF4CAF50)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _qtyController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                labelText: 'Jumlah',
                labelStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.format_list_numbered,
                    color: Color(0xFF4CAF50)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF4CAF50), width: 2),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isEmpty || _qtyController.text.isEmpty)
                  return;
                final qty = int.tryParse(_qtyController.text) ?? 1;
                final exp = existingItem['expiredDate'];
                final res = await ApiService.put(
                  '/api/fridge/$id',
                  body: {
                    'quantity': qty,
                    'unit': existingItem['unit'] ?? 'pcs',
                    if (exp is DateTime) 'expired_date': exp.toIso8601String(),
                  },
                );
                _nameController.clear();
                _qtyController.clear();
                if (!mounted) return;
                Navigator.of(context).pop();
                if (res.success) {
                  await _loadFridge();
                  _showSuccessPopup('Bahan berhasil diperbarui!');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(res.message ?? 'Gagal memperbarui')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(dynamic id) async {
    final res = await ApiService.delete('/api/fridge/$id');
    if (!mounted) return;
    if (res.success) {
      await _loadFridge();
      _showSuccessPopup('Bahan berhasil dihapus!');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? 'Gagal menghapus')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TambahkanBahanPage()),
          );
          _loadFridge();
        },
        backgroundColor: _themeColors[0],
        child: const Icon(Icons.add),
      ),
      body: CustomScrollView(
        slivers: [
          // --- CUSTOM HEADER ANIMATION (DIUBAH DARI SLIVERAPPBAR) ---
          SliverPersistentHeader(
            pinned: true,
            delegate: _KulkasHeaderDelegate(
              safeArea: safeAreaTop,
              themeColors: _themeColors,
            ),
          ),

          // --- SEARCH & FILTER BAR ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                        style: const TextStyle(color: Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Cari bahan di kulkas...",
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 14),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: _themeColors[0]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _showFilterMenu(context),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _themeColors[1],
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: _themeColors[1].withOpacity(0.3),
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

          // --- LIST BAHAN KULKAS ---
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
                : _filteredItems.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Text(
                              "Bahan tidak ditemukan 😥\nCoba ubah filter atau tambahkan bahan.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 16),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = _filteredItems[index];
                            return _buildFridgeListItem(item);
                          },
                          childCount: _filteredItems.length,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // Desain Card List
  Widget _buildFridgeListItem(Map<String, dynamic> item) {
    // Hitung status kadaluarsa
    final diffDays = _getDaysDiff(item['expiredDate']);
    final isExpired = diffDays < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.shade50
            : Colors.white, // Berubah merah jika expired
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isExpired ? Colors.red.shade100 : Colors.grey.shade200),
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
          // Icon Kiri
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: isExpired
                  ? Colors.red.shade100
                  : _themeColors[0].withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.kitchen_rounded,
                color: isExpired ? Colors.red : _themeColors[1], size: 30),
          ),
          const SizedBox(width: 16),
          // Info Bahan Tengah
          // Info Bahan Tengah
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama Bahan
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),

                // 1. Info Stok (Baris Pertama)
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(
                      "Stok: ${item['qty']}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),

                // Jarak vertikal antara Stok dan Kadaluarsa
                const SizedBox(height: 4),

                // 2. Info Kadaluarsa (Baris Kedua)
                Row(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 14, color: _getExpiredColor(diffDays)),
                    const SizedBox(width: 4),
                    Text(
                      _getExpiredText(diffDays),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getExpiredColor(diffDays),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tombol Aksi Kanan (Edit & Delete)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _showEditForm(item['id']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300)),
                  child: const Icon(Icons.edit_note_rounded,
                      size: 20, color: Colors.black87),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(item['id'], item['name']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DELEGATE CUSTOM HEADER UNTUK ANIMASI SCROLL PINDAH KE KANAN TOMBOL BACK
// ============================================================================
class _KulkasHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double safeArea;
  final List<Color> themeColors;

  _KulkasHeaderDelegate({required this.safeArea, required this.themeColors});

  @override
  // Memberikan space yang cukup untuk tombol back, judul, & deskripsi di mode collapsed
  double get minExtent => safeArea + 70.0;

  @override
  // DIUBAH: Height awal dikurangi agar header tidak terlalu memakan tempat (sebelumnya 220.0)
  double get maxExtent => 170.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Persentase scroll (0.0 = full expand bawah, 1.0 = full collapsed atas)
    double percent = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: themeColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Icon Background (Menghilang saat scroll naik)
          Positioned(
            right: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.15 * (1 - percent),
              child: const Icon(
                Icons.kitchen_rounded,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),

          // 2. Tombol Back Custom (Bulat semi-transparan, Fix Posisi)
          Positioned(
            top: safeArea + 12, // Ini patokan posisi tombol back
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.2), // Background bulat transparan
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

          // 3. Judul & Deskripsi Bergerak (Dari Bawah-Kiri ke Samping Kanan Tombol Back)
          Positioned(
            // Bergerak dari kiri (16) ke kanan tombol back (sekitar 60)
            left: Tween<double>(begin: 16.0, end: 60.0).transform(percent),

            // DIUBAH: Nilai "begin" dikurangi agar judul naik lebih dekat ke tombol Back
            // Sebelumnya (maxExtent - 85.0), sekarang diset fix safeArea + 65.0
            top: Tween<double>(begin: safeArea + 65.0, end: safeArea + 10.0)
                .transform(percent),

            right: 16, // Membatasi lebar agar text tidak tembus layar kanan
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Judul
                Text(
                  "Isi Kulkasmu",
                  style: TextStyle(
                    // Ukuran mengecil perlahan
                    fontSize: Tween<double>(begin: 24.0, end: 18.0)
                        .transform(percent),
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                    height:
                        Tween<double>(begin: 6.0, end: 2.0).transform(percent)),
                // Deskripsi (Mengecil tapi TIDAK hilang / opacity tetap)
                Text(
                  "Cek dan kelola persediaan bahan masakan yang ada di dalam kulkasmu dengan mudah.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    // Ukuran mengecil agar muat di atas saat collapsed
                    fontSize: Tween<double>(begin: 12.0, end: 10.0)
                        .transform(percent),
                    // Line height (jarak antar baris) disesuaikan saat mengecil
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _KulkasHeaderDelegate oldDelegate) {
    return maxExtent != oldDelegate.maxExtent ||
        minExtent != oldDelegate.minExtent ||
        safeArea != oldDelegate.safeArea;
  }
}
