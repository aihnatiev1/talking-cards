import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../services/notification_service.dart';
import '../services/purchase_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  bool _loadingDone = false;
  bool _animDone = false;
  bool _imageReady = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );

    // Start loading in background
    _initServices();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imageReady) {
      precacheImage(
        const AssetImage('assets/images/webp/splash.webp'),
        context,
      ).then((_) {
        if (!mounted) return;
        setState(() => _imageReady = true);
        _ctrl.forward();
        Future.delayed(const Duration(milliseconds: 1200), () {
          _animDone = true;
          _navigateIfReady();
        });
      });
    }
  }

  Future<void> _initServices() async {
    await Future.wait([
      PurchaseService.instance.init(),
      AudioService.instance.precache(),
      NotificationService.instance.init(),
    ]);
    _loadingDone = true;
    _navigateIfReady();
  }

  void _navigateIfReady() {
    if (!_loadingDone || !_animDone || !mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _imageReady
            ? FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/webp/splash.webp',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Картки-розмовлялки',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          ),
        )
            : const SizedBox.shrink(),
      ),
    );
  }
}
