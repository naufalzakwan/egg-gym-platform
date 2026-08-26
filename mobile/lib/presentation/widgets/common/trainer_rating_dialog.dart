import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Popup "Beri Rating Trainer" yang muncul setelah program 100% selesai.
///
/// Bintang 1-5 wajib diisi, testimoni opsional. Mengembalikan `true` lewat
/// [Get.back] bila rating berhasil dikirim ke backend.
class TrainerRatingDialog extends StatefulWidget {
  const TrainerRatingDialog({
    super.key,
    required this.trainingProgramId,
    required this.trainerName,
  });

  final int trainingProgramId;
  final String trainerName;

  /// Tampilkan dialog. Return `true` bila rating berhasil terkirim.
  static Future<bool?> show({
    required int trainingProgramId,
    required String trainerName,
  }) {
    return Get.dialog<bool>(
      TrainerRatingDialog(
        trainingProgramId: trainingProgramId,
        trainerName: trainerName,
      ),
      barrierDismissible: false,
    );
  }

  @override
  State<TrainerRatingDialog> createState() => _TrainerRatingDialogState();
}

class _TrainerRatingDialogState extends State<TrainerRatingDialog> {
  final BackendRatingService _service = BackendRatingService();
  final TextEditingController _testimonialController = TextEditingController();

  int _rating = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _testimonialController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (_rating < 1) {
      setState(() =>
          _errorMessage = 'Silakan pilih rating bintang terlebih dahulu.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _service.submitRating(
        trainingProgramId: widget.trainingProgramId,
        rating: _rating,
        testimonial: _testimonialController.text,
      );

      if (!mounted) return;
      Get.back(result: true);
      Get.snackbar(
        'Terima Kasih',
        'Rating kamu untuk ${widget.trainerName} berhasil dikirim.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.surface,
        colorText: AppColors.textPrimary,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 44, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              'Beri Rating Trainer',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Program latihanmu bersama ${widget.trainerName} sudah selesai. Bagaimana pengalamanmu?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 20),
            // Bintang 1-5 (wajib)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final star = index + 1;
                final filled = star <= _rating;
                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _rating = star;
                            _errorMessage = null;
                          }),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: filled ? AppColors.accent : AppColors.textSecondary,
                  ),
                  splashRadius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 4),
              Text(
                _ratingLabel(_rating),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            const SizedBox(height: 18),
            // Testimoni (opsional)
            TextField(
              controller: _testimonialController,
              maxLines: 4,
              maxLength: 1000,
              enabled: !_isSubmitting,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Tulis testimoni / komentar (opsional)',
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
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            EggButton.primary(
              label: _isSubmitting ? 'Mengirim...' : 'Kirim Rating',
              onPressed: _isSubmitting ? () {} : _submit,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSubmitting ? null : () => Get.back(result: false),
              child: Text(
                'Nanti Saja',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Sangat Kurang';
      case 2:
        return 'Kurang';
      case 3:
        return 'Cukup';
      case 4:
        return 'Bagus';
      case 5:
        return 'Sangat Bagus';
      default:
        return '';
    }
  }
}
