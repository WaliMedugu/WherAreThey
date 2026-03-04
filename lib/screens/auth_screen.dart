import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import 'package:universal_html/html.dart' as html;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isSignUp = false;
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      if (_isSignUp) {
        final res = await supabase.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'full_name': _emailController.text.split('@')[0]}, // Default name from email
        );
        if (mounted) {
          if (res.session != null) {
            context.go('/');
            html.window.location.reload();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Success! Please check your email for confirmation.")),
            );
          }
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        if (mounted) {
          context.go('/');
          html.window.location.reload();
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left side: Branding/Illustration (Visible on desktop)
          if (MediaQuery.of(context).size.width > 800)
            Expanded(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF8A7650), Color(0xFF8E977D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Right side: Auth Form
          Expanded(
            flex: 1,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (MediaQuery.of(context).size.width <= 800) ...[
                          Center(
                            child: ClipOval(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 100,
                                  minHeight: 100,
                                  maxWidth: 160,
                                  maxHeight: 160,
                                ),
                                child: Image.asset(
                                  'assets/logo.png',
                                  width: MediaQuery.of(context).size.width * 0.3,
                                  height: MediaQuery.of(context).size.width * 0.3,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        Text(
                          _isSignUp ? "Create Account" : "Welcome Back",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8A7650),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSignUp 
                            ? "Join Nigeria's search community." 
                            : "Login to manage your reports.",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 32),
                        
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: "Email Address",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.alternate_email),
                          ),
                          validator: (val) => val == null || !val.contains('@') ? "Enter a valid email" : null,
                        ),
                        
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (val) => val == null || val.length < 6 ? "Password too short" : null,
                        ),
                        
                        if (_isSignUp) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Confirm Password",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_reset),
                            ),
                            validator: (val) {
                              if (val != _passwordController.text) return "Passwords do not match";
                              return null;
                            },
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8A7650),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(_isSignUp ? "Sign Up" : "Sign In"),
                        ),
                        
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() => _isSignUp = !_isSignUp),
                          child: Text(_isSignUp 
                            ? "Already have an account? Sign In" 
                            : "Don't have an account? Sign Up"),
                        ),
                        
                        if (!_isSignUp)
                          TextButton(
                            onPressed: () {},
                            child: const Text("Forgot Password?"),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
