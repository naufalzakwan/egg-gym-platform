import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_member_service.dart';
import 'package:egg_gym/data/services/backend_rating_service.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/initial_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef MemberRatingSubmitCallback = Future<void> Function({
  required int trainingProgramId,
  required int rating,
  String? testimonial,
});

class MemberTrainerRatingPage extends StatefulWidget {
  const MemberTrainerRatingPage({
    super.key,
    required this.program,
    this.submitRating,
  });

  final MemberProgramData program;
  final MemberRatingSubmitCallback? submitRating;

  @override
  State<MemberTrainerRatingPage> createState() =>
      _MemberTrainerRatingPageState();
}

class _MemberTrainerRatingPageState extends State<MemberTrainerRatingPage> {
  final TextEditingController _testimonialController = TextEditingController();
  late final BackendRatingService _ratingService = BackendRatingService();

  int _rating = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _testimonialController.dispose();
    super.dispose();
  }

  String? get _trainerPhotoPath {
    return widget.program.displayPhotoPath ?? widget.program.trainerAvatarUrl;
  }

  String? get _completionDate {
    return widget.program.lastSessionDate ??
        widget.program.completedAt ??
        widget.program.endedAt;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_rating == 0) {
      setState(() => _errorMessage = 'Pilih rating bintang terlebih dahulu.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final submitRating = widget.submitRating ?? _ratingService.submitRating;
      await submitRating(
        trainingProgramId: widget.program.id,
        rating: _rating,
        testimonial: _testimonialController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerName = widget.program.trainerName ?? '';
    final completionDate = _completionDate;
    final duration = widget.program.lastSessionDurationMinutes;

    return Scaffold(
      key: const Key('member-trainer-rating-page'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('rating-back-button'),
                  tooltip: 'Kembali',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Program Selesai',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Beri Rating Trainer',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bagikan pengalamanmu setelah menyelesaikan program ini.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 28),
                    Center(
                      child: InitialAvatar(
                        name: trainerName,
                        radius: 46,
                        avatarPath: _trainerPhotoPath,
                      ),
                    ),
                    if (trainerName.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        trainerName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.program.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (completionDate != null ||
                              (duration != null && duration > 0)) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                if (completionDate != null)
                                  _ProgramMeta(
                                    icon: Icons.calendar_today_rounded,
                                    label:
                                        AppDateFormatter.date(completionDate),
                                  ),
                                if (duration != null && duration > 0)
                                  _ProgramMeta(
                                    icon: Icons.schedule_rounded,
                                    label: '$duration menit',
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Rating kamu',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          key: Key('rating-star-$value'),
                          tooltip: '$value bintang',
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                    _rating = value;
                                    _errorMessage = null;
                                  }),
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            value <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 42,
                            color: value <= _rating
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const Key('rating-testimonial-field'),
                      controller: _testimonialController,
                      enabled: !_isSubmitting,
                      maxLength: 1000,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      minLines: 4,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Testimoni (opsional)',
                        hintText: 'Ceritakan pengalaman latihanmu',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _errorMessage!,
                        key: const Key('rating-error-message'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    EggButton.primary(
                      key: const Key('submit-rating-button'),
                      label: _isSubmitting ? 'Mengirim...' : 'Kirim Rating',
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('rating-later-button'),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Nanti Saja'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgramMeta extends StatelessWidget {
  const _ProgramMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
