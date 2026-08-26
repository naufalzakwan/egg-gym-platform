import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TrainerCountdownDurationSheet extends StatefulWidget {
  const TrainerCountdownDurationSheet({
    super.key,
    required this.presets,
    required this.selectedMinutes,
  });

  final List<int> presets;
  final int selectedMinutes;

  @override
  State<TrainerCountdownDurationSheet> createState() =>
      _TrainerCountdownDurationSheetState();
}

class _TrainerCountdownDurationSheetState
    extends State<TrainerCountdownDurationSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late bool _showCustom;

  @override
  void initState() {
    super.initState();
    _showCustom = !widget.presets.contains(widget.selectedMinutes);
    _controller = TextEditingController(
      text: _showCustom ? widget.selectedMinutes.toString() : '',
    );
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCustomInput() {
    if (!_showCustom) setState(() => _showCustom = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _submitCustom() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final minutes = int.parse(_controller.text.trim());
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(minutes);
  }

  String? _validateMinutes(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null) return 'Masukkan durasi dalam menit.';
    if (minutes < 1 || minutes > 120) {
      return 'Durasi harus antara 1 sampai 120 menit.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.7),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Durasi Countdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ...widget.presets.map(
                        (minutes) => ChoiceChip(
                          label: Text('$minutes menit'),
                          selected:
                              !_showCustom && widget.selectedMinutes == minutes,
                          onSelected: (_) => Navigator.of(context).pop(minutes),
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Atur Sendiri'),
                        selected: _showCustom,
                        onSelected: (_) => _showCustomInput(),
                      ),
                    ],
                  ),
                  if (_showCustom) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('custom-duration-input'),
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Durasi custom',
                        hintText: 'Masukkan durasi dalam menit',
                        suffixText: 'menit',
                        filled: true,
                        fillColor: const Color(0xFF222222),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: _validateMinutes,
                      onFieldSubmitted: (_) => _submitCustom(),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('use-custom-duration'),
                        onPressed: _submitCustom,
                        child: const Text('Gunakan Durasi'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
