import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EquipmentMovementExerciseSelection {
  const EquipmentMovementExerciseSelection({
    required this.equipment,
    required this.movement,
    required this.sets,
    required this.reps,
  });

  final EquipmentInfo equipment;
  final GymEquipmentMovement movement;
  final int sets;
  final int reps;
}

Future<EquipmentMovementExerciseSelection?> pickEquipmentMovementExercise(
  BuildContext context,
  List<EquipmentInfo> equipments,
) async {
  final source = await showModalBottomSheet<_EquipmentMovementSource>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _EquipmentMovementPicker(equipments: equipments),
  );
  if (source == null || !context.mounted) return null;

  // Let the bottom sheet finish detaching before mounting another input route.
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return null;

  return showDialog<EquipmentMovementExerciseSelection>(
    context: context,
    builder: (_) => _ExerciseSetsRepsDialog(source: source),
  );
}

class _ExerciseSetsRepsDialog extends StatefulWidget {
  const _ExerciseSetsRepsDialog({required this.source});

  final _EquipmentMovementSource source;

  @override
  State<_ExerciseSetsRepsDialog> createState() =>
      _ExerciseSetsRepsDialogState();
}

class _ExerciseSetsRepsDialogState extends State<_ExerciseSetsRepsDialog> {
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _setsController = TextEditingController(text: '3');
    _repsController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _submit() {
    final sets = int.tryParse(_setsController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    if (sets == null || reps == null || sets < 1 || reps < 1) {
      setState(() {
        _validationMessage = 'Sets dan reps wajib berupa angka minimal 1.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(
      EquipmentMovementExerciseSelection(
        equipment: widget.source.equipment,
        movement: widget.source.movement,
        sets: sets,
        reps: reps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Atur Sets dan Reps'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.source.movement.movementName,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 5),
            Text(
              '${widget.source.movement.targetArea} · ${widget.source.equipment.name}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _NumberField(
                  label: 'Sets',
                  fieldKey: const Key('exercise-sets-field'),
                  controller: _setsController,
                  hint: '3',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  label: 'Reps',
                  fieldKey: const Key('exercise-reps-field'),
                  controller: _repsController,
                  hint: '10',
                ),
              ),
            ]),
            if (_validationMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _validationMessage!,
                key: const Key('exercise-sets-reps-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambah Latihan'),
        ),
      ],
    );
  }
}

class _EquipmentMovementSource {
  const _EquipmentMovementSource({
    required this.equipment,
    required this.movement,
  });

  final EquipmentInfo equipment;
  final GymEquipmentMovement movement;
}

class _EquipmentMovementPicker extends StatefulWidget {
  const _EquipmentMovementPicker({required this.equipments});

  final List<EquipmentInfo> equipments;

  @override
  State<_EquipmentMovementPicker> createState() =>
      _EquipmentMovementPickerState();
}

class _EquipmentMovementPickerState extends State<_EquipmentMovementPicker> {
  EquipmentInfo? _selectedEquipment;

  @override
  Widget build(BuildContext context) {
    final equipment = _selectedEquipment;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: ColoredBox(
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                key: const Key('equipment-movement-picker-header'),
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (equipment != null)
                        IconButton(
                          onPressed: () =>
                              setState(() => _selectedEquipment = null),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Expanded(
                        child: Text(
                          equipment == null ? 'Pilih Alat Gym' : equipment.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(
                      equipment == null
                          ? 'Pilih alat terlebih dahulu, lalu pilih gerakan yang tersedia.'
                          : 'Pilih gerakan. Target otot akan terisi otomatis.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: ClipRect(
                  key: const Key('equipment-movement-picker-scroll-viewport'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: equipment == null
                        ? _buildEquipmentList()
                        : _buildMovementList(equipment),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentList() {
    if (widget.equipments.isEmpty) {
      return const _EmptyState(
        icon: Icons.fitness_center_outlined,
        title: 'Belum ada alat gym tersedia',
        message: 'Tambahkan alat gym melalui Web Admin terlebih dahulu.',
      );
    }
    final allEmpty = widget.equipments.every((item) => item.movements.isEmpty);
    return ListView(
      key: const Key('equipment-picker-list'),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      clipBehavior: Clip.hardEdge,
      children: [
        if (allEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _EmptyState(
              icon: Icons.info_outline_rounded,
              title: 'Belum ada gerakan alat gym',
              message:
                  'Isi Gerakan yang Bisa Dilakukan pada menu Alat Gym di Web Admin.',
              compact: true,
            ),
          ),
        ...widget.equipments.map((item) {
          final hasMovements = item.movements.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: hasMovements ? 1 : 0.55,
              child: ListTile(
                onTap: hasMovements
                    ? () => setState(() => _selectedEquipment = item)
                    : null,
                tileColor: AppColors.surfaceSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.accent,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${item.category} · ${item.statusLabel}\n'
                  '${hasMovements ? '${item.movements.length} gerakan tersedia' : 'Belum ada gerakan'}',
                ),
                isThreeLine: true,
                trailing: hasMovements
                    ? const Icon(Icons.chevron_right_rounded)
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMovementList(EquipmentInfo equipment) {
    if (equipment.movements.isEmpty) {
      return const _EmptyState(
        icon: Icons.list_alt_outlined,
        title: 'Alat ini belum memiliki daftar gerakan',
        message: 'Tambahkan gerakan alat melalui Web Admin.',
      );
    }
    return ListView.separated(
      key: const Key('movement-picker-list'),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      clipBehavior: Clip.hardEdge,
      itemCount: equipment.movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final movement = equipment.movements[index];
        return ListTile(
          onTap: () => Navigator.of(context).pop(
            _EquipmentMovementSource(
              equipment: equipment,
              movement: movement,
            ),
          ),
          tileColor: AppColors.surfaceSoft,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: const Icon(
            Icons.directions_run_rounded,
            color: AppColors.accent,
          ),
          title: Text(
            movement.movementName,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Target: ${movement.targetArea}'),
          trailing: const Icon(Icons.chevron_right_rounded),
        );
      },
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.label,
    required this.fieldKey,
    required this.controller,
    required this.hint,
  });

  final String label;
  final Key fieldKey;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase()),
          const SizedBox(height: 8),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 24),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: compact ? 22 : 34),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
}
