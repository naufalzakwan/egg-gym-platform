import 'package:egg_gym/app/routes/app_routes.dart';
import 'package:egg_gym/data/services/notification_center_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton(
      {super.key, this.color, this.icon = Icons.notifications_none_rounded});
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NotificationCenterService.instance,
        builder: (context, _) {
          final unread = NotificationCenterService.instance.unreadCount;
          return Stack(clipBehavior: Clip.none, children: [
            IconButton(
              tooltip:
                  unread > 0 ? '$unread notifikasi belum dibaca' : 'Notifikasi',
              onPressed: () async {
                await Get.toNamed(AppRoutes.notifications);
                NotificationCenterService.instance.refresh();
              },
              icon: Icon(icon, color: color),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 3,
                child: Container(
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.black, width: 1.5)),
                  alignment: Alignment.center,
                  child: Text(unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        },
      );
}
