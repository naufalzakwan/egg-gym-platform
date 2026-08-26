import 'dart:io';

import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_profile_service.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Avatar besar + ikon pensil untuk upload/edit/hapus foto profil.
///
/// REUSABLE untuk member & trainer (dipakai di member_shell & trainer_shell).
/// Upload/hapus lewat [BackendProfileService] (endpoint reusable
/// `/profile/avatar`), hasilnya disimpan ke session -> semua tempat yang render
/// [InitialAvatar] dengan avatarPath dari session ikut konsisten.
///
/// - Belum ada foto (avatarPath null) -> opsi "Upload Foto".
/// - Sudah ada foto -> opsi "Edit Foto Profil" + "Hapus Foto".
/// [onAvatarChanged] dipanggil setelah berubah agar parent bisa setState
/// (mis. rebuild header shell).
class ProfileAvatarEditor extends StatefulWidget {
  const ProfileAvatarEditor({
    super.key,
    required this.displayName,
    required this.avatarPath,
    this.onAvatarChanged,
    this.radius = 38,
  });

  final String displayName;
  final String? avatarPath;
  final VoidCallback? onAvatarChanged;
  final double radius;

  @override
  State<ProfileAvatarEditor> createState() => _ProfileAvatarEditorState();
}

class _ProfileAvatarEditorState extends State<ProfileAvatarEditor> {
  final BackendProfileService _profileService = BackendProfileService();
  final ImagePicker _picker = ImagePicker();
  bool _isBusy = false;

  bool get _hasAvatar =>
      (widget.avatarPath != null && widget.avatarPath!.trim().isNotEmpty);

  Future<void> _showOptions() async {
    if (_isBusy) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: AppColors.accent),
                title: Text(_hasAvatar ? 'Edit Foto Profil' : 'Upload Foto'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUpload();
                },
              ),
              if (_hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
                  title: const Text('Hapus Foto'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteAvatar();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload() async {
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

    try {
      // Resize + kompres di sisi klien (tanpa package tambahan).
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (picked == null) return;
      if (!mounted) return;

      setState(() => _isBusy = true);
      await _profileService.uploadAvatar(File(picked.path));
      if (!mounted) return;
      widget.onAvatarChanged?.call();
      _snack('Foto profil berhasil diperbarui.');
    } on ProfileApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal memproses foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _isBusy = true);
    try {
      await _profileService.deleteAvatar();
      if (!mounted) return;
      widget.onAvatarChanged?.call();
      _snack('Foto profil dihapus.');
    } on ProfileApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Gagal menghapus foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isBusy ? null : _showOptions,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFFFFD54D), AppColors.accentDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: InitialAvatar(
              name: widget.displayName,
              radius: widget.radius,
              avatarPath: widget.avatarPath,
            ),
          ),
          if (_isBusy)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xAA000000),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.edit_rounded,
                  size: 15, color: Color(0xFF0E0E0E)),
            ),
          ),
        ],
      ),
    );
  }
}
