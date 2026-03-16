import 'package:flutter/material.dart';
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Home')));
}
class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}
