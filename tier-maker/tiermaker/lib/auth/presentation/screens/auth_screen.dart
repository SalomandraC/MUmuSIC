import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:RandomTierList/app/app_routes.dart';
import 'package:RandomTierList/app/state/app_model_provider.dart';
import 'package:RandomTierList/core/api/auth_api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final appModel = AppModelProvider.of(context);

    try {
      if (_isRegisterMode) {
        // Регистрация
        final username = _nicknameController.text.trim();
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        final result = await AuthApi.register(
          username: username,
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>;
          final user = data['user'] as Map<String, dynamic>;
          final tokens = data['tokens'] as Map<String, dynamic>;

          await appModel.setAuthData(
            email: user['email'] as String,
            username: user['username'] as String,
            accessToken: tokens['accessToken'] as String,
            refreshToken: tokens['refreshToken'] as String,
            userId: user['id'] as int,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Регистрация выполнена успешно'),
              backgroundColor: Colors.green,
            ),
          );
          context.go(AppRoutes.home);
        } else {
          final error = result['error'] as String? ?? 'Ошибка регистрации';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Вход
        final email = _emailController.text.trim();
        final password = _passwordController.text;

        final result = await AuthApi.login(
          email: email,
          password: password,
        );

        if (!mounted) return;

        if (result['success'] == true) {
          final data = result['data'] as Map<String, dynamic>;
          final user = data['user'] as Map<String, dynamic>;
          final tokens = data['tokens'] as Map<String, dynamic>;

          await appModel.setAuthData(
            email: user['email'] as String,
            username: user['username'] as String,
            accessToken: tokens['accessToken'] as String,
            refreshToken: tokens['refreshToken'] as String,
            userId: user['id'] as int,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Вход выполнен успешно'),
              backgroundColor: Colors.green,
            ),
          );
          context.go(AppRoutes.home);
        } else {
          final error = result['error'] as String? ?? 'Ошибка входа';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGuestLogin() async {
    final appModel = AppModelProvider.of(context);
    await appModel.setGuestMode(true);

    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? theme.colorScheme.surface : Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isRegisterMode ? 'Регистрация' : 'Вход',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _nicknameController,
                      decoration: InputDecoration(
                        labelText: 'Никнейм',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark
                                ? theme.colorScheme.outline
                                : Colors.black87,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark
                                ? theme.colorScheme.outline
                                : Colors.black87,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите никнейм';
                        }
                        if (value.trim().length < 3) {
                          return 'Никнейм должен быть не менее 3 символов';
                        }
                        if (value.trim().length > 50) {
                          return 'Никнейм должен быть не более 50 символов';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? theme.colorScheme.outline
                              : Colors.black87,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? theme.colorScheme.outline
                              : Colors.black87,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите email';
                      }
                      if (!value.contains('@')) {
                        return 'Введите корректный email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? theme.colorScheme.outline
                              : Colors.black87,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? theme.colorScheme.outline
                              : Colors.black87,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Введите пароль';
                      }
                      if (value.length < 8) {
                        return 'Пароль должен быть не менее 8 символов';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isRegisterMode ? 'Зарегистрироваться' : 'Войти',
                            style: const TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _toggleMode,
                    child: Text(
                      _isRegisterMode
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _handleGuestLogin,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(
                        color:
                            isDark ? theme.colorScheme.outline : Colors.black87,
                        width: 1.5,
                      ),
                    ),
                    child: const Text(
                      'Войти как гость',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
