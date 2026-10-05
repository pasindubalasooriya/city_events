import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:city_events/register_screen.dart';
import 'package:city_events/services/auth_service.dart';

/// The sign-in screen, and the first thing a signed-out visitor sees.
///
/// It is a StatefulWidget because three things change while it is on screen:
/// what has been typed, whether we are waiting for Firebase, and whether an
/// error needs showing.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// A handle on the Form below, so the button can ask every field to validate
  /// itself in one call.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controllers hold and expose what the user has typed in each field.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();

  /// True while we are waiting for Firebase, so the button can show a spinner
  /// and refuse to be pressed twice.
  bool _isLoading = false;

  /// The message shown above the button, or null when there is nothing wrong.
  String? _errorMessage;

  @override
  void dispose() {
    // Controllers hold resources that are not cleaned up automatically. Not
    // disposing them leaks memory every time this screen is opened and closed.
    // dispose() runs when the screen is permanently removed from the tree.
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validates the form, then asks Firebase to sign the user in.
  ///
  /// On success nothing happens here on purpose: AuthGate is listening to the
  /// auth stream and swaps this screen out for the app by itself.
  Future<void> _signIn() async {
    // validate() runs every field's validator and returns false if any failed.
    // Doing this first means an empty form never reaches the network.
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      // 'mounted' asks "is this screen still on the tree?". After an await the
      // user may have navigated away, and calling setState on a screen that is
      // gone throws. Checking it after every await is the habit to keep.
      if (!mounted) return;
      setState(() => _errorMessage = AuthService.friendlyError(e.code));
    } finally {
      // Runs whether we succeeded or failed, so the spinner can never get
      // stuck on screen.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Opens the register screen on top of this one.
  ///
  /// push() adds a screen to the stack, so Android's back button returns here.
  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          // Scrollable so the form is still reachable when the on-screen
          // keyboard covers half the display on a small phone.
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Stops the form stretching to full width on a tablet or a
              // maximised browser window, where very wide text fields look
              // broken.
              constraints: const BoxConstraints(maxWidth: 400),
              child: _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  /// The heading, the two fields, the error line, and the buttons.
  Widget _buildForm(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.location_city,
              size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'CityEvents',
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Find and share what is happening near you',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _emailController,
            // Gives the phone's keyboard an "@" key instead of a space bar.
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!value.contains('@')) return 'Please enter a valid email';
              return null; // null means this field is acceptable
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            // Replaces the characters with dots as they are typed.
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              // The error colour comes from the theme, so it stays readable in
              // dark mode instead of being a fixed red.
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            // A null onPressed is how Flutter disables a button, so this also
            // blocks a second tap while the first is still in flight.
            onPressed: _isLoading ? null : _signIn,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isLoading ? null : _goToRegister,
            child: const Text('New here? Create an account'),
          ),
        ],
      ),
    );
  }
}
