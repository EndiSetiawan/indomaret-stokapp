import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

const _blueDark = Color(0xFF00335E);
const _blue = Color(0xFF004B87);
const _yellow = Color(0xFFFFD400);
const _red = Color(0xFFE53935);
const _green = Color(0xFF20B66B);
const _surface = Color(0xFFF4F7FA);

const _logoAsset = 'assets/indomaret_logo.png';
const _storageKey = 'indomaret_snack_db';
const _themeKey = 'indomaret_stokapp_dark';

enum StockStatus { ada, refill, kosong }

extension StockStatusX on StockStatus {
  String get value {
    switch (this) {
      case StockStatus.ada:
        return 'ada';
      case StockStatus.refill:
        return 'refill';
      case StockStatus.kosong:
        return 'kosong';
    }
  }

  String get label {
    switch (this) {
      case StockStatus.ada:
        return '🟢 ADA';
      case StockStatus.refill:
        return '🟡 REFILL';
      case StockStatus.kosong:
        return '🔴 KOSONG';
    }
  }

  Color get color {
    switch (this) {
      case StockStatus.ada:
        return _green;
      case StockStatus.refill:
        return Color(0xFFFFB300);
      case StockStatus.kosong:
        return _red;
    }
  }

  static StockStatus fromValue(String? value) {
    switch (value) {
      case 'refill':
        return StockStatus.refill;
      case 'kosong':
        return StockStatus.kosong;
      default:
        return StockStatus.ada;
    }
  }
}

class SnackItem {
  final String id;
  String name;
  String rack;
  String warehouse;
  String? imageBase64;
  StockStatus status;
  final bool master;

  SnackItem({
    required this.id,
    required this.name,
    required this.rack,
    required this.warehouse,
    required this.status,
    this.imageBase64,
    this.master = false,
  });

  SnackItem copyWith({
    String? name,
    String? rack,
    String? warehouse,
    String? imageBase64,
    StockStatus? status,
  }) {
    return SnackItem(
      id: id,
      name: name ?? this.name,
      rack: rack ?? this.rack,
      warehouse: warehouse ?? this.warehouse,
      status: status ?? this.status,
      imageBase64: imageBase64 ?? this.imageBase64,
      master: master,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rack': rack,
        'warehouse': warehouse,
        'imageBase64': imageBase64,
        'status': status.value,
        'master': master,
      };

  factory SnackItem.fromJson(Map<String, dynamic> json) => SnackItem(
        id: '${json['id'] ?? DateTime.now().microsecondsSinceEpoch}',
        name: '${json['name'] ?? ''}',
        rack: '${json['rack'] ?? '-'}',
        warehouse: '${json['warehouse'] ?? '-'}',
        imageBase64: json['imageBase64'] as String?,
        status: StockStatusX.fromValue(json['status'] as String?),
        master: json['master'] == true,
      );
}

List<SnackItem> defaultSnackCatalog() {
  const rows = [
    ['Chitato Sapi Panggang 68g', 'R01-A03', 'G01-A01'],
    ['Chitato Ayam Bumbu 68g', 'R01-A04', 'G01-A01'],
    ['Chitato Lite Seaweed 68g', 'R01-A05', 'G01-A02'],
    ['Oreo Vanilla 119.6g', 'R02-B01', 'G01-B01'],
    ['Oreo Chocolate 119.6g', 'R02-B02', 'G01-B01'],
    ['Qtela Balado 185g', 'R03-C01', 'G02-A01'],
    ['Qtela Tempe Original 55g', 'R03-C02', 'G02-A01'],
    ['Kusuka Original 60g', 'R04-A01', 'G02-A02'],
    ['Kusuka Balado 60g', 'R04-A02', 'G02-A02'],
    ['Piattos Cheese 85g', 'R05-B01', 'G03-A01'],
    ['Piattos Sambal Matah 75g', 'R05-B02', 'G03-A01'],
    ['SilverQueen Chunky Bar 30g', 'R06-C01', 'G03-B01'],
    ['SilverQueen Almond 30g', 'R06-C02', 'G03-B01'],
    ['Tango Wafer Vanilla 176g', 'R07-A01', 'G04-A01'],
    ['Tango Wafer Chocolate 176g', 'R07-A02', 'G04-A01'],
    ['Choki-Choki 9g', 'R08-B01', 'G04-B01'],
    ['Good Time Choco Chip 72g', 'R08-B02', 'G04-B01'],
    ['Pringles Original 107g', 'R09-C01', 'G05-A01'],
    ['Pringles Sour Cream 107g', 'R09-C02', 'G05-A01'],
    ['Lays Classic 68g', 'R10-A01', 'G05-B01'],
    ['Lays Seaweed 68g', 'R10-A02', 'G05-B01'],
    ['Cheetos Cheese 60g', 'R10-B01', 'G05-B02'],
    ['Momogi Jagung Bakar 20g', 'R11-C01', 'G06-A01'],
    ['Pilus Garuda 95g', 'R12-A01', 'G06-A02'],
    ['Roma Malkist Abon 135g', 'R12-B01', 'G06-B01'],
  ];

  return List.generate(
    rows.length,
    (i) => SnackItem(
      id: 'master-${i + 1}',
      name: rows[i][0],
      rack: rows[i][1],
      warehouse: rows[i][2],
      status: StockStatus.ada,
      master: true,
    ),
  );
}

class StokApp extends StatefulWidget {
  const StokApp({super.key});

