import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_crypto/View/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isEditing = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  User? user;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      fetchUserData();
    }
  }

  Future<void> fetchUserData() async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    setState(() {
      userData = doc.data() as Map<String, dynamic>?;
      if (userData != null) {
        nameController.text = userData!['name'];
        phoneController.text = userData!['phone'];
        emailController.text = userData!['email'];
      }
    });
  }

  Future<void> updateProfile() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': nameController.text,
        'phone': phoneController.text,
        'email': emailController.text,
      });
      setState(() {
        isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile updated successfully!')));
      fetchUserData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update profile: ${e.toString()}')));
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=> WelcomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (isEditing) {
                updateProfile();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
          SizedBox(width: 8),
        ],
      ),
      body: userData == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${userData!['email']}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            isEditing
                ? TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            )
                : Text('Name: ${userData!['name']}', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            isEditing
                ? TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            )
                : Text('Phone: ${userData!['phone']}', style: TextStyle(fontSize: 18)),
            Expanded(child: Container()),
            if(!isEditing)
            ElevatedButton(onPressed: logout,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text('Log Out', style: TextStyle(color: Colors.white)),),
          ],
        ),
      ),
    );
  }
}
