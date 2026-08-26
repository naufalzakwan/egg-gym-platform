import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overview previews two checkpoints and exposes conditional View All',
      () {
    final source = File(
      'lib/presentation/pages/details/member_physical_progress_page.dart',
    ).readAsStringSync();

    expect(source, contains('newestHistory.take(2)'));
    expect(source, contains('if (newestHistory.length > 2)'));
    expect(source, contains("child: const Text('View All')"));
    expect(source, contains('AppRoutes.memberAllCheckpoints'));
    expect(source, contains('class MemberAllCheckpointsPage'));
  });

  test('View All route is registered', () {
    final routes = File('lib/app/routes/app_routes.dart').readAsStringSync();
    final pages = File('lib/app/routes/app_pages.dart').readAsStringSync();

    expect(routes, contains('memberAllCheckpoints'));
    expect(pages, contains('name: AppRoutes.memberAllCheckpoints'));
  });
}
