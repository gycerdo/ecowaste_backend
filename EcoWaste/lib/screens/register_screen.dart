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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final String _backendUrl =
      "https://ecowaste-backend-v8i9.onrender.com/api/auth";

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar("Usajili Umefanikiwa! Tunatuma kodi ya uhakiki...");
        _showOtpBottomSheet(_phoneController.text.trim());
      } else {
        throw Exception(data['message'] ?? 'Imeshindwa kukamilisha usajili.');
      }
    } catch (e) {
      if (!mounted) return;
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  top: 30,
                  left: 20,
                  right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("Thibitisha Namba Yako",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text("Weka kodi tuliyotuma kwenye namba $phoneNumber",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), hintText: "000000"),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 15)),
                    onPressed: _isVerifying
                        ? null
                        : () async {
                            if (_otpController.text.trim().length < 6) return;
                            setModalState(() => _isVerifying = true);

                            try {
                              final resp = await http.post(
                                Uri.parse("$_backendUrl/verify-otp"),
                                headers: {"Content-Type": "application/json"},
                                body: jsonEncode({
                                  "phone": phoneNumber,
                                  "code": _otpController.text.trim()
                                }),
                              );

                              if (resp.statusCode == 200) {
                                if (!mounted) return;
                                Navigator.pop(context); // Funga bottom sheet
                                _showSnackBar(
                                    "Uhakiki Umefanikiwa! Sasa unaweza kuingia.");
                                Navigator.pushReplacementNamed(
                                    context, '/login');
                              } else {
                                final resData = jsonDecode(resp.body);
                                throw Exception(
                                    resData['message'] ?? 'Kodi sio sahihi');
                              }
                            } catch (err) {
                              setModalState(() => _isVerifying = false);
                              _showSnackBar(
                                  err.toString().replaceAll("Exception:", ""),
                                  isError: true);
                            }
                          },
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("Thibitisha na Uingie",
                            style:
                                TextStyle(color: Colors.white, fontSize: 16)),
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text("🌿 EcoWaste",
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text("Unda akaunti mpya kuanza safari yako",
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                          labelText: "Username",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person, color: Colors.green)),
                      validator: (v) => v!.isEmpty ? "Weka username" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                          labelText: "Barua Pepe (Email)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email, color: Colors.green)),
                      validator: (v) => v!.isEmpty ? "Weka email yako" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: "Namba ya Simu",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone, color: Colors.green),
                          hintText: "07xxxxxxxx"),
                      validator: (v) =>
                          v!.isEmpty ? "Weka namba ya simu" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: "Nywila (Password)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock, color: Colors.green)),
                      validator: (v) => v!.isEmpty ? "Weka password" : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: _handleRegister,
                      child: const Text("Jisajili Sasa",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text("Tayari una akaunti? Ingia hapa",
                          style: TextStyle(color: Colors.green, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
