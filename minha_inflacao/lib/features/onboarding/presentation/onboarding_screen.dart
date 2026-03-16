import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _consentSharing = false;
  bool _loading = false;

  static const _slides = [
    _Slide(
      icon: Icons.receipt_long,
      title: 'Fotografe suas notas',
      body: 'Aponte a câmera para qualquer nota fiscal. O app extrai automaticamente os produtos e preços.',
    ),
    _Slide(
      icon: Icons.trending_up,
      title: 'Acompanhe sua inflação',
      body: 'Veja como os preços dos seus produtos favoritos evoluem ao longo do tempo.',
    ),
    _Slide(
      icon: Icons.location_on,
      title: 'Compare com sua região',
      body: 'Descubra se você está pagando mais ou menos do que outros consumidores próximos.',
    ),
  ];

  Future<void> _finish() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'consentSharing': _consentSharing,
        'consentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideWidget(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _currentPage ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentPage
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_currentPage == _slides.length - 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SwitchListTile(
                  title: const Text(
                    'Compartilhar meus preços anonimamente',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'Seus preços, sem identificação pessoal, ajudam outros usuários a comparar valores na sua região.',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _consentSharing,
                  onChanged: (v) => setState(() => _consentSharing = v),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  if (_currentPage < _slides.length - 1) ...[
                    TextButton(
                      onPressed: () {
                        _pageController.animateToPage(
                          _slides.length - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Text('Pular'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Próximo'),
                    ),
                  ] else ...[
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _finish,
                        child: _loading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Começar'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class _Slide {
  final IconData icon;
  final String title;
  final String body;
  const _Slide({required this.icon, required this.title, required this.body});
}

class _SlideWidget extends StatelessWidget {
  final _Slide slide;
  const _SlideWidget({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(slide.icon, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 32),
          Text(slide.title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(slide.body, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
