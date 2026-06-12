import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Mahususi kwa ajili ya kuzuia kosa la RELATIONSHIP USER DOES NOT EXIST
  String _selectedVehicleType = 'none'; 
  final List<String> _vehicleOptions = ['none', 'pickup', 'truck', 'tricycle', 'bicycle'];

  bool _isLoading = false;
  final String _backendUrl = "https://ecowaste-backend-v8i9.onrender.com/api/auth";

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_backendUrl/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameController.text.trim(),
          "email": _emailController.text.trim(),
          "phone": _phoneController.text.trim(),
          "password": _passwordController.text.trim(),
          "full_name": _fullNameController.text.trim(),
          "vehicle_type": _selectedVehicleType, // Zinasafirishwa kwenda PostgreSQL vizuri
          "role": _selectedVehicleType == 'none' ? 'user' : 'driver'
        }),
      );

      final data = jsonDecode(response.body);

      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showOtpBottomSheet(_phoneController.text.trim());
      } else {
        throw Exception(data['message'] ?? 'Imeshindwa kusajili akaunti');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceAll("Exception:", ""), isError: true);
    }
  }

  void _showOtpBottomSheet(String phoneNumber) {
    final _otpController = TextEditingController();
    bool _isVerifying = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 30, left: 20, right: 20
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Kodi ya Uhakiki (OTP)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text("Weka tarakimu 6 zilizotumwa kwenda $phoneNumber", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "000000"),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _isVerifying ? null : () async {
                      if (_otpController.text.trim().length < 6) return;
                      setModalState(() => _isVerifying = true);

                      try {
                        final resp = await http.post(
                          Uri.parse("$_backendUrl/verify-otp"),
                          headers: {"Content-Type": "application/json"},
                          body: jsonEncode({"phone": phoneNumber, "code": _otpController.text.trim()}),
                        );
                        final resData = jsonDecode(resp.body);

                        if (resp.statusCode == 200) {
                          Navigator.pop(context); // Funga sheet
                          _showSnackBar("Akaunti imethibitishwa kikamilifu! Karibu Login.");
                          Navigator.pushReplacementNamed(context, '/login');
                        } else {
                          throw Exception(resData['message'] ?? 'OTP si sahihi');
                        }
                      } catch (err) {
                        setModalState(() => _isVerifying = false);
                        _showSnackBar(err.toString().replaceAll("Exception:", ""), isError: true);
                      }
                    },
                    child: _isVerifying 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Kamilisha Uhakiki", style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Jisajili EcoWaste"), backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(labelText: "Jina Kamili", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person, color: Colors.green)),
                      validator: (v) => v!.isEmpty ? "Jaza jina lako" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_circle, color: Colors.green)),
                      validator: (v) => v!.isEmpty ? "Jaza username" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email, color: Colors.green)),
                      validator: (v) => !v!.contains("@") ? "Weka email sahihi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Namba ya Simu (Mfano: 0719242796)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone, color: Colors.green)),
                      validator: (v) => v!.length < 10 ? "Weka namba sahihi" : null,
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _selectedVehicleType,
                      decoration: const InputDecoration(labelText: "Aina ya Usafiri (Vehicle Type)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.delivery_dining, color: Colors.green)),
                      items: _vehicleOptions.map((type) => DropdownMenuItem(value: type, child: Text(type.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _selectedVehicleType = val!),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Nywila (Password)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock, color: Colors.green)),
                      validator: (v) => v!.length < 6 ? "Password lazima izidi tarakimu 6" : null,
                    ),
                    const SizedBox(height: 25),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: _handleRegister,
                      child: const Text("Tengeneza Akaunti", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}