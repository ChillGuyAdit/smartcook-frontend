import 'package:flutter/material.dart';
import 'package:smartcook/service/api_service.dart';
import 'package:smartcook/service/offline_cache_service.dart';
import 'package:smartcook/service/offline_manager.dart';

import '../core/theme/app_theme_colors.dart';
import '../core/theme/shadows.dart';
import 'tambahkan_bahan.dart';
import '../core/l10n/strings.dart';

class KulkasPage extends StatefulWidget {
  const KulkasPage({super.key, this.loader});

  /// Test seam: where the fridge list comes from. Defaults to the API.
  final Future<ApiResponse> Function()? loader;

  @override
  State<KulkasPage> createState() => _KulkasPageState();
}

class _KulkasPageState extends State<KulkasPage> {
  List<Map<String, dynamic>> _fridgeItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController();
  String _searchQuery = "";
  // Upper bound of the "maximum stock" filter. Starts at "no limit": a fixed
  // default (it used to be 500) silently hid every item with more in stock,
  // e.g. 1000 g of rice.
  static const int _noLimit = 1 << 30;
  int _maxStock = _noLimit;
  bool _loadFailed = false;
  String _sortOption = "Terbanyak";
  String _expiredFilterOption = "Semua";
  bool _loading = true;

  final List<Color> _themeColors = [
    const Color(0xFF4CAF50),
    const Color(0xFF1B5E20),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFridge();
  }

  Future<void> _loadFridge() async {
    setState(() => _loading = true);
    final res = await (widget.loader ?? () => ApiService.get('/api/fridge'))();
    if (!mounted) return;

    // A failed request must not look like an empty fridge: keep what was on
    // screen and say that loading failed.
    if (!res.success) {
      setState(() {
        _loadFailed = true;
        _loading = false;
      });
      _applyFilters();
      return;
    }

    List<Map<String, dynamic>> list = [];
    final data = res.data;
    if (data is List) {
      for (final e in data) {
        if (e is! Map) continue;
        final item = Map<String, dynamic>.from(e);
        // No expiry date means "not set", not "a week from now".
        DateTime? exp;
        try {
          final ed = item['expired_date']?.toString();
          if (ed != null && ed.isNotEmpty) exp = DateTime.parse(ed).toLocal();
        } catch (_) {}
        list.add({
          'id': item['_id']?.toString(),
          'name': item['ingredient_name'] ??
              item['name'] ??
              currentStrings.ingredientWord,
          'qty': item['quantity'] ?? item['qty'] ?? 0,
          'expiredDate': exp,
          'unit': item['unit'],
        });
      }
    }

    setState(() {
      _fridgeItems = list;
      _loadFailed = false;
      _loading = false;
    });
    _applyFilters();
  }

