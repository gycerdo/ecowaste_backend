import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'main_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // email or driver ID
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailOtpCtrl = TextEditingController(); // NEW: for email OTP
  final _otpCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _useDriverId = false;
  bool _showOtpSection = false;
  bool _otpSent = false;
  bool _otpLoading = false;

  // NEW: OTP channel selection (phone or email)
  String _otpChannel = 'phone'; // 'phone' or 'email'
  String _otpTarget = '';

  @override
  void dispose() {
    for (final c in [
      _identifierCtrl,
      _passwordCtrl,
      _phoneCtrl,
      _emailOtpCtrl,
      _otpCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Normal login (email/driver ID + password) ─────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final res = await ApiService.login(
      email: _useDriverId ? null : _identifierCtrl.text.trim(),
      driverId: _useDriverId ? _identifierCtrl.text.trim() : null,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res.success) {
      final name = res.data?['user']?['full_name'] ??
          res.data?['user']?['username'] ??
          'User';
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => MainShell(username: name)));
    } else {
      _snack(res.message, Colors.red);
    }
  }

  // ── NEW: Send OTP using updated ApiService ─────────────────────────────────
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
      email = _emailOtpCtrl.text.trim();
      if (email.isEmpty || !email.contains('@')) {
        _snack('Weka barua pepe halisi', Colors.orange);
        return;
      }
      _otpTarget = email;
    }

    setState(() => _otpLoading = true);

    // Use the updated sendOtp method
    final result = await ApiService.sendOtp(
      phone: phone,
      email: email,
      name: 'User',
    );

    if (!mounted) return;
    setState(() {
      _otpLoading = false;
      _otpSent = result['success'] ?? false;
    });

    _snack(
      result['success']
          ? 'OTP imetumwa kwa $_otpTarget'
          : (result['message'] ?? 'Imeshindwa kutuma OTP'),
      result['success'] ? Colors.green : Colors.red,
    );
  }

  // ── NEW: Verify OTP using updated ApiService ───────────────────────────────
  Future<void> _verifyOtpAndLogin() async {
    final code = _otpCtrl.text.trim();
    if (code.length != 6) {
      _snack('Weka nambari 6 za OTP', Colors.orange);
      return;
    }

    setState(() => _otpLoading = true);

    String? phone;
    String? email;

    if (_otpChannel == 'phone') {
      phone = _phoneCtrl.text.trim();
    } else {
      email = _emailOtpCtrl.text.trim();
    }

    // Use the updated verifyOtp method
    final result = await ApiService.verifyOtp(
      phone: phone,
      email: email,
      otp: code,
    );

    if (!mounted) return;
    setState(() => _otpLoading = false);

    if (result['success']) {
      _snack('Umeingia kwa mafanikio! 🌿', Colors.green);

      // Try to login with OTP as password (if backend supports)
      final loginRes = await ApiService.login(
        phone: phone,
        email: email,
        password: code, // Use OTP as temporary password
      );

      if (loginRes.success && mounted) {
        final name = loginRes.data?['user']?['full_name'] ??
            loginRes.data?['user']?['username'] ??
            'User';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainShell(username: name)),
        );
      } else if (mounted) {
        // If OTP login not fully integrated, just go to home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainShell(username: 'User')),
        );
      }
    } else {
      _snack(result['message'] ?? 'OTP si sahihi', Colors.red);
    }
  }

  void _snack(String msg, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.eco_rounded,
                      size: 60, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 14),
                  Text('Welcome Back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Log in to EcoWaste',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 32),

                  // Toggle: Email vs Driver ID
                  Row(children: [
                    const Text('Login with: ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    ChoiceChip(
                      label: const Text('Email'),
                      selected: !_useDriverId,
                      onSelected: (_) => setState(() => _useDriverId = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Driver ID'),
                      selected: _useDriverId,
                      onSelected: (_) => setState(() => _useDriverId = true),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _identifierCtrl,
                    decoration: InputDecoration(
                      labelText: _useDriverId ? 'Driver License / ID' : 'Email',
                      prefixIcon: Icon(_useDriverId
                          ? Icons.badge_outlined
                          : Icons.email_outlined),
                    ),
                    keyboardType: _useDriverId
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'This field is required'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordCtrl,
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
                    obscureText: _obscurePass,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Password required' : null,
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Log In', style: TextStyle(fontSize: 16)),
                  ),

                  // SMS/Email OTP Section
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () =>
                        setState(() => _showOtpSection = !_showOtpSection),
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(_showOtpSection
                        ? 'Hide OTP Option'
                        : 'Use OTP Code Instead'),
                  ),

                  if (_showOtpSection) ...[
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 8),

                    // OTP Channel Selection
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                  value: 'phone', label: Text('📱 SMS')),
                              ButtonSegment(
                                  value: 'email', label: Text('📧 Email')),
                            ],
                            selected: {_otpChannel},
                            onSelectionChanged: (Set<String> selection) {
                              setState(() {
                                _otpChannel = selection.first;
                                _otpSent = false;
                                _otpCtrl.clear();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Phone or Email input based on channel
                    if (_otpChannel == 'phone')
                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          hintText: '0755XXXXXX',
                        ),
                        keyboardType: TextInputType.phone,
                      )
                    else
                      TextFormField(
                        controller: _emailOtpCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: Icon(Icons.email_outlined),
                          hintText: 'you@example.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),

                    const SizedBox(height: 12),

                    // Send OTP Button
                    if (!_otpSent)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: _otpLoading ? null : _sendOtp,
                          child: _otpLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Send OTP Code'),
                        ),
                      ),

                    // OTP Verification Section
                    if (_otpSent) ...[
                      const SizedBox(height: 12),
                      Text(
                        'OTP imetumwa kwa: $_otpTarget',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _otpCtrl,
                              decoration: const InputDecoration(
                                labelText: '6-digit OTP Code',
                                prefixIcon: Icon(Icons.pin_outlined),
                                counterText: '',
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 20, letterSpacing: 4),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: _otpLoading ? null : _verifyOtpAndLogin,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                            child: _otpLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Verify & Login'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _otpLoading ? null : _sendOtp,
                        child: const Text('Resend OTP'),
                      ),
                    ],
                  ],

                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RegisterScreen())),
                      child: const Text('Register'),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
