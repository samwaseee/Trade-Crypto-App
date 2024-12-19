import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void togglePasswordVisibility() {
    setState(() {
      isObscure = !isObscure;
    });
  }

  Future<void> register() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );
      print('User registered with UID: ${userCredential.user?.uid}');

      // Save additional user data to Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
          'name': nameController.text,
          'phone': phoneController.text,
          'email': emailController.text,
          'wallet': 10000,
        });
        print('User data added to Firestore');

        // Display success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registered successfully!')),
        );

        // Navigate back to the login screen
        Navigator.pop(context);
      } catch (e) {
        print('Error adding user to Firestore: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user data: ${e.toString()}')),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double myHeight = MediaQuery.of(context).size.height;
    double myWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(title: Text('Register New Portfolio'), centerTitle: true ,
      backgroundColor: Color(0xffFBC700),),
      body: Container(
        padding: EdgeInsets.all(16.0),
        color: Colors.white, // Light yellowish background color
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'Enter your name',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.white70,
                prefixIcon: Icon(Icons.person, color: Color(0xffFBC700)),
              ),
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            SizedBox(height: myHeight * 0.02),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'Enter your phone number',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.white70,
                prefixIcon: Icon(Icons.phone, color: Color(0xffFBC700)),
              ),
              keyboardType: TextInputType.phone,
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            SizedBox(height: myHeight * 0.02),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'Enter your email',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.white70,
                prefixIcon: Icon(Icons.email, color: Color(0xffFBC700)),
              ),
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            SizedBox(height: myHeight * 0.02),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
                hintText: 'Enter your password',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50.0),
                  borderSide: BorderSide(
                    color: Color(0xffFBC700),
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.white70,
                prefixIcon: Icon(Icons.lock, color: Color(0xffFBC700)),
                suffixIcon: IconButton(
                  onPressed: togglePasswordVisibility,
                  icon: Icon(
                    isObscure ? Icons.visibility_outlined : Icons.visibility_off_rounded,
                    color: Color(0xffFBC700),
                  ),
                ),
              ),
              obscureText: isObscure,
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            Spacer(),
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xffFBC700),
                  foregroundColor: Colors.black,
                ),
                child: Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