  /// Quantity as a number; the server may send an int, a double or a string.
  static num _qtyOf(Object? v) {
    if (v is num) return v;
    return num.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  /// "2" instead of "2.0"; "0.5" stays "0.5".
  static String _qtyText(Object? v) {
    final n = _qtyOf(v);
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  // Menghitung sisa hari
  int _getDaysDiff(DateTime expiredDate) {
    final today =
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final exp = DateTime(expiredDate.year, expiredDate.month, expiredDate.day);
    return exp.difference(today).inDays;
  }

  /// Chip text for an expiry-filter option. The option string itself is the
  /// logic key (compared in the filter), so only its label is translated.
  String _filterLabel(String opt) => switch (opt) {
        'Semua' => context.s.allLabel,
        'Kadaluarsa' => context.s.expiredLabel,
        '< 3 Hari' => context.s.lessThanDays(3),
        '< 7 Hari' => context.s.lessThanDays(7),
        _ => opt,
      };

  // Teks Tanggal Kadaluarsa
  String _getExpiredText(int? diffDays) {
    if (diffDays == null) return context.s.noExpiryDate;
    if (diffDays < 0) return context.s.expiredLabel;
    if (diffDays == 0) return context.s.todayLabel;
    if (diffDays == 1) return context.s.tomorrowLabel;
    return context.s.daysLeft(diffDays);
  }

  // Warna Teks Kadaluarsa
  Color _getExpiredColor(int? diffDays) {
    if (diffDays == null) return context.colors.textSecondary;
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
        final matchStock = _qtyOf(item['qty']) <= _maxStock;
        final exp = item['expiredDate'];
        final int? diffDays = exp is DateTime ? _getDaysDiff(exp) : null;
        bool matchExpired = true;
        if (_expiredFilterOption != "Semua") {
          // Items without an expiry date can never match an expiry filter.
          if (diffDays == null) {
            matchExpired = false;
          } else if (_expiredFilterOption == "Kadaluarsa") {
            matchExpired = diffDays < 0;
          } else if (_expiredFilterOption == "< 3 Hari") {
            matchExpired = diffDays >= 0 && diffDays <= 3;
          } else if (_expiredFilterOption == "< 7 Hari") {
            matchExpired = diffDays >= 0 && diffDays <= 7;
          }
        }
        return matchSearch && matchStock && matchExpired;
      }).toList();

      _filteredItems.sort((a, b) {
        final c = _qtyOf(a['qty']).compareTo(_qtyOf(b['qty']));
        return _sortOption == "Terbanyak" ? -c : c;
      });
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
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: context.floatShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 60),
                const SizedBox(height: 15),
                Text(
                  message,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary),
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
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: context.floatShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red.withValues(alpha: 0.18)
                        : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: Colors.redAccent, size: 40),
                ),
                const SizedBox(height: 15),
                Text(
                  context.s.deleteIngredientTitle,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  context.s.deleteIngredientBody(itemName),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: context.colors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        context.s.cancel,
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.bold),
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
                      child: Text(
                        context.s.yesDelete,
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
      barrierLabel: context.s.filterDismiss,
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
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: context.floatShadow,
                ),
                child: StatefulBuilder(
                  builder: (context, setPopupState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.s.sortAndFilter,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: context.colors.textPrimary)),
                        const Divider(),

                        // --- SORTING STOK ---
                        Text(context.s.sortBy,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary)),
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
                                        : context.colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    context.s.mostStock,
                                    style: TextStyle(
                                      color: _sortOption == "Terbanyak"
                                          ? Colors.white
                                          : context.colors.textSecondary,
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
                                        : context.colors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    context.s.leastStock,
                                    style: TextStyle(
                                      color: _sortOption == "Terdikit"
                                          ? Colors.white
                                          : context.colors.textSecondary,
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
                        Text(context.s.expiryFilter,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary)),
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
                              label: Text(_filterLabel(opt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? Colors.white
                                        : context.colors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                              selected: isSelected,
                              selectedColor: _themeColors[0],
                              backgroundColor: context.colors.surfaceVariant,
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
                        Text(context.s.maxStockLabel,
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textSecondary)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: Colors.redAccent),
                              onPressed: () => setPopupState(() => _maxStock =
                                  _maxStock >= _noLimit
                                      ? 1000
                                      : (_maxStock - 10).clamp(5, 1000)),
                            ),
                            Text(_maxStock >= _noLimit ? "∞" : "$_maxStock",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: context.colors.textPrimary)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: Colors.green),
                              onPressed: () => setPopupState(() => _maxStock =
                                  _maxStock >= _noLimit || _maxStock + 10 > 1000
                                      ? _noLimit
                                      : _maxStock + 10),
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
                            child: Text(context.s.apply,
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
    final found = _fridgeItems.where((element) => element['id'] == id);
    if (found.isEmpty) return;
    final existingItem = found.first;
    _nameController.text = existingItem['name'].toString();
    _qtyController.text = _qtyText(existingItem['qty']);

    showModalBottomSheet(
      context: context,
      elevation: 5,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
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
            Text(
              context.s.editFridgeIngredient,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              // The name is the identity of the item (the server cannot rename
              // it), so it is shown but not editable.
              enabled: false,
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: context.s.ingredientName,
                labelStyle: TextStyle(color: context.colors.textSecondary),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: context.s.quantity,
                labelStyle: TextStyle(color: context.colors.textSecondary),
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
                final typed = num.tryParse(
                    _qtyController.text.trim().replaceAll(',', '.'));
                if (typed == null || typed < 0 || typed > 1000000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.s.invalidQuantity)),
                  );
                  return;
                }
                final qty = typed;
                final exp = existingItem['expiredDate'];
                final res = await ApiService.put(
                  '/api/fridge/$id',
                  body: {
                    'quantity': qty,
                    'unit': existingItem['unit'] ?? 'pcs',
                    // Only a date the user/server really has: never invent one.
                    if (exp is DateTime)
                      'expired_date': exp.toUtc().toIso8601String(),
                  },
                );
                _nameController.clear();
                _qtyController.clear();
                if (!mounted) return;
                Navigator.of(context).pop();
                if (res.success) {
                  await _loadFridge();
                  _showSuccessPopup(currentStrings.ingredientUpdated);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(res.message ?? context.s.updateFailed)),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E1E1E),
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                context.s.saveChanges,
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
    if (OfflineManager.isOffline.value) {
      // Hapus lokal dan antrikan operasi
      setState(() {
        _fridgeItems.removeWhere((e) => e['id'] == id);
        _applyFilters();
      });
      await OfflineCacheService.addPendingOperation(
        method: 'DELETE',
        path: '/api/fridge/$id',
      );
      _showSuccessPopup(currentStrings.ingredientDeletedSync);
      return;
    }
    final res = await ApiService.delete('/api/fridge/$id');
    if (!mounted) return;
    if (res.success) {
      await _loadFridge();
      _showSuccessPopup(currentStrings.ingredientDeleted);
    } else if (OfflineManager.isOffline.value) {
      // Fallback: anggap offline, hapus lokal & antrikan operasi
      if (mounted)
        setState(() {
          _fridgeItems.removeWhere((e) => e['id'] == id);
          _applyFilters();
        });
      await OfflineCacheService.addPendingOperation(
        method: 'DELETE',
        path: '/api/fridge/$id',
      );
      _showSuccessPopup(currentStrings.ingredientDeletedSync);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message ?? context.s.deleteFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.colors.background,
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
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: context.softShadow,
                        border: Border.all(color: context.colors.border),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          _searchQuery = value;
                          _applyFilters();
                        },
                        style: TextStyle(color: context.colors.textPrimary),
                        decoration: InputDecoration(
                          hintText: context.s.searchFridge,
                          hintStyle: TextStyle(
                              color: context.colors.textDisabled, fontSize: 14),
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
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
                            color: _themeColors[1].withValues(alpha: 0.3),
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
                : _loadFailed && _fridgeItems.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 50),
                            child: Column(
                              children: [
                                Text(
                                  context.s.fridgeLoadFailed,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: _loadFridge,
                                  child: Text(context.s.updateRetry),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : _filteredItems.isEmpty
                        ? SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 50),
                                child: Text(
                                  context.s.ingredientsNotFound,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 16),
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
    final exp = item['expiredDate'];
    final int? diffDays = exp is DateTime ? _getDaysDiff(exp) : null;
    final isExpired = diffDays != null && diffDays < 0;
    // The expired tint must work on both themes: the old light pink card made
    // the (light) name text invisible in dark mode.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final expiredBg =
        dark ? Colors.red.withValues(alpha: 0.14) : Colors.red.shade50;
    final expiredBorder =
        dark ? Colors.red.withValues(alpha: 0.45) : Colors.red.shade100;
    final expiredIconBg =
        dark ? Colors.red.withValues(alpha: 0.22) : Colors.red.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExpired
            ? expiredBg
            : context.colors.surface, // Berubah merah jika expired
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isExpired ? expiredBorder : context.colors.border),
        boxShadow: context.softShadow,
      ),
      child: Row(
        children: [
          // Icon Kiri
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: isExpired
                  ? expiredIconBg
                  : _themeColors[0].withValues(alpha: 0.1),
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
                  item['name'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),

                // 1. Info Stok (Baris Pertama)
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 14, color: Colors.blueGrey),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(
                      context.s.stockLabel(
                          '${_qtyText(item['qty'])}${(item['unit'] ?? '').toString().isEmpty ? '' : ' ${item['unit']}'}'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    )),
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
                    Flexible(
                        child: Text(
                      _getExpiredText(diffDays),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getExpiredColor(diffDays),
                      ),
                    )),
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
                      color: context.colors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.colors.border)),
                  child: Icon(Icons.edit_note_rounded,
                      size: 20, color: context.colors.textPrimary),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(item['id'], item['name']),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.red.withValues(alpha: 0.18)
                        : Colors.red.shade50,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  // Background bulat transparan
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
            top: Tween<double>(begin: safeArea + 46.0, end: safeArea + 10.0)
                .transform(percent),

            right: 16, // Membatasi lebar agar text tidak tembus layar kanan
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Judul
                Text(
                  context.s.yourFridge,
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
                  context.s.fridgeIntro,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // Ukuran mengecil agar muat di atas saat collapsed
                    fontSize: Tween<double>(begin: 12.0, end: 10.0)
                        .transform(percent),
                    color: Colors.white.withValues(alpha: 0.85),
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
