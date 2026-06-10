import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NearbyVehiclesScreen extends StatefulWidget {
  const NearbyVehiclesScreen({super.key});
  @override
  State<NearbyVehiclesScreen> createState() => _NearbyVehiclesScreenState();
}

class _NearbyVehiclesScreenState extends State<NearbyVehiclesScreen> {
  List<dynamic> _vehicles = [];
  bool          _loading  = true;
  bool          _scanning = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _scanning = true; });
    await Future.delayed(const Duration(seconds: 1)); // scanning animation
    final res = await ApiService.getNearbyVehicles();
    if (!mounted) return;
    setState(() {
      _vehicles = res.data?['vehicles'] ?? [];
      _loading  = false;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Collection Vehicles'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          // Radar animation placeholder
          Container(
            height: 160,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _scanning
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      CircularProgressIndicator(color: Colors.greenAccent),
                      SizedBox(height: 10),
                      Text('Scanning for nearby vehicles...', style: TextStyle(color: Colors.white70)),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.local_shipping, color: Colors.greenAccent, size: 48),
                      const SizedBox(height: 8),
                      Text('${_vehicles.length} vehicle(s) found',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ]),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _vehicles.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
                          Icon(Icons.local_shipping_outlined, size: 60, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('Hakuna magari karibu nawe sasa hivi'),
                        ]),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _vehicles.length,
                        itemBuilder: (_, i) {
                          final v   = _vehicles[i];
                          final eta = v['eta_minutes'];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _statusColor(v['status']).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.local_shipping,
                                        color: _statusColor(v['status']), size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(v['plate_number'] ?? 'Unknown',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (v['driver_name'] != null)
                                          Text('Driver: ${v['driver_name']}',
                                              style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _statusColor(v['status']).withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              (v['status'] ?? 'unknown').toUpperCase(),
                                              style: TextStyle(
                                                color:    _statusColor(v['status']),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  if (eta != null)
                                    Column(children: [
                                      Text('$eta', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                                      const Text('min ETA', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                    ]),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'collecting': return Colors.blue;
      case 'full':       return Colors.red;
      case 'idle':       return Colors.green;
      default:           return Colors.grey;
    }
  }
}
