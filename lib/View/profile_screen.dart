import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import 'package:my_crypto/View/welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  User? _user;
  Map<String, dynamic>? _userData;
  File? _avatarFile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isPickingAvatar = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<File?> _avatarFileFor(String uid) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}profile_avatar_$uid.jpg',
    );
    return await file.exists() ? file : null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _user = null;
          _userData = null;
          _avatarFile = null;
          _isLoading = false;
        });
        return;
      }

      final document = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = document.data();
      final avatar = await _avatarFileFor(user.uid);
      if (!mounted) return;
      setState(() {
        _user = user;
        _userData = data;
        _avatarFile = avatar;
        _nameController.text = data?['name'] as String? ?? '';
        _phoneController.text = data?['phone'] as String? ?? '';
      });
    } catch (error) {
      debugPrint('Profile load failed: $error');
      if (mounted) setState(() => _loadError = 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_isPickingAvatar || _user == null) return;
    setState(() => _isPickingAvatar = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (image == null) return;

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}'
        'profile_avatar_${_user!.uid}.jpg',
      );
      await file.writeAsBytes(await image.readAsBytes(), flush: true);
      await FileImage(file).evict();
      if (!mounted) return;
      setState(() => _avatarFile = file);
      _showMessage('Profile photo updated on this device.');
    } catch (error) {
      debugPrint('Profile photo selection failed: $error');
      if (mounted) _showMessage('Could not update your profile photo.');
    } finally {
      if (mounted) setState(() => _isPickingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final user = _user;
    final avatar = _avatarFile;
    if (user == null || avatar == null) return;
    try {
      await avatar.delete();
      await FileImage(avatar).evict();
      if (!mounted) return;
      setState(() => _avatarFile = null);
      _showMessage('Profile photo removed.');
    } catch (error) {
      debugPrint('Profile photo removal failed: $error');
      if (mounted) _showMessage('Could not remove your profile photo.');
    }
  }

  Future<void> _updateProfile() async {
    final user = _user;
    if (user == null || _isSaving) return;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || name.length > 100) {
      _showMessage('Enter a name between 1 and 100 characters.');
      return;
    }
    if (phone.length > 30) {
      _showMessage('Phone number must be 30 characters or fewer.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': name,
        'phone': phone,
      });
      if (!mounted) return;
      setState(() {
        _userData = {...?_userData, 'name': name, 'phone': phone};
        _isEditing = false;
      });
      _showMessage('Profile saved.');
    } catch (error) {
      debugPrint('Profile update failed: $error');
      if (mounted) _showMessage('Could not save your profile. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancelEditing() {
    _nameController.text = _userData?['name'] as String? ?? '';
    _phoneController.text = _userData?['phone'] as String? ?? '';
    setState(() => _isEditing = false);
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      debugPrint('Profile sign-out failed: $error');
      if (mounted) _showMessage('Could not log out. Please try again.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionTitle(String title, ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  Widget _readOnlyTile({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
  }) =>
      ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(label, style: theme.textTheme.bodySmall),
        subtitle: Text(
          value.isEmpty ? 'Not provided' : value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _editField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: label == 'Name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          onChanged: label == 'Name' ? (_) => setState(() {}) : null,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            counterText: '',
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isLoading && _userData != null)
            if (_isEditing) ...[
              TextButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: const Text('Cancel'),
              ),
              IconButton(
                tooltip: 'Save profile',
                onPressed: _isSaving ? null : _updateProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
              ),
            ] else
              IconButton(
                tooltip: 'Edit profile',
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined),
              ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 44),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _loadProfile,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : _userData == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Sign in to view your profile.',
                          style: textTheme.titleMedium,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProfile,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  colors.primaryContainer,
                                  colors.secondaryContainer,
                                ],
                              ),
                            ),
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 48,
                                      backgroundColor: colors.surface,
                                      backgroundImage: _avatarFile == null
                                          ? null
                                          : FileImage(_avatarFile!),
                                      child: _avatarFile == null
                                          ? Icon(
                                              Icons.person_rounded,
                                              size: 54,
                                              color: colors.primary,
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Material(
                                        color: colors.primary,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: _isPickingAvatar
                                              ? null
                                              : _pickAvatar,
                                          child: Padding(
                                            padding: const EdgeInsets.all(9),
                                            child: _isPickingAvatar
                                                ? SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: colors.onPrimary,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.add_a_photo_outlined,
                                                    size: 18,
                                                    color: colors.onPrimary,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _nameController.text.isEmpty
                                      ? 'Your profile'
                                      : _nameController.text,
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['email'] as String? ??
                                      _user?.email ??
                                      '',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        colors.surface.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Text(
                                    'DEMO ACCOUNT',
                                    style: textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                                if (_avatarFile != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _removeAvatar,
                                    icon: const Icon(Icons.delete_outline),
                                    label: const Text('Remove photo'),
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          colors.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet_outlined,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Demo cash balance',
                                          style: textTheme.bodySmall?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '\$${((_userData?['wallet'] as num?) ?? 0).toStringAsFixed(2)}',
                                          style: textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.trending_up_rounded,
                                    color: colors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _sectionTitle('Personal information', theme),
                          Card(
                            margin: EdgeInsets.zero,
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                if (_isEditing)
                                  _editField(
                                    label: 'Name',
                                    controller: _nameController,
                                    icon: Icons.person_outline,
                                    maxLength: 100,
                                  )
                                else
                                  _readOnlyTile(
                                    icon: Icons.person_outline,
                                    label: 'Name',
                                    value: _userData?['name'] as String? ?? '',
                                    theme: theme,
                                  ),
                                Divider(
                                  height: 1,
                                  indent: 64,
                                  color: colors.outlineVariant,
                                ),
                                if (_isEditing)
                                  _editField(
                                    label: 'Phone number',
                                    controller: _phoneController,
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    maxLength: 30,
                                  )
                                else
                                  _readOnlyTile(
                                    icon: Icons.phone_outlined,
                                    label: 'Phone number',
                                    value: _userData?['phone'] as String? ?? '',
                                    theme: theme,
                                  ),
                                Divider(
                                  height: 1,
                                  indent: 64,
                                  color: colors.outlineVariant,
                                ),
                                _readOnlyTile(
                                  icon: Icons.email_outlined,
                                  label: 'Email address',
                                  value: _userData?['email'] as String? ??
                                      _user?.email ??
                                      '',
                                  theme: theme,
                                ),
                              ],
                            ),
                          ),
                          _sectionTitle('Account', theme),
                          Card(
                            margin: EdgeInsets.zero,
                            child: ListTile(
                              leading: Icon(
                                Icons.privacy_tip_outlined,
                                color: colors.primary,
                              ),
                              title: const Text('Private profile photo'),
                              subtitle: const Text(
                                'Your photo is stored only on this device.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          OutlinedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.error,
                              side: BorderSide(
                                color: colors.error.withValues(alpha: 0.6),
                              ),
                              minimumSize: const Size.fromHeight(54),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
