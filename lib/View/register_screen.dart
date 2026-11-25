import 'package:material_ui/material_ui.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_crypto/View/navBar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isObscure = true;
  bool _isRegistering = false;
  String? _emailError;
  String? _passwordError;

  void togglePasswordVisibility() {
    setState(() {
      isObscure = !isObscure;
    });
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();

    if (name.isEmpty || name.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a valid name (up to 100 characters).')),
      );
      return;
    }

    if (phone.length > 30) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Phone number cannot exceed 30 characters.')),
      );
      return;
    }

    final email = emailController.text.trim();
    final password = passwordController.text;
    final emailError = email.isEmpty
        ? 'Enter your email address.'
        : (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
            ? 'Enter a valid email address.'
            : null);
    final passwordError = password.isEmpty
        ? 'Enter a password.'
        : (password.length < 6 ? 'Use at least 6 characters.' : null);
    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    if (emailError != null || passwordError != null) return;

    setState(() => _isRegistering = true);
    UserCredential? userCredential;
    try {
      userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional user data to Firestore
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'email': userCredential.user!.email!,
          'wallet': 10000,
        });

        if (!mounted) return;

        // Display success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered successfully!')),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const NavBar()),
          (_) => false,
        );
      } catch (e) {
        try {
          await userCredential.user?.delete();
        } catch (_) {}

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: ${e.toString()}')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'An account already exists for that email.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Choose a stronger password.',
        'operation-not-allowed' => 'Email and password sign-up is unavailable.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        _ => 'Could not create your account. Please try again.',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Portfolio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
                prefixIcon: Icon(Icons.person_outline),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _emailError,
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_emailError != null) setState(() => _emailError = null);
              },
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: togglePasswordVisibility,
                  icon: Icon(
                    isObscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                errorText: _passwordError,
              ),
              obscureText: isObscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_passwordError != null) {
                  setState(() => _passwordError = null);
                }
              },
              onSubmitted: (_) => _isRegistering ? null : register(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isRegistering ? null : register,
              child: _isRegistering
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
