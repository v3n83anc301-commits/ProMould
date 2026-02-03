import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../theme/dark_theme.dart';
import '../utils/validators.dart';
import '../services/error_handler.dart';
import '../services/log_service.dart';
import '../services/rbac_service.dart';
import '../services/audit_service.dart';
import '../models/user_model.dart';
import '../core/constants.dart';
import 'role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUsers();
  }

  void _checkUsers() async {
    try {
      final usersBox = Hive.box('usersBox');
      LogService.info('Login screen loaded. Users in box: ${usersBox.length}');

      if (usersBox.isEmpty) {
        LogService.warning('No users found! Creating default admin...');
        await usersBox.put('admin', {
          'username': 'admin',
          'password': 'admin123',
          'level': 4,
          'shift': 'Any'
        });
        LogService.info('Default admin created');
      }

      // Log available users (without passwords)
      for (var key in usersBox.keys) {
        final user = usersBox.get(key) as Map?;
        if (user != null) {
          LogService.debug(
              'Available user: ${user['username']} (Level: ${user['level']})');
        }
      }
    } catch (e) {
      LogService.error('Error checking users', e);
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final usersBox = Hive.box('usersBox');
      final u = _u.text.trim();
      final p = _p.text;

      LogService.debug('Login attempt for user: $u');
      LogService.debug('Users box has ${usersBox.length} users');
      LogService.debug('User keys: ${usersBox.keys.toList()}');

      // Try to find user by key first (more efficient)
      Map? user;
      if (usersBox.containsKey(u)) {
        user = usersBox.get(u) as Map?;
        LogService.debug('Found user by key: $u');
      } else {
        // Fallback: search through all users
        LogService.debug('User not found by key, searching values...');
        try {
          user = usersBox.values
              .cast<Map>()
              .firstWhere((x) => x['username'] == u, orElse: () => {});
        } catch (e) {
          LogService.debug('Error searching users: $e');
          user = {};
        }
      }

      if (user == null || user.isEmpty) {
        LogService.warning('User not found: $u');
        throw AuthenticationException('User not found. Try username: admin');
      }

      if (user['password'] != p) {
        LogService.warning('Incorrect password for user: $u');
        throw AuthenticationException('Incorrect password');
      }

      final level = (user['level'] ?? 1) as int;
      LogService.auth('User $u logged in successfully (Level $level)');

      // Set RBAC context for the logged-in user
      try {
        final rbacUser = User.fromMap(Map<String, dynamic>.from(user));
        RBACService.setCurrentUser(rbacUser);
        
        // Log the login event
        await AuditService.logLogin(
          userId: rbacUser.id,
          userName: rbacUser.username,
          userRole: rbacUser.role,
        );
      } catch (e) {
        LogService.warning('Could not set RBAC context: $e');
        // Continue with legacy level-based auth as fallback
      }

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => RoleRouter(level: level, username: u)));
      }
    } catch (e) {
      LogService.error('Login failed', e);
      ErrorHandler.handle(e, context: 'Login');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            const SizedBox(height: 10),
            Image.asset('assets/logo.png', width: 120, height: 120),
            const SizedBox(height: 16),
            Text('ProMould',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _u,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (value) => Validators.required(value, 'Username'),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _p,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (value) => Validators.required(value, 'Password'),
              enabled: !_isLoading,
              onFieldSubmitted: (_) => _login(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _showDebugInfo,
              child:
                  const Text('Show Debug Info', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(height: 8),
            Text(
              'Default: admin / admin123',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ]),
        ),
      )),
    );
  }

  void _showDebugInfo() async {
    final usersBox = Hive.box('usersBox');
    final usersList = <String>[];

    for (var key in usersBox.keys) {
      final user = usersBox.get(key) as Map?;
      if (user != null) {
        usersList.add('${user['username']} (Level ${user['level']})');
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total users: ${usersBox.length}'),
            const SizedBox(height: 8),
            const Text('Available users:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (usersList.isEmpty)
              const Text('No users found!', style: TextStyle(color: Colors.red))
            else
              ...usersList.map((u) => Text('• $u')),
            const SizedBox(height: 16),
            if (usersList.isEmpty)
              ElevatedButton(
                onPressed: () async {
                  await usersBox.put('admin', {
                    'username': 'admin',
                    'password': 'admin123',
                    'level': 4,
                    'shift': 'Any'
                  });
                  Navigator.pop(context);
                  _checkUsers();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Admin user created!')),
                  );
                },
                child: const Text('Create Admin User'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
