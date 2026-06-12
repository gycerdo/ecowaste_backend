import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  final String _backendUrl =
      "https://ecowaste-backend-v8i9.onrender.com/api/auth";

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$_backendUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usernameOrEmailController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showSnackBar("Karibu tena kwenye mfumo wa EcoWaste!");
        Navigator.pushReplacementNamed(context, '/home');
      } else if (response.statusCode == 403 && data['is_verified'] == false) {
        // HAPA NDIPO TUNAPODAKA AKAUNTI AMBAZO HAZIJAWA VERIFIED KWANZA
        _showSnackBar("Namba yako haijathibitishwa bado. Tunatuma OTP...",
            isError: true);
        _triggerOtpRequest(
            data['phone'] ?? _usernameOrEmailController.text.trim());
      } else {
        throw Exception(
            data['message'] ?? 'Mchanganyiko wa data zako sio sahihi');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(e.toString().replaceAll("Exception:", ""), isError: true);
    }
  }

  Future<void> _triggerOtpRequest(String phone) async {
    try {
      await http.post(
        Uri.parse("$_backendUrl/send-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"phone": phone}),
      );
      _showOtpBottomSheet(phone);
    } catch (e) {
      _showSnackBar("Imeshindwa kurun mtambo wa OTP", isError: true);
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
                                Navigator.pop(context);
                                _showSnackBar(
                                    "Uhakiki Umefanikiwa! Sasa unaweza kuingia.");
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
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text("🌿 EcoWaste",
                          style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 40),
                    TextFormField(
                      controller: _usernameOrEmailController,
                      decoration: const InputDecoration(
                          labelText: "Username au Barua Pepe",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person, color: Colors.green)),
                      validator: (v) =>
                          v!.isEmpty ? "Tafadhali jaza uwanja huu" : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: "Nywila (Password)",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock, color: Colors.green)),
                      validator: (v) =>
                          v!.isEmpty ? "Weka password yako" : null,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onPressed: _handleLogin,
                      child: const Text("Ingia Mfomoni",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: const Text("Hauna akaunti bado? Jisajili hapa",
                          style: TextStyle(color: Colors.green, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
