import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/core/formatters/app_date_formatter.dart';
import 'package:egg_gym/domain/entities/demo_models.dart';
import 'package:egg_gym/presentation/widgets/common/booking_expiry_countdown.dart';
import 'package:egg_gym/presentation/widgets/common/egg_button.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:flutter/material.dart';

class RescheduleRequestCard extends StatelessWidget {
  const RescheduleRequestCard({
    super.key,
    required this.request,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onExpired,
  });

  final BookingRescheduleRequestData request;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final Future<void> Function()? onExpired;

  @override
  Widget build(BuildContext context) {
    return EggCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.isIncoming
                ? 'Permintaan Reschedule Masuk'
                : 'Menunggu Persetujuan Reschedule',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('Pengaju: ${request.requestedByName}'),
          const SizedBox(height: 6),
          Text(
            'Jadwal lama: ${AppDateFormatter.schedule(dateValue: request.oldDate, startTime: request.oldStartTime, endTime: request.oldEndTime)}',
          ),
          const SizedBox(height: 4),
          Text(
            'Jadwal baru: ${AppDateFormatter.schedule(dateValue: request.proposedDate, startTime: request.proposedStartTime, endTime: request.proposedEndTime)}',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text('Alasan: ${_label(request.reasonType)}'),
          if (request.reasonNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(request.reasonNote!),
          ],
          if (request.expiredAt != null && request.status == 'pending') ...[
            const SizedBox(height: 10),
            BookingExpiryCountdown(
              expiredAt: request.expiredAt,
              label: 'Sisa waktu respon',
              onExpired: onExpired,
            ),
          ],
          if (request.canAccept || request.canReject) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: EggButton.secondary(
                    label: 'Tolak Reschedule',
                    onPressed: onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EggButton.primary(
                    label: 'Terima Reschedule',
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ] else if (request.canCancel && onCancel != null) ...[
            const SizedBox(height: 14),
            EggButton.secondary(
              label: 'Batalkan Permintaan',
              onPressed: onCancel,
            ),
          ],
        ],
      ),
    );
  }

  static String _label(String slug) => slug
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
