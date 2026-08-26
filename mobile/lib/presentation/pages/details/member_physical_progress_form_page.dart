import 'dart:io';

import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/utils/physical_progress_navigation.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/detail_screen_header.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

class MemberPhysicalProgressFormPage extends StatefulWidget {
  const MemberPhysicalProgressFormPage({super.key});

  @override
  State<MemberPhysicalProgressFormPage> createState() =>
      _MemberPhysicalProgressFormPageState();
}

class _MemberPhysicalProgressFormPageState
    extends State<MemberPhysicalProgressFormPage> {
  final BackendMemberService _service = BackendMemberService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _noteController;
  var _isMilestone = false;
  bool _isSubmitting = false;

  // Foto per-pose (Front/Side/Back). Semua opsional.
  static const List<String> _poses = ['Front', 'Side', 'Back'];
  final Map<String, File> _photos = {};

  @override
  void initState() {
    super.initState();
    // Field kosong (bukan hardcode) - member isi sendiri.
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(String pose) async {
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
            const SizedBox(height: 16),
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

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _photos[pose] = File(picked.path));
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitCheckpoint() async {
    if (_isSubmitting) return;

    final weight =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    final height =
        double.tryParse(_heightController.text.trim().replaceAll(',', '.'));

    if (weight == null || weight <= 0) {
      _snack('Berat badan wajib diisi dengan angka yang valid.');
      return;
    }
    if (height == null || height <= 0) {
      _snack('Tinggi badan wajib diisi dengan angka yang valid.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final now = DateTime.now();
      final recordedAt =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await _service.createPhysicalProgress(
        weightKg: weight,
        heightCm: height,
        recordedAt: recordedAt,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        isMilestone: _isMilestone,
        photosByPose: Map<String, File>.from(_photos),
      );
      if (!mounted) return;
      _snack('Checkpoint berhasil disimpan.');
      if (shouldOpenPhysicalProgressOverviewAfterSave(Get.arguments)) {
        // Form dibuka langsung dari card Profil saat belum ada checkpoint.
        // Replace form dengan Overview; back berikutnya kembali ke Profil.
        await Get.offNamed(AppRoutes.memberPhysicalProgress);
      } else {
        // Form dibuka dari Overview: pop true agar Overview existing refetch.
        Get.back(result: true);
      }
    } on MemberApiException catch (e) {
      _snack(e.toString().replaceAll('MemberApiException: ', ''));
    } catch (_) {
      _snack('Gagal menyimpan checkpoint. Pastikan backend aktif.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedScreen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const DetailScreenHeader(
            title: 'Form Checkpoint',
            subtitle:
                'Catat satu checkpoint fisik baru: berat, tinggi, foto pose, dan catatan.',
          ),
          const SizedBox(height: 18),
          // Foto per pose.
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foto Checkpoint (opsional)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tambahkan foto pose depan/samping/belakang untuk perbandingan.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _poses.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: _buildPhotoSlot(_poses[i])),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Data fisik.
          EggCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Fisik',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Berat badan (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tinggi badan (cm)',
                    prefixIcon: Icon(Icons.height_rounded),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _noteController,
                  minLines: 4,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Catatan progres (opsional)',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 56),
                      child: Icon(Icons.sticky_note_2_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  value: _isMilestone,
                  onChanged: _isSubmitting
                      ? null
                      : (value) => setState(() => _isMilestone = value),
                  activeColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tandai sebagai milestone'),
                  subtitle: const Text(
                    'Milestone tampil lebih menonjol di histori progress.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          EggButton.primary(
            label: _isSubmitting ? 'Menyimpan...' : 'Simpan Checkpoint',
            onPressed: _isSubmitting ? () {} : _submitCheckpoint,
          ),
          const SizedBox(height: 10),
          EggButton.secondary(
            label: 'Kembali ke Progress',
            onPressed: () => Get.back(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoSlot(String pose) {
    final file = _photos[pose];
    return GestureDetector(
      onTap: _isSubmitting ? null : () => _pickPhoto(pose),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 110,
              width: double.infinity,
              color: AppColors.surfaceSoft,
              child: file != null
                  ? Image.file(file, fit: BoxFit.cover)
                  : const Center(
                      child: Icon(Icons.add_a_photo_outlined,
                          size: 28, color: AppColors.accent),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pose,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      file != null ? AppColors.accent : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
