import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/core/constants/trainer_specialties.dart';
import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/presentation/widgets/common/brand_logo.dart';
import 'package:egg_gym/core/utils/public_storage_url.dart';
import 'package:egg_gym/core/utils/trainer_tier.dart';
import 'package:egg_gym/core/utils/trainer_rating_display.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GuestTrainerTabV2 extends StatefulWidget {
  const GuestTrainerTabV2({
    super.key,
    required this.trainers,
    required this.isLoading,
    required this.onRetry,
  });

  final List<TrainerProfile> trainers;
  final bool isLoading;
  final Future<void> Function() onRetry;

  @override
  State<GuestTrainerTabV2> createState() => _GuestTrainerTabV2State();
}

class _GuestTrainerTabV2State extends State<GuestTrainerTabV2> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedSpecialty;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TrainerProfile> get _filteredTrainers {
    final query = _query.trim().toLowerCase();
    return widget.trainers.where((trainer) {
      final specialties = trainer.specialtyLabels
          .map(TrainerSpecialties.displayLabel)
          .toList(growable: false);
      if (_selectedSpecialty != null &&
          !specialties.contains(_selectedSpecialty)) {
        return false;
      }
      if (query.isEmpty) return true;
      return trainer.name.toLowerCase().contains(query) ||
          specialties.any((item) => item.toLowerCase().contains(query));
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTrainers;
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: widget.onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          const _TrainerGuestHeader(),
          const SizedBox(height: 28),
          const Text(
            'PERSONAL TRAINERS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 29,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Temukan pelatih profesional yang siap membantumu mencapai target kebugaran maksimal.',
            style: TextStyle(
              color: Color(0xFFBFB6A1),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cari spesialisasi atau nama trainer...',
              hintStyle:
                  const TextStyle(color: Color(0xFF727272), fontSize: 12),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF8B805A),
                size: 21,
              ),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF302E28)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF302E28)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _SpecialtyFilterChip(
                  label: 'Semua',
                  selected: _selectedSpecialty == null,
                  onTap: () => setState(() => _selectedSpecialty = null),
                ),
                ...TrainerSpecialties.popularLabels.map(
                  (label) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _SpecialtyFilterChip(
                      label: label,
                      selected: _selectedSpecialty == label,
                      onTap: () => setState(() => _selectedSpecialty = label),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (widget.isLoading && widget.trainers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (filtered.isEmpty)
            _TrainerEmptyState(
              filtered: widget.trainers.isNotEmpty,
              onRetry: widget.onRetry,
            )
          else
            ...filtered.map(
              (trainer) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _GuestTrainerDirectoryCard(trainer: trainer),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerGuestHeader extends StatelessWidget {
  const _TrainerGuestHeader();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: BrandLogo(compact: true, showTagline: false)),
          FilledButton(
            onPressed: () => Get.offAllNamed(AppRoutes.login),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
              minimumSize: const Size(80, 40),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text('Masuk',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      );
}

class _SpecialtyFilterChip extends StatelessWidget {
  const _SpecialtyFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.accent : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
            child: Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppColors.background : const Color(0xFFD0D0D0),
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
}

class _GuestTrainerDirectoryCard extends StatelessWidget {
  const _GuestTrainerDirectoryCard({required this.trainer});
  final TrainerProfile trainer;

  @override
  Widget build(BuildContext context) {
    final photoUrl = resolvePublicStorageUrl(
      trainer.displayPhotoPath ?? trainer.avatarUrl,
    );
    final specialties = trainer.specialtyLabels
        .map(TrainerSpecialties.displayLabel)
        .where((item) => item != '-' && item.trim().isNotEmpty)
        .toList(growable: false);
    final bio = trainer.bio.trim().isEmpty || trainer.bio.trim() == '-'
        ? 'Belum ada bio trainer.'
        : trainer.bio.trim();
    final tierLabel = trainerTierLabel(trainer.tier);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF292929),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1E1E1E),
                  border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF6E5D12), width: 2),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: photoUrl == null
                    ? _TrainerInitial(name: trainer.name)
                    : Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _TrainerInitial(name: trainer.name),
                      ),
              ),
              if (tierLabel != null)
                Positioned(
                  right: -10,
                  bottom: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tierLabel,
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            trainer.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 4),
              Text(
                trainerRatingDisplay(
                  rating: trainer.rating,
                  reviewsCount: trainer.reviewsCount,
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 7,
              runSpacing: 7,
              children: specialties
                  .map((label) => _TrainerSpecialtyTag(label: label))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 15),
          Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFC0B8A6),
              fontSize: 11,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 17),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => Get.toNamed(
                AppRoutes.trainerProfileDetail,
                arguments: {'trainer': trainer, 'source': 'guest'},
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: const Text(
                'LIHAT PROFIL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerInitial extends StatelessWidget {
  const _TrainerInitial({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TrainerSpecialtyTag extends StatelessWidget {
  const _TrainerSpecialtyTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF323229),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.accent,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _TrainerEmptyState extends StatelessWidget {
  const _TrainerEmptyState({required this.filtered, required this.onRetry});
  final bool filtered;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        decoration: BoxDecoration(
          color: const Color(0xFF191919),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF252525)),
        ),
        child: Column(
          children: [
            const Icon(Icons.person_search_rounded,
                color: Color(0xFF777777), size: 38),
            const SizedBox(height: 10),
            Text(
              filtered
                  ? 'Trainer tidak ditemukan untuk filter ini.'
                  : 'Belum ada trainer tersedia.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 12),
            ),
            if (!filtered) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ],
        ),
      );
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty);
  final result = parts.take(2).map((item) => item[0].toUpperCase()).join();
  return result.isEmpty ? '?' : result;
}
