import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/stores.dart';
import '../state/app_state.dart';
import 'theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Mark(size: 84),
            SizedBox(height: 18),
            Text(
              'LUMEN',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: ink,
              ),
            ),
            SizedBox(height: 8),
            Text('A quieter kind of shop', style: TextStyle(color: Color(0xFF6E675E))),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Text(
        'L',
        style: TextStyle(
          color: paper,
          fontSize: size * 0.48,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: demoEmail);
  final _password = TextEditingController(text: demoPassword);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).signIn(_email.text, _password.text);
    if (!ok || !mounted) return;
    final redirect = GoRouterState.of(context).extra as String? ?? '/home';
    context.go(redirect);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Welcome back',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demo account is filled in. Password lumen123.',
            style: TextStyle(color: Color(0xFF6E675E)),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Text(auth.error!, style: const TextStyle(color: clay)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.busy ? null : _submit,
            child: Text(auth.busy ? 'Signing in…' : 'Sign in'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.push('/register', extra: GoRouterState.of(context).extra),
            child: const Text('Create an account'),
          ),
        ],
      ),
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref.read(authProvider.notifier).register(
          _name.text,
          _email.text,
          _password.text,
        );
    if (!ok || !mounted) return;
    final redirect = GoRouterState.of(context).extra as String? ?? '/home';
    context.go(redirect);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          if (auth.error != null) ...[
            const SizedBox(height: 12),
            Text(auth.error!, style: const TextStyle(color: clay)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: auth.busy ? null : _submit,
            child: Text(auth.busy ? 'Creating…' : 'Create account'),
          ),
        ],
      ),
    );
  }
}
