import 'package:egg_gym/data/services/backend_public_service.dart';
import 'package:egg_gym/data/services/public_settings_service.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/pages/guest/guest_home_tab_v2.dart';
import 'package:egg_gym/presentation/pages/guest/guest_membership_tab_v2.dart';
import 'package:egg_gym/presentation/pages/guest/guest_profile_tab_v2.dart';
import 'package:egg_gym/presentation/pages/guest/guest_program_tab_v2.dart';
import 'package:egg_gym/presentation/pages/guest/guest_trainer_tab_v2.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class GuestShellPageV2 extends StatefulWidget {
  const GuestShellPageV2({super.key});

  @override
  State<GuestShellPageV2> createState() => _GuestShellPageV2State();
}

class _GuestShellPageV2State extends State<GuestShellPageV2> {
  int _currentIndex = 0;
  GuestShowcaseData _homeShowcase = const GuestShowcaseData(
    plans: [],
    trainers: [],
    equipments: [],
    operationHours: [],
  );
  final BackendPublicService _publicService = BackendPublicService();
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadLiveShowcase();
  }

  Future<void> _loadLiveShowcase() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await PublicSettingsService.instance.refresh();
    } catch (_) {
      // Cached/default settings remain authoritative while offline.
    }
    final errors = <String>[];
    var plans = _homeShowcase.plans;
    var trainers = _homeShowcase.trainers;
    var equipments = _homeShowcase.equipments;
    var operationHours = _homeShowcase.operationHours;

    try {
      plans = await _publicService.getMembershipPlans();
    } catch (_) {
      errors.add('paket membership');
    }
    try {
      trainers = await _publicService.getTrainers();
    } catch (_) {
      errors.add('personal trainer');
    }
    try {
      equipments = await _publicService.getEquipments();
    } catch (_) {
      errors.add('alat gym');
    }
    try {
      operationHours = await _publicService.getOperationHours();
    } catch (_) {
      errors.add('jam operasional');
    }
    if (!mounted) return;
    setState(() {
      _homeShowcase = GuestShowcaseData(
        plans: plans,
        trainers: trainers,
        equipments: equipments,
        operationHours: operationHours,
      );
      _loadError = errors.isEmpty
          ? null
          : 'Sebagian data belum dapat dimuat: ${errors.join(', ')}.';
      _isLoading = false;
    });
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 3) _loadLiveShowcase();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      GuestHomeTabV2(
        showcase: _homeShowcase,
        isLoading: _isLoading,
        loadError: _loadError,
        onRetry: _loadLiveShowcase,
      ),
      GuestProgramTabV2(
        onOpenMembership: () => _selectTab(3),
      ),
      GuestTrainerTabV2(
        trainers: _homeShowcase.trainers,
        isLoading: _isLoading,
        onRetry: _loadLiveShowcase,
      ),
      GuestMembershipTabV2(
        plans: _homeShowcase.plans,
        isLoading: _isLoading,
        loadError: _loadError,
        onRetry: _loadLiveShowcase,
      ),
      const GuestProfileTabV2(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: tabs,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_outline_rounded),
            label: 'Program',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_search_rounded),
            label: 'Trainer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_rounded),
            label: 'Membership',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
