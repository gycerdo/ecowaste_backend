import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LogWasteScreen extends StatefulWidget {
  final String? prefilledType;
  final double? prefilledConfidence;

  const LogWasteScreen({super.key, this.prefilledType, this.prefilledConfidence});

  @override
  State<LogWasteScreen> createState() => _LogWasteScreenState();
}

class _LogWasteScreenState extends State<LogWasteScreen> {
  final _pageCtrl = PageController();
  int  _step      = 0;

  // Step 1 fields
  String? _wasteType;
  final   _containerCtrl = TextEditingController(text: '1');

  // Step 2 fields
  final _weightCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String? _photoUrl;
  bool _loading = false;

  final List<String> _wasteTypes = ['plastic', 'paper', 'glass', 'metal', 'organic', 'hazardous'];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledType != null) _wasteType = widget.prefilledType;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _containerCtrl.dispose();
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_wasteType == null) {
      _snack('Chagua aina ya taka kwanza', Colors.orange);
      return;
    }
    setState(() => _step = 1);
    _pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _submit() async {
    setState(() => _loading = true);

    final res = await ApiService.logWaste(
      wasteType:      _wasteType!,
      containerCount: int.tryParse(_containerCtrl.text) ?? 1,
      weightKg:       double.tryParse(_weightCtrl.text),
      photoUrl:       _photoUrl,
      aiConfidence:   widget.prefilledConfidence,
      aiDetectedType: widget.prefilledType,
      notes:          _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      _snack('Taka imerekodiwa! 🌿', Colors.green);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      _snack(res.message, Colors.red);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Log Waste – Step ${_step + 1} of 2'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / 2,
            backgroundColor: Colors.white30,
            color: Colors.white,
          ),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStep1(), _buildStep2()],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.prefilledType != null)
            Card(
              color: const Color(0xFFE8F5E9),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.smart_toy_outlined, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('AI detected: ${widget.prefilledType} (${widget.prefilledConfidence?.toStringAsFixed(1) ?? ''}%)',
                      style: const TextStyle(color: Colors.green)),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Select Waste Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _wasteTypes.map((type) {
              final selected = _wasteType == type;
              return ChoiceChip(
                label: Text(type[0].toUpperCase() + type.substring(1)),
                selected: selected,
                selectedColor: const Color(0xFF2E7D32),
                labelStyle: TextStyle(color: selected ? Colors.white : null),
                avatar: Icon(_wasteIcon(type), size: 18,
                    color: selected ? Colors.white : Colors.grey),
                onSelected: (_) => setState(() => _wasteType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Container Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            IconButton(
              onPressed: () {
                final v = int.tryParse(_containerCtrl.text) ?? 1;
                if (v > 1) _containerCtrl.text = (v - 1).toString();
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Expanded(
              child: TextFormField(
                controller: _containerCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Containers'),
              ),
            ),
            IconButton(
              onPressed: () {
                final v = int.tryParse(_containerCtrl.text) ?? 1;
                _containerCtrl.text = (v + 1).toString();
              },
              icon: const Icon(Icons.add_circle_outline),
            ),
          ]),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _nextStep,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Next → Weight & Photo', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFFE8F5E9),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Icon(_wasteIcon(_wasteType), color: Colors.green),
                const SizedBox(width: 8),
                Text('Type: ${_wasteType ?? ''} | Containers: ${_containerCtrl.text}',
                    style: const TextStyle(color: Colors.green)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _weightCtrl,
            decoration: const InputDecoration(
              labelText: 'Estimated Weight (kg)',
              prefixIcon: Icon(Icons.scale_outlined),
              suffixText: 'kg',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),

          // Photo upload placeholder
          OutlinedButton.icon(
            onPressed: () {
              // Integrate image_picker here
              setState(() => _photoUrl = 'https://example.com/waste_photo.jpg');
              _snack('Picha imepakiwa (simulated)', Colors.green);
            },
            icon: const Icon(Icons.add_a_photo_outlined),
            label: Text(_photoUrl != null ? 'Photo Added ✓' : 'Add Photo'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(color: _photoUrl != null ? Colors.green : Colors.grey),
            ),
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _step = 0);
                  _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
                child: const Text('← Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit Waste Log', style: TextStyle(fontSize: 16)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  IconData _wasteIcon(String? type) {
    switch (type) {
      case 'plastic':   return Icons.water_drop_outlined;
      case 'paper':     return Icons.description_outlined;
      case 'glass':     return Icons.wine_bar_outlined;
      case 'metal':     return Icons.hardware_outlined;
      case 'organic':   return Icons.grass_outlined;
      case 'hazardous': return Icons.warning_amber_outlined;
      default:          return Icons.delete_outline;
    }
  }
}
