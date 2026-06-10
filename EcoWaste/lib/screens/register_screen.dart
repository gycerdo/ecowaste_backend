import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // OTP state variables
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _otpLoading = false;
  String _otpTarget = '';
  String _otpChannel = 'phone'; // 'phone' or 'email'
  String _autoFillOtp = '';

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // Send OTP to backend
  Future<void> _sendOtp() async {
    String? phone;
    String? email;

    if (_otpChannel == 'phone') {
      phone = _phoneCtrl.text.trim();
      if (phone.isEmpty) {
        _snack('Weka namba ya simu', Colors.orange);
        return;
      }
      _otpTarget = phone;
    } else {
      email = _emailCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        _snack('Weka barua pepe halisi', Colors.orange);
        return;
      }
      _otpTarget = email;
    }

    setState(() {
      _otpLoading = true;
      _otpSent = false;
      _otpVerified = false;
      _autoFillOtp = '';
      _otpCtrl.clear();
    });

    try {
      final response = await ApiService.sendOtp(
        phone: phone,
        email: email,
        name: _fullNameCtrl.text.trim().isEmpty
            ? 'User'
            : _fullNameCtrl.text.trim(),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // Auto-fill OTP if available
        if (response['otp'] != null && response['otp'].toString().isNotEmpty) {
          _autoFillOtp = response['otp'].toString();
          _otpCtrl.text = _autoFillOtp;
          _snack('✅ OTP: $_autoFillOtp', Colors.green);

          // Auto-verify after 1 second
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted && !_otpVerified) {
              _verifyOtp();
            }
          });
        } else {
          _snack('✅ OTP imetumwa kwa $_otpTarget', Colors.green);
        }

        setState(() {
          _otpSent = true;
          _otpLoading = false;
        });
      } else {
        setState(() => _otpLoading = false);
        _snack('Imeshindwa: ${response['message']}', Colors.red);
      }
    } catch (e) {
      setState(() => _otpLoading = false);
      _snack('Error: $e', Colors.red);
    }
  }

  // Verify OTP with backend
  Future<void> _verifyOtp() async {
    final enteredOtp = _otpCtrl.text.trim();
    if (enteredOtp.isEmpty) {
      _snack('Weka OTP', Colors.orange);
      return;
    }

    setState(() => _otpLoading = true);

    try {
      final response = await ApiService.verifyOtp(
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        otp: enteredOtp,
      );

      if (!mounted) return;

      if (response['success'] == true && response['verified'] == true) {
        setState(() {
          _otpVerified = true;
          _otpLoading = false;
        });
        _snack('✓ Imethibitishwa! Sasa jisajili...', Colors.green);

        // Auto-register after successful verification
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _register();
        });
      } else {
        setState(() => _otpLoading = false);
        _snack(response['message'] ?? 'OTP si sahihi', Colors.red);
      }
    } catch (e) {
      setState(() => _otpLoading = false);
      _snack('Verification failed: $e', Colors.red);
    }
  }

  // Complete registration - FIXED: Using ApiResponse properties
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_otpVerified) {
      _snack('Thibitisha OTP kwanza', Colors.orange);
      return;
    }

    setState(() => _loading = true);

    final username = _emailCtrl.text.split('@').first.trim();
    final phone = _phoneCtrl.text.trim();

    // FIXED: ApiService.register returns ApiResponse, not Map
    final res = await ApiService.register(
      fullName: _fullNameCtrl.text.trim(),
      username: username,
      email: _emailCtrl.text.trim(),
      phone: phone.isEmpty
          ? ''
          : phone, // FIXED: pass empty string instead of null
      driverLicense:
          _licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim(),
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    // FIXED: Use .success instead of ['success']
    if (res.success) {
      _snack('Karibu EcoWaste! 🌿', Colors.green);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell(username: 'User')),
      );
    } else {
      // FIXED: Use .message instead of ['message']
      _snack(res.message, Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.eco_rounded,
                    size: 56, color: Color(0xFF2E7D32)),
                const SizedBox(height: 10),
                const Text('Create Account',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Join the EcoWaste community',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black45, fontSize: 14)),
                const SizedBox(height: 24),

                // Full Name
                TextFormField(
                  controller: _fullNameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter full name'
                      : null,
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined)),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter valid email'
                      : null,
                ),
                const SizedBox(height: 14),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '0755XXXXXX'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                // Driver License
                TextFormField(
                  controller: _licenseCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Driver License (optional)',
                      prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'At least 6 characters'
                      : null,
                ),
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) =>
                      v != _passwordCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 20),

                // OTP Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.verified_user,
                            size: 20,
                            color: _otpVerified ? Colors.green : Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                            _otpVerified ? '✓ Verified' : 'Verify Your Contact',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _otpVerified
                                    ? Colors.green
                                    : Colors.orange)),
                        if (_autoFillOtp.isNotEmpty && !_otpVerified)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('OTP: $_autoFillOtp',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green.shade800)),
                          ),
                      ]),
                      const SizedBox(height: 12),
                      if (!_otpVerified) ...[
                        Row(children: [
                          Expanded(
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'phone', label: Text('📱 SMS')),
                                ButtonSegment(
                                    value: 'email', label: Text('📧 Email'))
                              ],
                              selected: {_otpChannel},
                              onSelectionChanged: (Set<String> selection) {
                                setState(() {
                                  _otpChannel = selection.first;
                                  _otpSent = false;
                                  _otpVerified = false;
                                  _autoFillOtp = '';
                                  _otpCtrl.clear();
                                });
                              },
                            ),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        if (!_otpSent)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _otpLoading ? null : _sendOtp,
                              icon: _otpLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Icon(_otpChannel == 'phone'
                                      ? Icons.sms
                                      : Icons.email),
                              label: Text(_otpLoading
                                  ? 'Sending...'
                                  : 'Send OTP via ${_otpChannel == 'phone' ? 'SMS' : 'Email'}'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white),
                            ),
                          ),
                        if (_otpSent) ...[
                          Text('Code sent to: $_otpTarget',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(
                                    counterText: '',
                                    hintText: 'Enter 6-digit code',
                                    border: OutlineInputBorder()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                                onPressed: _otpLoading ? null : _verifyOtp,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green),
                                child: const Text('Verify')),
                          ]),
                          TextButton(
                              onPressed: _otpLoading ? null : _sendOtp,
                              child: const Text('Resend Code')),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Register Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_loading || !_otpVerified) ? null : _register,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Register',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Already have an account?"),
                  TextButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen())),
                      child: const Text('Log in')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
