import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import 'log_waste_screen.dart';

// ── Waste pricing per kg (USD) ────────────────────────────────────────────────
const Map<String, double> _wastePricePerKg = {
  'plastic':     0.12,
  'paper':       0.08,
  'glass':       0.05,
  'metal':       0.25,
  'organic':     0.04,
  'e-waste':     0.80,
  'mixed waste': 0.06,
  'unknown':     0.07,
};

const double _baseCollectionFee = 2.50;
const double _usdToTzs          = 2650.0;

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {

  // ── Scan state ──────────────────────────────────────────────────────────────
  bool    _scanning      = false;
  String? _detectedType;
  double? _confidence;
  String? _description;
  bool    _verified      = false;
  File?   _capturedImage;
  String? _errorMessage;

  // ── Manual input ────────────────────────────────────────────────────────────
  String? _selectedType;
  final   _descCtrl    = TextEditingController();
  final   _weightCtrl  = TextEditingController();
  double? _enteredWeight;
  double? _aiWeightConfidence;
  bool    _showManualForm = false;

  // ── Cost state ──────────────────────────────────────────────────────────────
  double? _costUsd;
  double? _costTzs;
  bool    _costCalculated = false;

  // ── Animation ───────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulse;

  static const List<String> _wasteTypes = [
    'Plastic', 'Paper', 'Glass', 'Metal',
    'Organic', 'E-Waste', 'Mixed Waste',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  // ── Image picking ───────────────────────────────────────────────────────────
  Future<void> _scanFromCamera() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;
    await _analyzeImage(File(picked.path));
  }

  Future<void> _scanFromGallery() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 800);
    if (picked == null) return;
    await _analyzeImage(File(picked.path));
  }

  // ── Real AI analysis ────────────────────────────────────────────────────────
  Future<void> _analyzeImage(File file) async {
    final bytes       = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    setState(() {
      _scanning       = true;
      _verified       = false;
      _capturedImage  = file;
      _detectedType   = null;
      _confidence     = null;
      _description    = null;
      _errorMessage   = null;
      _showManualForm = false;
      _costCalculated = false;
      _costUsd        = null;
      _costTzs        = null;
    });

    final res = await ApiService.verifyAI(base64Image);

    if (!mounted) return;
    setState(() {
      _scanning = false;
      if (res.success) {
        _detectedType   = res.data?['detected_type'] as String? ?? 'Unknown';
        _confidence     = (res.data?['confidence'] as num?)?.toDouble() ?? 0;
        _description    = res.data?['description'] as String? ?? '';
        _verified       = true;
        _errorMessage   = null;
        _selectedType   = _wasteTypes.firstWhere(
          (t) => t.toLowerCase() == _detectedType!.toLowerCase(),
          orElse: () => _wasteTypes.first,
        );
        _descCtrl.text  = _description ?? '';
        _showManualForm = true;
      } else {
        _errorMessage   = res.message;
        _verified       = false;
        _showManualForm = true;
        _selectedType   = _wasteTypes.first;
      }
    });
  }

  // ── Simulate scan (demo) ────────────────────────────────────────────────────
  Future<void> _simulateScan() async {
    setState(() {
      _scanning       = true;
      _verified       = false;
      _showManualForm = false;
      _costCalculated = false;
      _errorMessage   = null;
    });

    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final rng   = Random();
    const types = ['Plastic', 'Paper', 'Glass', 'Metal', 'Organic', 'E-Waste'];
    const descs = {
      'Plastic': 'PET plastic bottles and containers detected.',
      'Paper':   'Cardboard and paper waste detected.',
      'Glass':   'Glass bottles and jars detected.',
      'Metal':   'Aluminum cans and metal scraps detected.',
      'Organic': 'Food waste and organic material detected.',
      'E-Waste': 'Electronic components and circuit boards detected.',
    };
    final type = types[rng.nextInt(types.length)];
    final conf = 70.0 + rng.nextDouble() * 28;

    setState(() {
      _scanning       = false;
      _detectedType   = type;
      _confidence     = conf;
      _description    = descs[type] ?? '';
      _verified       = true;
      _errorMessage   = null;
      _selectedType   = type;
      _descCtrl.text  = descs[type] ?? '';
      _showManualForm = true;
    });
  }

  // ── Weight AI confidence ────────────────────────────────────────────────────
  void _estimateWeightConfidence(double kg) {
    final type = (_selectedType ?? 'unknown').toLowerCase();
    double conf;
    if (type == 'e-waste')     conf = kg > 0.5 && kg < 50  ? 88 : 55;
    else if (type == 'metal')  conf = kg > 0.2 && kg < 200 ? 91 : 60;
    else if (type == 'glass')  conf = kg > 0.3 && kg < 100 ? 85 : 58;
    else                       conf = kg > 0.1 && kg < 500
        ? 78 + Random().nextDouble() * 15 : 50;
    conf = (conf + (Random().nextDouble() * 6 - 3)).clamp(40, 98);
    setState(() => _aiWeightConfidence = conf);
  }

  // ── Cost calculation ────────────────────────────────────────────────────────
  void _calculateCost() {
    final weight = double.tryParse(_weightCtrl.text.trim());
    if (weight == null || weight <= 0) return;
    final type = (_selectedType ?? 'unknown').toLowerCase();
    final rate = _wastePricePerKg[type] ?? _wastePricePerKg['unknown']!;
    final usd  = _baseCollectionFee + (weight * rate);
    final tzs  = usd * _usdToTzs;
    setState(() {
      _enteredWeight  = weight;
      _costUsd        = usd;
      _costTzs        = tzs;
      _costCalculated = true;
    });
    _estimateWeightConfidence(weight);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Color get _confidenceColor {
    if (_confidence == null)    return Colors.grey;
    if (_confidence! >= 85)     return const Color(0xFF1B8A5A);
    if (_confidence! >= 60)     return Colors.orange;
    return Colors.red;
  }

  Color _weightConfColor(double c) {
    if (c >= 80) return const Color(0xFF1B8A5A);
    if (c >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _wasteIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'plastic':     return Icons.local_drink_outlined;
      case 'paper':       return Icons.article_outlined;
      case 'glass':       return Icons.wine_bar_outlined;
      case 'metal':       return Icons.hardware_outlined;
      case 'organic':     return Icons.eco_outlined;
      case 'e-waste':     return Icons.devices_outlined;
      case 'mixed waste': return Icons.delete_sweep_outlined;
      default:            return Icons.delete_outline;
    }
  }

  String _formatTzs(double amount) {
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000)    return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final l10n  = AppLocalizations.of(context);
    final app   = context.watch<AppProvider>();
    final isDark = app.isDark;

    // ── Theme-aware colors ──────────────────────────────────────────────────
    final scaffoldBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5);
    final appBarBg   = isDark ? const Color(0xFF0D1117) : Colors.white;
    final appBarFg   = isDark ? Colors.white             : const Color(0xFF1A1A1A);
    final cardBg     = isDark ? const Color(0xFF161B22)  : Colors.white;
    final cardBorder = isDark ? const Color(0xFF30363D)  : Colors.black.withOpacity(0.08);
    final viewBg     = isDark ? const Color(0xFF0A0E14)  : const Color(0xFFEEEEEE);
    final mutedText  = isDark ? const Color(0xFF8B949E)  : Colors.black45;
    final subtleText = isDark ? const Color(0xFF484F58)  : Colors.black26;
    final infoBg     = isDark ? const Color(0xFF161B22)  : const Color(0xFFF0F0F0);
    final inputFill  = isDark ? const Color(0xFF0D1117)  : const Color(0xFFF5F5F5);
    final textColor  = isDark ? Colors.white              : const Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: appBarFg, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.aiWasteScan,
            style: TextStyle(
                color: appBarFg, fontWeight: FontWeight.w600, fontSize: 18)),
        actions: [
          // ── Language toggle ──────────────────────────────────────────────
          GestureDetector(
            onTap: () => app.setLocale(app.isSwahili ? 'en' : 'sw'),
            child: Container(
              margin: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B8A5A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF1B8A5A).withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  app.isSwahili ? '🇹🇿 SW' : '🇬🇧 EN',
                  style: const TextStyle(
                      color: Color(0xFF1B8A5A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          // ── Dark/Light toggle ────────────────────────────────────────────
          IconButton(
            icon: Icon(
                isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: appBarFg,
                size: 22),
            onPressed: app.toggleTheme,
          ),
          // ── Gemini badge ─────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF1B8A5A).withOpacity(0.4)),
            ),
            child: const Center(
              child: Text('Gemini',
                  style: TextStyle(
                      color: Color(0xFF1B8A5A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
          ),
        ],
      ),

      // ════════════════════════════════════════════════════════════════════════
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // ── Viewfinder ────────────────────────────────────────────────
              _buildViewfinder(
                  l10n, mutedText, subtleText, viewBg, isDark),

              const SizedBox(height: 14),

              // ── Action buttons ────────────────────────────────────────────
              Row(children: [
                Expanded(child: _actionBtn(
                    icon: Icons.camera_alt_outlined,
                    label: l10n.scanCamera,
                    onTap: _scanning ? null : _scanFromCamera,
                    isDark: isDark)),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn(
                    icon: Icons.photo_library_outlined,
                    label: l10n.scanGallery,
                    onTap: _scanning ? null : _scanFromGallery,
                    isDark: isDark)),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn(
                    icon: Icons.play_circle_outline,
                    label: app.isSwahili ? 'Simulate' : 'Simulate',
                    onTap: _scanning ? null : _simulateScan,
                    isDark: isDark,
                    accent: true)),
                const SizedBox(width: 8),
                Expanded(child: _actionBtn(
                    icon: Icons.refresh_outlined,
                    label: l10n.scanRescan,
                    onTap: (_scanning || _capturedImage == null)
                        ? null
                        : () => _analyzeImage(_capturedImage!),
                    isDark: isDark)),
              ]),

              const SizedBox(height: 16),

              // ── AI result card ────────────────────────────────────────────
              if (_verified) ...[
                _buildAiResultCard(
                    cardBg, mutedText, textColor, isDark, l10n),
                const SizedBox(height: 14),
              ],

              // ── Error banner ──────────────────────────────────────────────
              if (_errorMessage != null)
                _buildErrorBanner(app, cardBorder),

              // ── Manual input form ─────────────────────────────────────────
              if (_showManualForm)
                _buildManualForm(cardBg, cardBorder, inputFill,
                    textColor, mutedText, isDark, app, l10n),

              // ── Cost card ─────────────────────────────────────────────────
              if (_costCalculated) ...[
                const SizedBox(height: 16),
                _buildCostCard(cardBg, cardBorder, textColor,
                    mutedText, isDark, app, l10n),
              ],

              // ── Initial CTA ───────────────────────────────────────────────
              if (!_showManualForm && !_scanning &&
                  _capturedImage == null) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _scanFromCamera,
                  icon: const Icon(
                      Icons.document_scanner_outlined, size: 20),
                  label: Text(l10n.scanCta),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B8A5A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const LogWasteScreen())),
                  icon: Icon(Icons.edit_note_outlined,
                      color: mutedText, size: 20),
                  label: Text(l10n.scanSkipManual,
                      style: TextStyle(color: mutedText)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: cardBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Info note ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: infoBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: mutedText, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.scanInfo,
                        style: TextStyle(
                            color: mutedText,
                            fontSize: 12,
                            height: 1.5)),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Viewfinder ──────────────────────────────────────────────────────────────
  Widget _buildViewfinder(AppLocalizations l10n, Color mutedText,
      Color subtleText, Color viewBg, bool isDark) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: viewBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _verified
              ? const Color(0xFF1B8A5A)
              : _errorMessage != null
                  ? Colors.red.withOpacity(0.6)
                  : const Color(0xFF1B8A5A).withOpacity(0.3),
          width: _verified ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(fit: StackFit.expand, children: [
          // Image or placeholder
          if (_capturedImage != null)
            Image.file(_capturedImage!, fit: BoxFit.cover)
          else
            _buildPlaceholder(l10n, mutedText, subtleText, viewBg),

          // Scanning overlay
          if (_scanning) _buildScanningOverlay(l10n),

          // Corner brackets
          if (!_scanning) ...[
            _bracket(top: 14, left: 14,
                b: const Border(
                    top:  BorderSide(color: Color(0xFF1B8A5A), width: 3),
                    left: BorderSide(color: Color(0xFF1B8A5A), width: 3))),
            _bracket(top: 14, right: 14,
                b: const Border(
                    top:   BorderSide(color: Color(0xFF1B8A5A), width: 3),
                    right: BorderSide(color: Color(0xFF1B8A5A), width: 3))),
            _bracket(bottom: 14, left: 14,
                b: const Border(
                    bottom: BorderSide(color: Color(0xFF1B8A5A), width: 3),
                    left:   BorderSide(color: Color(0xFF1B8A5A), width: 3))),
            _bracket(bottom: 14, right: 14,
                b: const Border(
                    bottom: BorderSide(color: Color(0xFF1B8A5A), width: 3),
                    right:  BorderSide(color: Color(0xFF1B8A5A), width: 3))),
          ],

          // Verified badge
          if (_verified)
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: const Color(0xFF1B8A5A),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 12),
                  const SizedBox(width: 4),
                  Text(l10n.scanDetected,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),

          // Error badge
          if (_errorMessage != null && !_scanning)
            Positioned(
              top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('AI Failed — Manual Mode',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Placeholder ─────────────────────────────────────────────────────────────
  Widget _buildPlaceholder(AppLocalizations l10n, Color mutedText,
      Color subtleText, Color bg) {
    return Container(
      color: bg,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.camera_alt_outlined,
            size: 58, color: mutedText.withOpacity(0.4)),
        const SizedBox(height: 12),
        Text(l10n.scanPlaceholder,
            style: TextStyle(color: mutedText, fontSize: 15)),
        const SizedBox(height: 6),
        Text(l10n.scanPlaceholderSub,
            style: TextStyle(color: subtleText, fontSize: 12)),
      ]),
    );
  }

  // ── Scanning overlay ─────────────────────────────────────────────────────────
  Widget _buildScanningOverlay(AppLocalizations l10n) {
    return Container(
      color: Colors.black54,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ScaleTransition(
          scale: _pulse,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF1B8A5A), width: 2.5),
              color: const Color(0xFF1B8A5A).withOpacity(0.08),
            ),
            child: const Icon(Icons.document_scanner_outlined,
                color: Color(0xFF1B8A5A), size: 38),
          ),
        ),
        const SizedBox(height: 14),
        Text(l10n.scanAnalysing,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
        const SizedBox(height: 4),
        const Text('Powered by Gemini 1.5 Flash',
            style: TextStyle(
                color: Color(0xFF1B8A5A), fontSize: 12)),
        const SizedBox(height: 16),
        const SizedBox(
          width: 140,
          child: LinearProgressIndicator(
            backgroundColor: Color(0xFF21262D),
            color: Color(0xFF1B8A5A),
            minHeight: 3,
          ),
        ),
      ]),
    );
  }

  // ── AI Result Card ───────────────────────────────────────────────────────────
  Widget _buildAiResultCard(Color cardBg, Color mutedText,
      Color textColor, bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF1B8A5A).withOpacity(0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.auto_awesome,
              color: Color(0xFF1B8A5A), size: 18),
          const SizedBox(width: 8),
          Text(l10n.scanResultTitle,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15)),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Gemini Vision',
                style: TextStyle(
                    color: Color(0xFF1B8A5A), fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 14),

        // Type + description
        Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_wasteIcon(_detectedType),
                color: const Color(0xFF1B8A5A), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_detectedType ?? '',
                    style: TextStyle(
                        color: textColor,
                        fontSize: 19,
                        fontWeight: FontWeight.bold)),
                if (_description != null && _description!.isNotEmpty)
                  Text(_description!,
                      style: TextStyle(
                          color: mutedText,
                          fontSize: 12,
                          height: 1.4)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Confidence bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.scanConfidence,
                style: TextStyle(color: mutedText, fontSize: 13)),
            Text('${_confidence?.toStringAsFixed(1)}%',
                style: TextStyle(
                    color: _confidenceColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_confidence ?? 0) / 100,
            backgroundColor: isDark
                ? const Color(0xFF21262D)
                : Colors.black12,
            valueColor:
                AlwaysStoppedAnimation<Color>(_confidenceColor),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }

  // ── Error Banner ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(AppProvider app, Color cardBorder) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Scan Failed',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(_errorMessage!,
                    style: const TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        height: 1.4)),
                const SizedBox(height: 6),
                Text(
                  app.isSwahili
                      ? 'Unaweza kuchagua aina ya taka mwenyewe hapa chini.'
                      : 'You can still select waste type manually below.',
                  style: TextStyle(
                      color: Colors.red.withOpacity(0.7),
                      fontSize: 11,
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Manual Input Form ────────────────────────────────────────────────────────
  Widget _buildManualForm(
      Color cardBg, Color cardBorder, Color inputFill,
      Color textColor, Color mutedText, bool isDark,
      AppProvider app, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.edit_note_outlined,
              color: Color(0xFF1B8A5A), size: 20),
          const SizedBox(width: 8),
          Text(
            app.isSwahili ? 'Maelezo ya Taka' : 'Waste Details',
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                app.isSwahili ? 'Mkono' : 'Manual',
                style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 16),

        // ── Waste type dropdown ────────────────────────────────────────────
        Text(
          app.isSwahili ? 'Aina ya Taka' : 'Waste Type',
          style: TextStyle(
              color: mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              dropdownColor:
                  isDark ? const Color(0xFF161B22) : Colors.white,
              style: TextStyle(color: textColor, fontSize: 14),
              icon: Icon(Icons.keyboard_arrow_down, color: mutedText),
              items: _wasteTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Row(children: [
                          Icon(_wasteIcon(t),
                              color: const Color(0xFF1B8A5A),
                              size: 18),
                          const SizedBox(width: 10),
                          Text(t,
                              style: TextStyle(color: textColor)),
                        ]),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedType   = v;
                _costCalculated = false;
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── Description ────────────────────────────────────────────────────
        Text(
          app.isSwahili
              ? 'Maelezo (hiari)'
              : 'Description (optional)',
          style: TextStyle(
              color: mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          style: TextStyle(color: textColor, fontSize: 13),
          decoration: InputDecoration(
            hintText: app.isSwahili
                ? 'Elezea hali ya taka...'
                : 'Describe the waste condition...',
            hintStyle: TextStyle(color: mutedText, fontSize: 13),
            filled: true,
            fillColor: inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF1B8A5A)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 14),

        // ── Weight ─────────────────────────────────────────────────────────
        Text(
          app.isSwahili
              ? 'Uzito Unaokisia (kg)'
              : 'Approximate Weight (kg)',
          style: TextStyle(
              color: mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))
              ],
              style: TextStyle(color: textColor, fontSize: 14),
              onChanged: (v) {
                final w = double.tryParse(v);
                if (w != null && w > 0) _estimateWeightConfidence(w);
                setState(() => _costCalculated = false);
              },
              decoration: InputDecoration(
                hintText:
                    app.isSwahili ? 'mfano: 5.5' : 'e.g. 5.5',
                hintStyle: TextStyle(color: mutedText),
                suffixText: 'kg',
                suffixStyle: TextStyle(color: mutedText),
                filled: true,
                fillColor: inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF1B8A5A)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _calculateCost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              app.isSwahili ? 'Hesabu' : 'Calculate',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ]),

        // AI weight confidence
        if (_aiWeightConfidence != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.psychology_outlined,
                color: _weightConfColor(_aiWeightConfidence!),
                size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                app.isSwahili
                    ? 'AI: Uhakika wa uzito huu — '
                        '${_aiWeightConfidence!.toStringAsFixed(0)}%'
                    : 'AI weight plausibility — '
                        '${_aiWeightConfidence!.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: _weightConfColor(_aiWeightConfidence!),
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _aiWeightConfidence! / 100,
              backgroundColor:
                  isDark ? Colors.white10 : Colors.black12,
              valueColor: AlwaysStoppedAnimation(
                  _weightConfColor(_aiWeightConfidence!)),
              minHeight: 5,
            ),
          ),
        ],
      ]),
    );
  }

  // ── Cost Card ────────────────────────────────────────────────────────────────
  Widget _buildCostCard(
      Color cardBg, Color cardBorder, Color textColor,
      Color mutedText, bool isDark, AppProvider app,
      AppLocalizations l10n) {
    final type       = _selectedType ?? 'Unknown';
    final rate       = _wastePricePerKg[type.toLowerCase()] ?? 0.07;
    final weightCost = _enteredWeight! * rate;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20)
                .withOpacity(isDark ? 0.6 : 0.08),
            const Color(0xFF1B8A5A)
                .withOpacity(isDark ? 0.3 : 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF1B8A5A).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(children: [
            const Icon(Icons.calculate_outlined,
                color: Color(0xFF1B8A5A), size: 20),
            const SizedBox(width: 8),
            Text(
              app.isSwahili
                  ? 'Gharama ya Ubebaji'
                  : 'Collection Cost Estimate',
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            app.isSwahili
                ? 'Hesabu kulingana na aina na uzito wa taka'
                : 'Calculated based on waste type and weight',
            style: TextStyle(color: mutedText, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Breakdown
          _costRow(
              app.isSwahili ? 'Aina ya Taka' : 'Waste Type',
              type, textColor, mutedText),
          const SizedBox(height: 6),
          _costRow(
              app.isSwahili ? 'Uzito' : 'Weight',
              '${_enteredWeight!.toStringAsFixed(2)} kg',
              textColor, mutedText),
          const SizedBox(height: 6),
          _costRow(
              app.isSwahili ? 'Kiwango kwa kg' : 'Rate per kg',
              '\$${rate.toStringAsFixed(3)}',
              textColor, mutedText),
          const SizedBox(height: 6),
          _costRow(
              app.isSwahili ? 'Ada ya msingi' : 'Base collection fee',
              '\$${_baseCollectionFee.toStringAsFixed(2)}',
              textColor, mutedText),
          const SizedBox(height: 6),
          _costRow(
              app.isSwahili
                  ? 'Gharama ya taka'
                  : 'Waste handling cost',
              '\$${weightCost.toStringAsFixed(2)}',
              textColor, mutedText),

          Divider(
              color: const Color(0xFF1B8A5A).withOpacity(0.3),
              height: 20),

          // Total USD
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                app.isSwahili ? 'JUMLA (USD)' : 'TOTAL (USD)',
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              Text(
                '\$${_costUsd!.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Color(0xFF1B8A5A),
                    fontWeight: FontWeight.bold,
                    fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Total TZS
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A5A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Text('🇹🇿 ',
                      style: TextStyle(fontSize: 16)),
                  Text(
                    app.isSwahili
                        ? 'Sawa na (TZS)'
                        : 'Equivalent (TZS)',
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ]),
                Text(
                  'TZS ${_formatTzs(_costTzs!)}',
                  style: const TextStyle(
                      color: Color(0xFF1B8A5A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Exchange rate note
          Row(children: [
            Icon(Icons.currency_exchange, color: mutedText, size: 13),
            const SizedBox(width: 6),
            Text(
              app.isSwahili
                  ? 'Kiwango: 1 USD = ${_usdToTzs.toStringAsFixed(0)} TZS'
                  : 'Rate: 1 USD = ${_usdToTzs.toStringAsFixed(0)} TZS',
              style: TextStyle(color: mutedText, fontSize: 11),
            ),
          ]),
          const SizedBox(height: 16),

          // Confirm & Log button
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LogWasteScreen(
                  prefilledType:       _selectedType,
                  prefilledConfidence: _confidence,
                ),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: Text(l10n.scanConfirmLog),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B8A5A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Cost row ─────────────────────────────────────────────────────────────────
  Widget _costRow(String label, String value,
      Color textColor, Color mutedText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: mutedText, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ── Corner bracket ───────────────────────────────────────────────────────────
  Widget _bracket({
    double? top, double? bottom,
    double? left, double? right,
    required Border b,
  }) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(border: b)),
    );
  }

  // ── Action button ─────────────────────────────────────────────────────────────
  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool accent = false,
    required bool isDark,
  }) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? (isDark
                  ? const Color(0xFF0D1117)
                  : Colors.black.withOpacity(0.03))
              : accent
                  ? const Color(0xFF1B8A5A).withOpacity(0.12)
                  : (isDark
                      ? const Color(0xFF161B22)
                      : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: disabled
                ? (isDark
                    ? const Color(0xFF21262D)
                    : Colors.black.withOpacity(0.06))
                : accent
                    ? const Color(0xFF1B8A5A).withOpacity(0.5)
                    : (isDark
                        ? const Color(0xFF30363D)
                        : Colors.black.withOpacity(0.08)),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
            color: disabled
                ? (isDark
                    ? const Color(0xFF484F58)
                    : Colors.black26)
                : accent
                    ? const Color(0xFF1B8A5A)
                    : (isDark
                        ? const Color(0xFF8B949E)
                        : Colors.black54),
            size: 22),
          const SizedBox(height: 3),
          Text(label,
            style: TextStyle(
              color: disabled
                  ? (isDark
                      ? const Color(0xFF484F58)
                      : Colors.black26)
                  : accent
                      ? const Color(0xFF1B8A5A)
                      : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ]),
      ),
    );
  }
}