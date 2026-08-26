import 'dart:io';

import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/core/utils/account_input_validators.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/data/services/backend_trainer_profile_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class TrainerAccountSettingsPage extends StatefulWidget {
  const TrainerAccountSettingsPage({super.key});

  @override
  State<TrainerAccountSettingsPage> createState() =>
      _TrainerAccountSettingsPageState();
}

class _TrainerAccountSettingsPageState
    extends State<TrainerAccountSettingsPage> {
  final BackendTrainerProfileService _service = BackendTrainerProfileService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TrainerProfileData? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDisplayPhotoBusy = false;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final Set<String> _selectedSpecialties = {};
  final _bioController = TextEditingController();
  final _experienceController = TextEditingController();
  final List<TextEditingController> _certificationControllers = [];
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _danaNumberController = TextEditingController();
  final _danaAccountNameController = TextEditingController();
  final _otherPaymentMethodController = TextEditingController();
  final _otherPaymentNumberController = TextEditingController();
  final _otherPaymentAccountNameController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _experienceController.dispose();
    for (final controller in _certificationControllers) {
      controller.dispose();
    }
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _passwordConfirmationController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    _danaNumberController.dispose();
    _danaAccountNameController.dispose();
    _otherPaymentMethodController.dispose();
    _otherPaymentNumberController.dispose();
    _otherPaymentAccountNameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
        _nameController.text = profile.name ?? '';
        _emailController.text = profile.email ?? '';
        _phoneController.text = profile.phone ?? '';
        _selectedSpecialties
          ..clear()
          ..addAll(profile.specialties.isNotEmpty
              ? profile.specialties
              : [
                  if (profile.specialty != null &&
                      profile.specialty!.isNotEmpty)
                    profile.specialty!,
                ]);
        _bioController.text = profile.bio ?? '';
        _experienceController.text = profile.experienceYears?.toString() ?? '';
        _replaceCertificationControllers(profile.certifications);
        _bankNameController.text = profile.bankName ?? '';
        _bankAccountNumberController.text = profile.bankAccountNumber ?? '';
        _bankAccountNameController.text = profile.bankAccountName ?? '';
        _danaNumberController.text = profile.danaNumber ?? '';
        _danaAccountNameController.text = profile.danaAccountName ?? '';
        _otherPaymentMethodController.text = profile.otherPaymentMethod ?? '';
        _otherPaymentNumberController.text = profile.otherPaymentNumber ?? '';
        _otherPaymentAccountNameController.text =
            profile.otherPaymentAccountName ?? '';
        _priceController.text =
            profile.pricePerSession != null && profile.pricePerSession! > 0
                ? profile.pricePerSession!.toInt().toString()
                : '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      await _service.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        specialties: _selectedSpecialties.isEmpty
            ? null
            : _selectedSpecialties.toList(growable: false),
        bio: _bioController.text.trim(),
        experienceYears: _experienceController.text.trim().isEmpty
            ? null
            : int.parse(_experienceController.text.trim()),
        certifications: _certificationControllers
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList(growable: false),
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        newPasswordConfirmation: _passwordConfirmationController.text,
        bankName: _bankNameController.text.trim(),
        bankAccountNumber: _bankAccountNumberController.text.trim(),
        bankAccountName: _bankAccountNameController.text.trim(),
        danaNumber: _danaNumberController.text.trim(),
        danaAccountName: _danaAccountNameController.text.trim(),
        otherPaymentMethod: _otherPaymentMethodController.text.trim(),
        otherPaymentNumber: _otherPaymentNumberController.text.trim(),
        otherPaymentAccountName: _otherPaymentAccountNameController.text.trim(),
        pricePerSession: _priceController.text.trim().isNotEmpty
            ? double.parse(_priceController.text.trim())
            : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDisplayPhoto() async {
    if (_isDisplayPhotoBusy) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.accent),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.image_outlined, color: AppColors.accent),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _isDisplayPhotoBusy = true);
    try {
      await _service.uploadDisplayPhoto(File(picked.path));
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
      _showMessage('Foto tampilan trainer berhasil diperbarui.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDisplayPhotoBusy = false);
    }
  }

  Future<void> _deleteDisplayPhoto() async {
    if (_isDisplayPhotoBusy) return;
    setState(() => _isDisplayPhotoBusy = true);
    try {
      await _service.deleteDisplayPhoto();
      final profile = await _service.getProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
      _showMessage('Foto tampilan trainer berhasil dihapus.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isDisplayPhotoBusy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Coba Lagi', onPressed: _loadProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengaturan Akun',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _settingsCard(
            title: 'Profil Dasar',
            subtitle: 'Kelola identitas akun trainer Anda.',
            icon: Icons.person_outline_rounded,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Nama Trainer',
                hint: 'Nama lengkap trainer',
                validator: AccountInputValidators.fullName,
              ),
              _fieldGap,
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'nama@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              _fieldGap,
              _buildTextField(
                controller: _phoneController,
                label: 'Nomor Telepon',
                hint: 'Contoh: 08123456789',
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                validator: AccountInputValidators.phone,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildReadOnlyValue(
                      label: 'Tier',
                      value: trainerTierDisplay(profile.tier),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildReadOnlyValue(
                      label: 'Status Akun',
                      value: _accountStatusLabel(profile.status),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tier dan status akun hanya dapat diubah oleh admin. Foto profil diubah dengan mengetuk avatar pada halaman Profil Trainer.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _settingsCard(
            title: 'Informasi Profesional',
            subtitle:
                'Informasi ini tampil sebagai profil profesional trainer.',
            icon: Icons.workspace_premium_outlined,
            children: [
              _buildSpecialtyField(),
              _fieldGap,
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                hint:
                    'Contoh: Saya membantu member membangun massa otot dan meningkatkan kebugaran dengan program bertahap.',
                maxLines: 4,
              ),
              _fieldGap,
              _buildTextField(
                controller: _experienceController,
                label: 'Tahun Pengalaman',
                hint: 'Contoh: 3',
                keyboardType: TextInputType.number,
                validator: _experienceValidator,
              ),
              _fieldGap,
              _buildCertificationField(),
            ],
          ),
          const SizedBox(height: 14),
          _buildDisplayPhotoCard(),
          const SizedBox(height: 14),
          _settingsCard(
            title: 'Keamanan Akun',
            subtitle:
                'Kosongkan semua field jika tidak ingin mengganti password.',
            icon: Icons.lock_outline_rounded,
            children: [
              _buildTextField(
                controller: _currentPasswordController,
                label: 'Password Lama',
                hint: 'Masukkan password saat ini',
                obscureText: true,
                validator: _currentPasswordValidator,
              ),
              _fieldGap,
              _buildTextField(
                controller: _newPasswordController,
                label: 'Password Baru',
                hint: 'Minimal 8 karakter',
                obscureText: true,
                validator: _newPasswordValidator,
              ),
              _fieldGap,
              _buildTextField(
                controller: _passwordConfirmationController,
                label: 'Konfirmasi Password Baru',
                hint: 'Ulangi password baru',
                obscureText: true,
                validator: _passwordConfirmationValidator,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _settingsCard(
            title: 'Informasi Pembayaran',
            subtitle: 'Kelola metode transfer yang dapat dipilih member.',
            icon: Icons.account_balance_wallet_outlined,
            children: [
              _paymentSectionLabel('REKENING BANK'),
              const SizedBox(height: 11),
              _buildTextField(
                controller: _bankNameController,
                label: 'Nama Bank',
                hint: 'Contoh: BCA, Mandiri, BRI',
              ),
              _fieldGap,
              _buildTextField(
                controller: _bankAccountNumberController,
                label: 'Nomor Rekening Bank',
                hint: 'Contoh: 1234567890',
                keyboardType: TextInputType.number,
              ),
              _fieldGap,
              _buildTextField(
                controller: _bankAccountNameController,
                label: 'Atas Nama Rekening Bank',
                hint: 'Nama pemilik rekening',
              ),
              const SizedBox(height: 20),
              _paymentSectionLabel('DANA'),
              const SizedBox(height: 11),
              _buildTextField(
                controller: _danaNumberController,
                label: 'Nomor DANA',
                hint: 'Contoh: 08123456789',
                keyboardType: TextInputType.phone,
              ),
              _fieldGap,
              _buildTextField(
                controller: _danaAccountNameController,
                label: 'Atas Nama DANA',
                hint: 'Nama pemilik akun DANA',
              ),
              const SizedBox(height: 20),
              _paymentSectionLabel('PEMBAYARAN LAINNYA'),
              const SizedBox(height: 11),
              _buildTextField(
                controller: _otherPaymentMethodController,
                label: 'Metode Pembayaran Lainnya',
                hint: 'Contoh: GoPay, OVO, atau LinkAja',
                validator: _otherPaymentMethodValidator,
              ),
              _fieldGap,
              _buildTextField(
                controller: _otherPaymentNumberController,
                label: 'Nomor / ID Pembayaran Lainnya',
                hint: 'Nomor telepon atau ID pembayaran',
                validator: _otherPaymentNumberValidator,
              ),
              _fieldGap,
              _buildTextField(
                controller: _otherPaymentAccountNameController,
                label: 'Atas Nama Pembayaran Lainnya',
                hint: 'Nama pemilik akun pembayaran',
                validator: _otherPaymentAccountNameValidator,
              ),
              const SizedBox(height: 20),
              _paymentSectionLabel('HARGA'),
              const SizedBox(height: 11),
              _buildTextField(
                controller: _priceController,
                label: 'Harga per Sesi (Rp)',
                hint: 'Contoh: 150000',
                keyboardType: TextInputType.number,
                validator: _priceValidator,
              ),
              const SizedBox(height: 5),
              const Text(
                'Harga ini ditampilkan ke member saat memilih jumlah sesi PT. Perubahan tidak mengubah payment snapshot booking yang sudah dibuat.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          EggButton.primary(
            label: _isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
            onPressed: _isSaving ? null : _saveChanges,
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: 'Kembali',
            onPressed: _isSaving ? null : () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDisplayPhotoCard() {
    final path = _profile?.displayPhotoPath;
    final url = resolvePublicStorageUrl(path);
    final hasPhoto = path != null && path.trim().isNotEmpty;
    final placeholder = Container(
      color: const Color(0xFF161616),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 44, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text('Belum ada foto tampilan',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );

    return _settingsCard(
      title: 'Foto Tampilan Trainer',
      subtitle:
          'Foto ini ditampilkan kepada member saat memilih personal trainer.',
      icon: Icons.photo_camera_back_outlined,
      children: [
        AspectRatio(
          aspectRatio: 4 / 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (url == null)
                  placeholder
                else
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => placeholder,
                  ),
                if (_isDisplayPhotoBusy)
                  const ColoredBox(
                    color: Color(0x99000000),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isDisplayPhotoBusy ? null : _pickDisplayPhoto,
            icon: const Icon(Icons.upload_rounded),
            label: Text(hasPhoto ? 'Ganti Foto' : 'Upload Foto Trainer'),
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 7),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _isDisplayPhotoBusy ? null : _deleteDisplayPhoto,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus Foto'),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
          ),
        ],
        const SizedBox(height: 7),
        const Text(
          'Foto ini berbeda dari avatar profil. Foto ini digunakan pada card trainer di halaman member.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyValue({required String label, required String value}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      );

  Widget _buildSpecialtyField() {
    return FormField<Set<String>>(
      initialValue: _selectedSpecialties,
      validator: (_) => _selectedSpecialties.isEmpty
          ? 'Pilih minimal satu spesialisasi.'
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Spesialisasi',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final selected = await _showSpecialtySelector();
              if (selected == null || !mounted) return;
              setState(() {
                _selectedSpecialties
                  ..clear()
                  ..addAll(selected);
              });
              field.didChange(Set.of(_selectedSpecialties));
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: field.hasError ? AppColors.error : AppColors.divider,
                ),
              ),
              child: _selectedSpecialties.isEmpty
                  ? const Text('Pilih spesialisasi trainer',
                      style: TextStyle(color: AppColors.textSecondary))
                  : Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: _selectedSpecialties
                          .map((label) => _specialtyChip(label))
                          .toList(growable: false),
                    ),
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 6),
            Text(field.errorText!,
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 7),
          const Text(
            'Ketuk untuk memilih satu atau lebih spesialisasi standar.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _replaceCertificationControllers(List<String> certifications) {
    for (final controller in _certificationControllers) {
      controller.dispose();
    }
    _certificationControllers
      ..clear()
      ..addAll(
        (certifications.isEmpty ? const [''] : certifications)
            .map((value) => TextEditingController(text: value)),
      );
  }

  void _addCertification() {
    if (_certificationControllers.length >= 20) return;
    setState(() => _certificationControllers.add(TextEditingController()));
  }

  void _removeCertification(int index) {
    if (index < 0 || index >= _certificationControllers.length) return;
    setState(() {
      _certificationControllers.removeAt(index).dispose();
      if (_certificationControllers.isEmpty) {
        _certificationControllers.add(TextEditingController());
      }
    });
  }

  Widget _buildCertificationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sertifikasi',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        for (var index = 0;
            index < _certificationControllers.length;
            index++) ...[
          Row(
            key: ValueKey('trainer-certification-$index'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _certificationControllers[index],
                  maxLength: 255,
                  decoration: InputDecoration(
                    hintText: 'Contoh: NASM CPT',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus sertifikasi',
                onPressed: () => _removeCertification(index),
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          if (index < _certificationControllers.length - 1)
            const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              _certificationControllers.length >= 20 ? null : _addCertification,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Tambah Sertifikasi'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tambahkan satu sertifikasi per baris, maksimal 20 item. Input kosong tidak akan disimpan.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _specialtyChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          TrainerSpecialties.isCanonical(label) ? label : '$label (data lama)',
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Future<Set<String>?> _showSpecialtySelector() {
    final temporary = Set<String>.of(_selectedSpecialties);
    final legacy = temporary
        .where((value) => !TrainerSpecialties.isCanonical(value))
        .toList(growable: false);
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.68,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
                  child: Text('Pilih Spesialisasi',
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Text(
                      'Pilih minimal satu. Pilihan dapat lebih dari satu.',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in legacy)
                          FilterChip(
                            label: Text('$value (data lama)'),
                            selected: temporary.contains(value),
                            onSelected: (selected) => setSheetState(() =>
                                selected
                                    ? temporary.add(value)
                                    : temporary.remove(value)),
                          ),
                        for (final option in TrainerSpecialties.options)
                          FilterChip(
                            label: Text(option.label),
                            selected: temporary.contains(option.label),
                            selectedColor:
                                AppColors.accent.withValues(alpha: 0.2),
                            checkmarkColor: AppColors.accent,
                            onSelected: (selected) => setSheetState(() =>
                                selected
                                    ? temporary.add(option.label)
                                    : temporary.remove(option.label)),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: temporary.isEmpty
                              ? null
                              : () => Navigator.pop(
                                  sheetContext, Set<String>.of(temporary)),
                          child: const Text('Simpan Pilihan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentSectionLabel(String label) => Row(
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              )),
        ],
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: obscureText ? 1 : maxLines,
          obscureText: obscureText,
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.surfaceSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  static const SizedBox _fieldGap = SizedBox(height: 14);

  String? _requiredValidator(String? value) =>
      value == null || value.trim().isEmpty ? 'Field ini wajib diisi.' : null;

  String? _emailValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;
    return GetUtils.isEmail(value!.trim()) ? null : 'Format email tidak valid.';
  }

  String? _experienceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Tahun pengalaman harus berupa angka 0 atau lebih.';
    }
    return null;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0 || parsed > 100000000) {
      return 'Harga harus berupa angka antara 0 dan 100.000.000.';
    }
    return null;
  }

  bool get _hasAnyOtherPaymentValue =>
      _otherPaymentMethodController.text.trim().isNotEmpty ||
      _otherPaymentNumberController.text.trim().isNotEmpty ||
      _otherPaymentAccountNameController.text.trim().isNotEmpty;

  String? _otherPaymentMethodValidator(String? value) =>
      _hasAnyOtherPaymentValue && (value == null || value.trim().isEmpty)
          ? 'Metode pembayaran wajib diisi.'
          : null;

  String? _otherPaymentNumberValidator(String? value) =>
      _hasAnyOtherPaymentValue && (value == null || value.trim().isEmpty)
          ? 'Nomor atau ID pembayaran wajib diisi.'
          : null;

  String? _otherPaymentAccountNameValidator(String? value) =>
      _hasAnyOtherPaymentValue && (value == null || value.trim().isEmpty)
          ? 'Atas nama pembayaran wajib diisi.'
          : null;

  String? _currentPasswordValidator(String? value) {
    if (_newPasswordController.text.isNotEmpty &&
        (value == null || value.isEmpty)) {
      return 'Password lama wajib diisi.';
    }
    return null;
  }

  String? _newPasswordValidator(String? value) {
    final password = value ?? '';
    if (password.isEmpty &&
        _currentPasswordController.text.isEmpty &&
        _passwordConfirmationController.text.isEmpty) {
      return null;
    }
    return AccountInputValidators.strongPassword(password);
  }

  String? _passwordConfirmationValidator(String? value) {
    if (_newPasswordController.text.isEmpty &&
        (value == null || value.isEmpty)) {
      return null;
    }
    return AccountInputValidators.confirmation(
      value,
      _newPasswordController.text,
    );
  }

  String _accountStatusLabel(String? status) => switch (status) {
        'active' => 'AKTIF',
        'inactive' => 'NONAKTIF',
        null || '' => '-',
        _ => status.replaceAll('_', ' ').toUpperCase(),
      };
}
