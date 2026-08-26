import 'package:egg_gym/core/theme/app_colors.dart';
import 'package:egg_gym/data/services/backend_notification_service.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:egg_gym/presentation/widgets/common/decorated_screen.dart';
import 'package:egg_gym/presentation/widgets/common/egg_card.dart';
import 'package:egg_gym/presentation/widgets/common/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});
  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final center = NotificationCenterService.instance;

  @override
  void initState() {
    super.initState();
    center.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => center.refresh());
  }

  @override
  void dispose() {
    center.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => DecoratedScreen(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              IconButton(
                  onPressed: Get.back,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Notifikasi',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    if (center.unreadCount > 0)
                      Text('${center.unreadCount} belum dibaca',
                          style: const TextStyle(
                              color: AppColors.accent, fontSize: 12)),
                  ])),
              if (center.unreadCount > 0)
                TextButton(
                    onPressed:
                        center.markingAllRead ? null : center.markAllRead,
                    child: const Text('Tandai semua dibaca')),
              IconButton(
                  onPressed: center.refresh,
                  icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          Expanded(
              child: center.loading && center.items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : center.error != null && center.items.isEmpty
                      ? Center(
                          child:
                              Text(center.error!, textAlign: TextAlign.center))
                      : center.items.isEmpty
                          ? const Center(
                              child: Text('Belum ada notifikasi',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)))
                          : RefreshIndicator(
                              onRefresh: center.refresh,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 32),
                                itemCount: center.items.length,
                                itemBuilder: (context, index) =>
                                    _NotificationTile(
                                        notification: center.items[index],
                                        onTap: () =>
                                            center.open(center.items[index])),
                              ),
                            )),
        ]),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: !notification.isRead
                ? BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(26),
                  )
                : null,
            child: EggCard(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: notification.priority == 'high'
                            ? Colors.red.withValues(alpha: .15)
                            : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(notification.typeIcon,
                        style: const TextStyle(fontSize: 18))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(notification.title,
                                style: TextStyle(
                                    fontWeight: notification.isRead
                                        ? FontWeight.w500
                                        : FontWeight.w800))),
                        if (!notification.isRead)
                          const Text('BARU',
                              style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900))
                      ]),
                      const SizedBox(height: 4),
                      Text(notification.message,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4)),
                      const SizedBox(height: 7),
                      Row(children: [
                        StatusChip(
                            label: notification.priority == 'high'
                                ? 'PENTING'
                                : notification.type.toUpperCase(),
                            color: notification.priority == 'high'
                                ? Colors.red
                                : AppColors.accent),
                        const Spacer(),
                        Text(notification.timeLabel,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 10))
                      ]),
                    ])),
              ]),
            ),
          ),
        ),
      );
}
