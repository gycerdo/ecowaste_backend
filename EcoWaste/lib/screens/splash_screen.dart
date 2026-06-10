import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late PageController _pageCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  int _currentPage = 0;
  bool _checking = false;

  // ── Onboarding slides ──────────────────────────────────────────────────────
  final List<_Slide> _slides = [
    _Slide(
      imageUrl:
          'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=80',
      tag: 'Civic Intelligence',
      title: 'Smarter Waste\nCollection',
      subtitle: 'AI-powered routes and real-time tracking for every district.',
    ),
    _Slide(
      imageUrl:
          'https://images.unsplash.com/photo-1611284446314-60a58ac0deb9?w=800&q=80',
      tag: 'AI Scanning',
      title: 'Identify Waste\nInstantly',
      subtitle: 'Point your camera — GPT-4o detects waste type in seconds.',
    ),
    _Slide(
      imageUrl:
          'https://images.unsplash.com/photo-1542601906897-ecd7a3fd4acb?w=800&q=80',
      tag: 'Eco Impact',
      title: 'Track Your\nGreen Impact',
      subtitle: 'See your CO₂ offset, eco points and weekly progress grow.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _pageCtrl = PageController();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    // Check login in background — navigate immediately if already logged in
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await ApiService.isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      final username = await ApiService.getUsername() ?? 'User';
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MainShell(username: username)),
      );
    }
  }

  /// Skip advances to the next slide only — never jumps to login directly.
  void _skip() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Arrow button on non-last slides also advances to next slide.
  void _nextPage() {
    if (!mounted) return;
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Only called from "Get Started" on the last slide.
  void _getStarted() => _goToLogin();

  void _goToLogin() {
    if (_checking) return;
    _checking = true;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // Skip is visible on slides 1 and 2 only; hidden on the last slide.
          if (_currentPage < _slides.length - 1)
            Padding(
              padding: const EdgeInsets.only(right: 20, top: 8),
              child: GestureDetector(
                onTap: _skip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 0.5),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background images ────────────────────────────────────────
            PageView.builder(
              controller: _pageCtrl,
              itemCount: _slides.length,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
              },
              itemBuilder: (_, i) => _BackgroundImage(url: _slides[i].imageUrl),
            ),

            // ── Dark gradient overlay ────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.35, 0.65, 1.0],
                  colors: [
                    Color(0x55000000),
                    Color(0x00000000),
                    Color(0xAA000000),
                    Color(0xFF000000),
                  ],
                ),
              ),
            ),

            // ── Bottom content ───────────────────────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    28, 0, 28, MediaQuery.of(context).padding.bottom + 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tag pill
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_currentPage),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B8A5A),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _slides[_currentPage].tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Title
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _slides[_currentPage].title,
                        key: ValueKey('title_$_currentPage'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _slides[_currentPage].subtitle,
                        key: ValueKey('sub_$_currentPage'),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Dots + CTA row
                    Row(
                      children: [
                        // Dots
                        Row(
                          children: List.generate(
                            _slides.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: _currentPage == i ? 24 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: _currentPage == i
                                    ? const Color(0xFF1B8A5A)
                                    : Colors.white.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),

                        // CTA button — arrow on slides 1 & 2, "Get Started" on last
                        GestureDetector(
                          onTap: _currentPage == _slides.length - 1
                              ? _getStarted
                              : _nextPage,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  _currentPage == _slides.length - 1 ? 24 : 0,
                              vertical: 14,
                            ),
                            width:
                                _currentPage == _slides.length - 1 ? null : 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _currentPage == _slides.length - 1
                                  ? const Color(0xFF1B8A5A)
                                  : Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _currentPage == _slides.length - 1
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_currentPage == _slides.length - 1)
                                  const Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                if (_currentPage == _slides.length - 1)
                                  const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Progress dots bar (static — no auto-progress fill) ───────
            Positioned(
              top: MediaQuery.of(context).padding.top + 56,
              left: 28,
              right: 28,
              child: Row(
                children: List.generate(
                  _slides.length,
                  (i) => Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _currentPage
                            ? Colors.white
                            : Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Background image widget ──────────────────────────────────────────────────
class _BackgroundImage extends StatelessWidget {
  final String url;
  const _BackgroundImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(color: const Color(0xFF0D1117));
      },
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFF0D1117),
        child: const Center(
          child: Icon(Icons.eco_rounded, size: 80, color: Color(0xFF1B8A5A)),
        ),
      ),
    );
  }
}

// ── Slide data ───────────────────────────────────────────────────────────────
class _Slide {
  final String imageUrl;
  final String tag;
  final String title;
  final String subtitle;

  const _Slide({
    required this.imageUrl,
    required this.tag,
    required this.title,
    required this.subtitle,
  });
}