  @override
  State<StokApp> createState() => _StokAppState();
}

class _StokAppState extends State<StokApp> {
  final _searchController = TextEditingController();
  final _prefs = SharedPreferences.getInstance();
  final _speech = stt.SpeechToText();

  List<SnackItem> _items = [];
  bool _dark = false;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _voiceMode = false;
  int _navIndex = 0;
  String _filter = 'all';
  String _statusMessage = 'Siap. Cari snack berdasarkan nama, rasa, atau ukuran.';
  Timer? _messageTimer;

  static const _popularBrands = [
    'chitato',
    'oreo',
    'qtela',
    'kusuka',
    'piattos',
    'silverqueen',
    'tango',
    'choki-choki',
    'good time',
    'pringles',
    'lays',
    'cheetos',
    'momogi',
    'garuda',
    'roma',
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await _prefs;
    _dark = prefs.getBool(_themeKey) ?? false;
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      _items = defaultSnackCatalog();
      await _save();
    } else {
      try {
        final decoded = jsonDecode(raw) as List;
        _items = decoded
            .map((e) => SnackItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _items = defaultSnackCatalog();
      }
    }

    if (mounted) setState(() {});
    await _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
          _showMessage('Pengenalan suara berhenti. Coba tekan mic lagi.');
        },
      );
      if (mounted) setState(() => _speechAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _save() async {
    final prefs = await _prefs;
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.map((e) => e.toJson()).toList()),
    );
  }

  void _showMessage(String message) {
    _messageTimer?.cancel();
    if (!mounted) return;
    setState(() => _statusMessage = message);
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _statusMessage =
            'Siap. Cari snack berdasarkan nama, rasa, atau ukuran.');
      }
    });
  }

  void _feedback({bool vibration = true}) {
    if (vibration) HapticFeedback.selectionClick();
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _listen() async {
    _feedback();
    if (!_speechAvailable) {
      await _initSpeech();
    }
    if (!_speechAvailable) {
      _showMessage('Speech recognition tidak tersedia di perangkat ini.');
      return;
    }

    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    setState(() {
      _listening = true;
      _voiceMode = true;
    });

    await _speech.listen(
      localeId: 'id_ID',
      listenMode: stt.ListenMode.search,
      partialResults: true,
      cancelOnError: true,
      pauseFor: const Duration(seconds: 3),
      listenFor: const Duration(seconds: 12),
      onResult: (result) {
        if (!result.finalResult) return;
        final spoken = _normalize(result.recognizedWords);
        if (spoken.isEmpty) return;
        _appendVoiceQuery(spoken);
      },
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[.!?;]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _splitVoiceQueries(String phrase) {
    var text = _normalize(phrase);
    text = text.replaceAll(RegExp(r'\b(dan|lalu|kemudian)\b'), ',');
    text = text.replaceAll(RegExp(r'\s*,\s*'), ',');
    final lower = text.toLowerCase();

    final hits = <int>[];
    for (final brand in _popularBrands) {
      var start = 0;
      while (true) {
        final index = lower.indexOf(brand, start);
        if (index < 0) break;
        hits.add(index);
        start = index + brand.length;
      }
    }

    if (hits.length > 1 && !text.contains(',')) {
      hits.sort();
      final chunks = <String>[];
      for (var i = 0; i < hits.length; i++) {
        final start = hits[i];
        final end = i + 1 < hits.length ? hits[i + 1] : text.length;
        final chunk = text.substring(start, end).trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
      }
      return chunks;
    }

    return text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void _appendVoiceQuery(String phrase) {
    final incoming = _splitVoiceQueries(phrase);
    final existing = _searchController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (final query in incoming) {
      if (!existing.any((e) => _normalize(e) == _normalize(query))) {
        existing.add(query);
      }
    }

    final result = existing.join(', ');
    _searchController.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
    _showMessage('Ditumpuk: $result');
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _voiceMode = false);
  }

  List<SnackItem> get _filtered {
    Iterable<SnackItem> result = _items;

    if (_filter == 'restock') {
      result = result.where((e) => e.status == StockStatus.refill);
    } else if (_filter == 'empty') {
      result = result.where((e) => e.status == StockStatus.kosong);
    }

    final raw = _searchController.text.trim();
    if (raw.isNotEmpty) {
      if (_voiceMode) {
        final queries = raw
            .split(',')
            .map(_normalize)
            .where((e) => e.isNotEmpty)
            .toList();

        result = result.where((item) {
          final name = _normalize(item.name);
          return queries.any((q) => name.contains(q));
        });
      } else {
        final query = _normalize(raw);
        result = result.where((item) {
          final hay = _normalize(
              '${item.name} ${item.rack} ${item.warehouse}');
          return hay.contains(query);
        });
      }
    }

    return result.toList();
  }

  void _setStatus(SnackItem item, StockStatus status) {
    _feedback();
    final index = _items.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    setState(() => _items[index] = item.copyWith(status: status));
    _save();
  }

  Future<void> _deleteItem(SnackItem item) async {
    _feedback();
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _save();
    _showMessage('${item.name} dihapus dari database lokal.');
  }

  Future<void> _openEditor([SnackItem? item]) async {
    final saved = await showModalBottomSheet<SnackItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SnackEditorSheet(item: item),
    );

    if (saved == null) return;

    final index = _items.indexWhere((e) => e.id == saved.id);
    setState(() {
      if (index >= 0) {
        _items[index] = saved;
      } else {
        _items.insert(0, saved);
      }
    });
    await _save();
    _showMessage(index >= 0 ? 'Produk diperbarui.' : 'Produk ditambahkan.');
  }

  Future<void> _exportBackup() async {
    _feedback();
    final payload = {
      'app': 'Indomaret StokApp',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'items': _items.map((e) => e.toJson()).toList(),
    };

    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'application/json',
              name: 'indomaret_stokapp_backup.json',
            ),
          ],
          subject: 'Backup Indomaret StokApp',
        ),
      );
      _showMessage('Backup JSON siap dibagikan/disimpan.');
    } catch (_) {
      _showMessage('Gagal membuka menu simpan/share backup.');
    }
  }

  Future<void> _importBackup() async {
    _feedback();
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) return;

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        _showMessage('File JSON tidak dapat dibaca.');
        return;
      }

      final decoded = jsonDecode(utf8.decode(bytes));
      final rawItems = decoded is Map ? decoded['items'] : decoded;

      if (rawItems is! List) {
        throw const FormatException('Format backup tidak valid.');
      }

      final imported = rawItems
          .map((e) => SnackItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (imported.isEmpty) {
        _showMessage('Backup kosong. Data tidak diubah.');
        return;
      }

      final ok = await _confirm(
        'Pulihkan backup?',
        'Database saat ini akan diganti dengan ${imported.length} produk dari file backup.',
      );
      if (!ok) return;

      setState(() => _items = imported);
      await _save();
      _showMessage('Import berhasil: ${imported.length} produk.');
    } catch (e) {
      _showMessage('Import gagal: file JSON tidak valid.');
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _toggleTheme() async {
    _feedback();
    final prefs = await _prefs;
    setState(() => _dark = !_dark);
    await prefs.setBool(_themeKey, _dark);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final scheme = ColorScheme.fromSeed(
      seedColor: _blue,
      brightness: _dark ? Brightness.dark : Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Indomaret StokApp',
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: _surface,
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _dark ? const Color(0xFF1C2229) : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF0C1117),
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _navIndex,
            children: [
              _buildSearchPage(filtered),
              _buildAddPage(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildSearchPage(List<SnackItem> filtered) {
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildVoiceBanner()),
        SliverToBoxAdapter(child: _buildSearchBox()),
        SliverToBoxAdapter(child: _buildFilters()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '${filtered.length} produk',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(.55),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (_, index) => SnackCard(
                item: filtered[index],
                onStatus: _setStatus,
                onDelete: _deleteItem,
                onEdit: _openEditor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blueDark, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.96),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 16,
                      color: Colors.black26,
                      offset: Offset(0, 5),
                    )
                  ],
                ),
                child: Image.asset(_logoAsset, fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'StokApp',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 25,
                      ),
                    ),
                    Text(
                      'Inventory • Rack • Gudang',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIcon(
                icon: Icons.file_download_outlined,
                tooltip: 'Backup JSON',
                onTap: _exportBackup,
              ),
              _HeaderIcon(
                icon: Icons.file_upload_outlined,
                tooltip: 'Import JSON',
                onTap: _importBackup,
              ),
              _HeaderIcon(
                icon: _dark ? Icons.light_mode : Icons.dark_mode,
                tooltip: 'Shift / tema',
                onTap: _toggleTheme,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: 'TOTAL',
                value: '${_items.length}',
                icon: Icons.inventory_2_outlined,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: 'REFILL',
                value:
                    '${_items.where((e) => e.status == StockStatus.refill).length}',
                icon: Icons.replay_outlined,
              ),
              const SizedBox(width: 8),
              _MiniStat(
                label: 'KOSONG',
                value:
                    '${_items.where((e) => e.status == StockStatus.kosong).length}',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GestureDetector(
        onTap: _listen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _listening ? const Color(0xFFFFE5E5) : _yellow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _listening ? _red : const Color(0xFFFFB800),
              width: _listening ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (_listening ? _red : _yellow).withOpacity(.25),
                blurRadius: _listening ? 20 : 12,
                spreadRadius: _listening ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening ? _red : _blueDark,
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEKAN & SEBUT SNACK',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: .2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'BISA DITUMPUK • contoh: Oreo, Chitato sapi panggang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                _listening ? Icons.graphic_eq : Icons.chevron_right,
                color: _listening ? _red : _blueDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 5),
      child: TextField(
        controller: _searchController,
        onChanged: (_) {
          if (_voiceMode) {
            setState(() => _voiceMode = false);
          }
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Cari nama, rasa, ukuran, atau lokasi...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 51,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: '🔍 Hasil Cari',
            selected: _filter == 'search',
            onTap: () => setState(() => _filter = 'search'),
          ),
          _FilterChip(
            label: 'Semua Katalog Snack',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
          ),
          _FilterChip(
            label: '🟡 Perlu Restock',
            selected: _filter == 'restock',
            onTap: () => setState(() => _filter = 'restock'),
          ),
          _FilterChip(
            label: '🔴 Kosong Total',
            selected: _filter == 'empty',
            onTap: () => setState(() => _filter = 'empty'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPage() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_blueDark, _blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah Produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Masukkan snack baru ke database toko.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.add_box_outlined,
                  title: 'Tambah snack manual',
                  subtitle: 'Nama, rasa, ukuran, rak, gudang & foto',
                  onTap: () => _openEditor(),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.file_upload_outlined,
                  title: 'Import database',
                  subtitle: 'Pulihkan backup JSON secara offline',
                  onTap: _importBackup,
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.file_download_outlined,
                  title: 'Backup database',
                  subtitle: 'Export seluruh stok menjadi JSON',
                  onTap: _exportBackup,
                ),
                const SizedBox(height: 24),
                _InfoPanel(
                  title: 'Offline-first',
                  body:
                      'Perubahan status, produk, lokasi, foto, dan tema disimpan otomatis di perangkat. Tidak perlu server untuk penggunaan harian.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _navIndex,
      onDestinationSelected: (index) {
        _feedback();
        setState(() => _navIndex = index);
        if (index == 1) {
          // Keep navigation lightweight; user can press the add tile.
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.search_rounded),
          selectedIcon: Icon(Icons.search_rounded),
          label: 'Pencarian',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_box_outlined),
          selectedIcon: Icon(Icons.add_box),
          label: 'Tambah Produk',
        ),
      ],
    );
  }
}

class SnackCard extends StatelessWidget {
  final SnackItem item;
  final void Function(SnackItem, StockStatus) onStatus;
  final Future<void> Function(SnackItem) onDelete;
  final Future<void> Function(SnackItem) onEdit;

  const SnackCard({
    super.key,
    required this.item,
    required this.onStatus,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          HapticFeedback.heavyImpact();
          return await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Hapus produk?'),
                  content: Text(item.name),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _red,
                      ),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              ) ??
              false;
        },
        onDismissed: (_) => onDelete(item),
        background: Container(
          decoration: BoxDecoration(
            color: _red,
            borderRadius: BorderRadius.circular(23),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(
            Icons.delete_forever_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        child: Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(23),
          child: InkWell(
            borderRadius: BorderRadius.circular(23),
            onLongPress: () => onEdit(item),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                border: Border(
                  left: BorderSide(
                    color: item.status.color,
                    width: 5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.07),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProductImage(base64: item.imageBase64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 9),
                        _LocationLine(
                          icon: Icons.storefront_rounded,
                          color: const Color(0xFFFFB300),
                          label: 'Rak ${item.rack}',
                        ),
                        const SizedBox(height: 5),
                        _LocationLine(
                          icon: Icons.warehouse_rounded,
                          color: _blue,
                          label: 'Gudang ${item.warehouse}',
                        ),
                        const SizedBox(height: 11),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: StockStatus.values.map((status) {
                              final selected = item.status == status;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(50),
                                  onTap: () => onStatus(item, status),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? status.color.withOpacity(.16)
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: selected
                                            ? status.color
                                            : Colors.transparent,
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Text(
                                      status.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: selected
                                            ? status.color
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () => onEdit(item),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? base64;
  const _ProductImage({this.base64});

  @override
  Widget build(BuildContext context) {
    if (base64 != null && base64!.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Image.memory(
            base64Decode(base64!),
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: _blue.withOpacity(.08),
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Icon(
        Icons.fastfood_rounded,
        color: _blue,
        size: 34,
      ),
    );
  }
}

class _LocationLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _LocationLine({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class SnackEditorSheet extends StatefulWidget {
  final SnackItem? item;
  const SnackEditorSheet({super.key, this.item});

  @override
  State<SnackEditorSheet> createState() => _SnackEditorSheetState();
}

class _SnackEditorSheetState extends State<SnackEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _rack;
  late final TextEditingController _warehouse;
  StockStatus _status = StockStatus.ada;
  String? _photoBase64;
  bool _processingPhoto = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _rack = TextEditingController(text: item?.rack ?? '');
    _warehouse = TextEditingController(text: item?.warehouse ?? '');
    _status = item?.status ?? StockStatus.ada;
    _photoBase64 = item?.imageBase64;
  }

  @override
  void dispose() {
    _name.dispose();
    _rack.dispose();
    _warehouse.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _processingPhoto = true);
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final compressed = await _compress(bytes);
      setState(() => _photoBase64 = base64Encode(compressed));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto gagal diproses.')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingPhoto = false);
    }
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 1200,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return data?.buffer.asUint8List() ?? bytes;
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  void _save() {
    final name = _name.text.trim();
    final rack = _rack.text.trim();
    final warehouse = _warehouse.text.trim();

    if (name.isEmpty || rack.isEmpty || warehouse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama produk, rak, dan gudang wajib diisi.'),
        ),
      );
      return;
    }

    final item = SnackItem(
      id: widget.item?.id ??
          'custom-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      rack: rack,
      warehouse: warehouse,
      status: _status,
      imageBase64: _photoBase64,
      master: widget.item?.master ?? false,
    );

    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.item == null ? 'Tambah Snack' : 'Edit Snack',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Produk',
                    hintText: 'Contoh: Chitato Sapi Panggang 68g',
                    prefixIcon: Icon(Icons.fastfood_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _rack,
                        decoration: const InputDecoration(
                          labelText: 'Lokasi Rak',
                          hintText: 'R01-A03',
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _warehouse,
                        decoration: const InputDecoration(
                          labelText: 'Lokasi Gudang',
                          hintText: 'G01-A01',
                          prefixIcon: Icon(Icons.warehouse_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Status Stok',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                Row(
                  children: StockStatus.values.map((status) {
                    final selected = _status == status;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _status = status);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? status.color.withOpacity(.15)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    selected ? status.color : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              status.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected
                                    ? status.color
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Foto Rak / Dus',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 9),
                GestureDetector(
                  onTap: _processingPhoto ? null : _choosePhoto,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _blue.withOpacity(.25),
                      ),
                    ),
                    child: _processingPhoto
                        ? const Center(child: CircularProgressIndicator())
                        : _photoBase64 != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Image.memory(
                                  base64Decode(_photoBase64!),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 36,
                                    color: _blue,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Ketuk untuk kamera / galeri',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Foto otomatis diperkecil sebelum disimpan',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text(
                      'SIMPAN PRODUK',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(.12),
        foregroundColor: Colors.white,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _blue.withOpacity(.10),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.arrow_forward_rounded, color: _blue),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String body;

  const _InfoPanel({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _blue.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _blue.withOpacity(.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.offline_bolt_rounded, color: _blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(body),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'Produk tidak ditemukan',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 5),
            const Text(
              'Coba ubah kata pencarian atau filter.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StokApp());
}
