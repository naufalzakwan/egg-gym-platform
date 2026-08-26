import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/account_input_validators.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class MemberPersonalInfoPage extends StatefulWidget {
  const MemberPersonalInfoPage({super.key});

  @override
  State<MemberPersonalInfoPage> createState() => _MemberPersonalInfoPageState();
}

class _MemberPersonalInfoPageState extends State<MemberPersonalInfoPage> {
  final BackendMemberService _service = BackendMemberService();

  MemberProfileData? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _notifyProfileUpdated() async {
    final args = Get.arguments;
    if (args is Map && args['onProfileUpdated'] is Future<void> Function()) {
      await (args['onProfileUpdated'] as Future<void> Function())();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  bool get _isComplete {
    final p = _profile;
    if (p == null) return false;
    return (p.heightCm != null && p.heightCm! > 0) &&
        (p.weightKg != null && p.weightKg! > 0) &&
        (p.fitnessGoal != null && p.fitnessGoal!.trim().isNotEmpty);
  }

  Future<void> _openEditSheet() async {
    final profile = _profile;
    if (profile == null) return;

    final heightController = TextEditingController(
      text: profile.heightCm != null && profile.heightCm! > 0
          ? profile.heightCm!.toStringAsFixed(0)
          : '',
    );
    final weightController = TextEditingController(
      text: profile.weightKg != null && profile.weightKg! > 0
          ? profile.weightKg!.toStringAsFixed(0)
          : '',
    );
    final goalController = TextEditingController(
      text: profile.fitnessGoal ?? '',
    );
    final medicalController = TextEditingController(
      text: profile.medicalNote ?? '',
    );
    // Gender ('male'/'female') & tanggal lahir dikelola sebagai state lokal
    // karena tidak berupa TextField biasa.
    String? selectedGender = profile.gender;
    DateTime? selectedBirthDate =
        (profile.birthDate != null && profile.birthDate!.isNotEmpty)
            ? DateTime.tryParse(profile.birthDate!)
            : null;
    final formKey = GlobalKey<FormState>();

    await Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lengkapi Data Kebugaran',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tinggi badan, berat badan, dan target latihan wajib diisi sebelum kamu bisa booking PT. Catatan medis opsional.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 18),
                    // Jenis kelamin
                    Text(
                      'Jenis Kelamin',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _GenderOption(
                            label: 'Laki-laki',
                            icon: Icons.male_rounded,
                            selected: selectedGender == 'male',
                            onTap: () =>
                                setSheetState(() => selectedGender = 'male'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _GenderOption(
                            label: 'Perempuan',
                            icon: Icons.female_rounded,
                            selected: selectedGender == 'female',
                            onTap: () =>
                                setSheetState(() => selectedGender = 'female'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Tanggal lahir (untuk menghitung usia)
                    Text(
                      'Tanggal Lahir',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedBirthDate ??
                              DateTime(now.year - 20, now.month, now.day),
                          firstDate: DateTime(1940),
                          lastDate: now,
                          helpText: 'Pilih Tanggal Lahir',
                        );
                        if (picked != null) {
                          setSheetState(() => selectedBirthDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_outlined,
                                size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedBirthDate != null
                                    ? '${_formatBirthDate(selectedBirthDate!)}  (${_ageFrom(selectedBirthDate!)} tahun)'
                                    : 'Pilih tanggal lahir',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: selectedBirthDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded,
                                size: 16, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: heightController,
                      label: 'Tinggi Badan (cm)',
                      hint: 'Contoh: 170',
                      keyboardType: TextInputType.number,
                      validator: (v) => _numberValidator(v, 'Tinggi badan'),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: weightController,
                      label: 'Berat Badan (kg)',
                      hint: 'Contoh: 65',
                      keyboardType: TextInputType.number,
                      validator: (v) => _numberValidator(v, 'Berat badan'),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: goalController,
                      label: 'Target / Goal Latihan',
                      hint: 'Contoh: Turun berat badan, bulking, dll',
                      keyboardType: TextInputType.text,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Target/goal wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: medicalController,
                      label: 'Catatan Medis (opsional)',
                      hint: 'Contoh: Riwayat cedera lutut, asma, dll',
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.primary(
                        label: _isSaving ? 'Menyimpan...' : 'Simpan Data',
                        onPressed: _isSaving
                            ? () {}
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                if (selectedGender == null) {
                                  Get.snackbar(
                                    'Lengkapi Data',
                                    'Jenis kelamin wajib dipilih.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.surface,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                if (selectedBirthDate == null) {
                                  Get.snackbar(
                                    'Lengkapi Data',
                                    'Tanggal lahir wajib dipilih.',
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: AppColors.surface,
                                    colorText: AppColors.textPrimary,
                                  );
                                  return;
                                }
                                setSheetState(() {});
                                await _saveProfile(
                                  gender: selectedGender,
                                  birthDate: _isoDate(selectedBirthDate!),
                                  heightCm: double.tryParse(
                                      heightController.text.trim()),
                                  weightKg: double.tryParse(
                                      weightController.text.trim()),
                                  fitnessGoal: goalController.text.trim(),
                                  medicalNote:
                                      medicalController.text.trim().isEmpty
                                          ? null
                                          : medicalController.text.trim(),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  String? _numberValidator(String? value, String field) {
    if (value == null || value.trim().isEmpty) {
      return '$field wajib diisi.';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return '$field harus berupa angka lebih dari 0.';
    }
    return null;
  }

  String _isoDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  int _ageFrom(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
  }

  Future<void> _saveProfile({
    String? phone,
    String? gender,
    String? birthDate,
    double? heightCm,
    double? weightKg,
    String? fitnessGoal,
    String? medicalNote,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _isSaving = true);

    try {
      // Backend mewajibkan name & phone; kirim nilai form terbaru (fallback ke
      // nilai profil saat ini bila field tidak diubah).
      final updated = await _service.updateProfile(
        name: profile.name,
        phone: phone ?? profile.phone ?? '',
        gender: gender ?? profile.gender,
        birthDate: birthDate ?? profile.birthDate,
        heightCm: heightCm,
        weightKg: weightKg,
        fitnessGoal: fitnessGoal,
        medicalNote: medicalNote,
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _isSaving = false;
      });

      Get.back(); // tutup bottom sheet
      await _notifyProfileUpdated();
      if (!mounted) return;
      Get.snackbar(
        'Tersimpan',
        'Data kebugaran berhasil diperbarui.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
  }

  Future<void> _openIdentitySheet() async {
    final profile = _profile;
    if (profile == null) return;

    final nameController = TextEditingController(text: profile.name);
    final emailController = TextEditingController(text: profile.email);
    final phoneController = TextEditingController(text: profile.phone ?? '');
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;

    await Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Identitas Akun',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Perbarui nama, email, dan nomor telepon. Ubah password bila perlu — kosongkan bagian password jika tidak ingin menggantinya.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _buildField(
                      controller: nameController,
                      label: 'Nama Lengkap',
                      hint: 'Nama lengkap kamu',
                      keyboardType: TextInputType.name,
                      validator: AccountInputValidators.fullName,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: emailController,
                      label: 'Email',
                      hint: 'nama@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Email wajib diisi.';
                        if (!GetUtils.isEmail(value)) {
                          return 'Format email tidak valid.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      controller: phoneController,
                      label: 'Nomor Telepon',
                      hint: 'Contoh: 08123456789',
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(15),
                      ],
                      validator: AccountInputValidators.phone,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ubah Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Isi hanya jika ingin mengganti password.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(
                      controller: currentPassController,
                      label: 'Password Lama',
                      obscure: obscureCurrent,
                      onToggle: () =>
                          setSheetState(() => obscureCurrent = !obscureCurrent),
                    ),
                    const SizedBox(height: 14),
                    _buildPasswordField(
                      controller: newPassController,
                      label: 'Password Baru',
                      obscure: obscureNew,
                      onToggle: () =>
                          setSheetState(() => obscureNew = !obscureNew),
                      validator: (value) =>
                          AccountInputValidators.strongPassword(
                        value,
                        required: currentPassController.text.isNotEmpty ||
                            confirmPassController.text.isNotEmpty,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPasswordField(
                      controller: confirmPassController,
                      label: 'Konfirmasi Password Baru',
                      obscure: obscureConfirm,
                      onToggle: () =>
                          setSheetState(() => obscureConfirm = !obscureConfirm),
                      validator: (value) => AccountInputValidators.confirmation(
                        value,
                        newPassController.text,
                        required: newPassController.text.isNotEmpty ||
                            currentPassController.text.isNotEmpty,
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: EggButton.primary(
                        label: _isSaving ? 'Menyimpan...' : 'Simpan Data',
                        onPressed: _isSaving
                            ? () {}
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                final newPass = newPassController.text;
                                final currentPass = currentPassController.text;
                                final confirmPass = confirmPassController.text;
                                final wantChangePassword = newPass.isNotEmpty ||
                                    currentPass.isNotEmpty ||
                                    confirmPass.isNotEmpty;

                                if (wantChangePassword) {
                                  if (currentPass.isEmpty) {
                                    _warn(
                                        'Password lama wajib diisi untuk mengubah password.');
                                    return;
                                  }
                                }

                                setSheetState(() {});
                                await _saveIdentity(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  currentPassword:
                                      wantChangePassword ? currentPass : null,
                                  newPassword:
                                      wantChangePassword ? newPass : null,
                                  newPasswordConfirmation:
                                      wantChangePassword ? confirmPass : null,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  void _warn(String message) {
    Get.snackbar(
      'Lengkapi Data',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.surface,
      colorText: AppColors.textPrimary,
    );
  }

  Future<void> _saveIdentity({
    required String name,
    required String email,
    required String phone,
    String? currentPassword,
    String? newPassword,
    String? newPasswordConfirmation,
  }) async {
    final profile = _profile;
    if (profile == null) return;

    setState(() => _isSaving = true);

    try {
      // Kirim ulang data fisik saat ini agar tidak ter-reset oleh backend
      // (endpoint update menimpa seluruh field profil member).
      final updated = await _service.updateProfile(
        name: name,
        email: email,
        phone: phone,
        gender: profile.gender,
        birthDate: profile.birthDate,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        fitnessGoal: profile.fitnessGoal,
        medicalNote: profile.medicalNote,
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );

      if (!mounted) return;
      setState(() {
        _profile = updated;
        _isSaving = false;
      });

      Get.back(); // tutup bottom sheet, kembali ke halaman utama Profil
      await _notifyProfileUpdated();
      if (!mounted) return;
      final changedPassword = newPassword != null && newPassword.isNotEmpty;
      Get.snackbar(
        'Tersimpan',
        changedPassword
            ? 'Identitas akun & password berhasil diperbarui. Gunakan kredensial baru untuk login berikutnya.'
            : 'Identitas akun berhasil diperbarui.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      Get.snackbar(
        'Gagal',
        e.toString().replaceAll('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    }
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
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Gagal memuat profil.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            EggButton.secondary(label: 'Coba Lagi', onPressed: _loadProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;
    final heightText = profile.heightCm != null && profile.heightCm! > 0
        ? '${profile.heightCm!.toStringAsFixed(0)} cm'
        : 'Belum diisi';
    final weightText = profile.weightKg != null && profile.weightKg! > 0
        ? '${profile.weightKg!.toStringAsFixed(0)} kg'
        : 'Belum diisi';
    final goalText =
        (profile.fitnessGoal != null && profile.fitnessGoal!.trim().isNotEmpty)
            ? profile.fitnessGoal!
            : 'Belum diisi';
    final genderText = switch (profile.gender) {
      'male' => 'Laki-laki',
      'female' => 'Perempuan',
      _ => 'Belum diisi',
    };
    final birthDate =
        (profile.birthDate != null && profile.birthDate!.isNotEmpty)
            ? DateTime.tryParse(profile.birthDate!)
            : null;
    final ageText =
        birthDate != null ? '${_ageFrom(birthDate)} tahun' : 'Belum diisi';

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadProfile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Data Pribadi',
            subtitle:
                'Identitas member dan data kebugaran yang tersinkron dengan akun kamu.',
          ),
          const SizedBox(height: 20),
          EggCard(
            highlight: true,
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD54D), AppColors.accentDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const StatusChip(
                          label: 'MEMBER PROFILE', color: AppColors.background),
                      StatusChip(
                        label: _isComplete
                            ? 'PROFIL LENGKAP'
                            : 'PROFIL BELUM LENGKAP',
                        color: AppColors.background,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.background,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.background.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ),
            ),
          ),
          if (!_isComplete) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lengkapi tinggi badan, berat badan, dan target latihan agar bisa mengajukan booking ke trainer.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                            height: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoMetricCard(label: 'HEIGHT', value: heightText),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InfoMetricCard(label: 'WEIGHT', value: weightText),
              ),
            ],
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Identitas Akun',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openIdentitySheet,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Nama lengkap', value: profile.name),
                const SizedBox(height: 10),
                _InfoRow(label: 'Email', value: profile.email),
                const SizedBox(height: 10),
                _InfoRow(
                    label: 'Nomor telepon',
                    value: profile.phone ?? 'Belum diisi'),
                const SizedBox(height: 10),
                _InfoRow(
                    label: 'Nomor anggota', value: profile.memberCode ?? '-'),
                const SizedBox(height: 10),
                _InfoRow(
                    label: 'Tier aktif',
                    value: profile.membershipTier ?? 'Member Status'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Data Kebugaran',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openEditSheet,
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(label: 'Jenis kelamin', value: genderText),
                const SizedBox(height: 10),
                _InfoRow(label: 'Usia', value: ageText),
                const SizedBox(height: 10),
                _InfoRow(label: 'Tinggi badan', value: heightText),
                const SizedBox(height: 10),
                _InfoRow(label: 'Berat badan', value: weightText),
                const SizedBox(height: 10),
                _InfoRow(label: 'Target / Goal', value: goalText),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Catatan medis',
                  value: (profile.medicalNote != null &&
                          profile.medicalNote!.trim().isNotEmpty)
                      ? profile.medicalNote!
                      : '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          validator: validator,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: '••••••••',
            filled: true,
            fillColor: AppColors.surfaceSoft,
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggle,
            ),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          maxLines: maxLines,
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
}

class _InfoMetricCard extends StatelessWidget {
  const _InfoMetricCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.accent : AppColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
