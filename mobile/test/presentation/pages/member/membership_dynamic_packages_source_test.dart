import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Member package list starts empty and refreshes from public API', () {
    final source = File(
      'lib/presentation/pages/member/member_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains('List<MembershipPlan> _plans = const'));
    expect(source, isNot(contains('_plans = repo.getMembershipPlans()')));
    expect(source, isNot(contains('repo.getMembershipPlans()')));
    expect(source,
        contains('final plans = await _publicService.getMembershipPlans()'));
    expect(source, contains('if (index == 3)'));
    expect(source, contains('_reloadTab(index);'));
    expect(source, contains('onRefreshPlans: _loadPlansData'));
    expect(source, contains('onRefresh: _refreshMembershipTab'));
    expect(source, contains('widget.onRefreshPlans()'));
    expect(source, isNot(contains('_availablePlans')));
    expect(source, contains('..._displayPlans.map('));
  });

  test('Guest refetches public data when Membership tab is selected', () {
    final source = File(
      'lib/presentation/pages/guest/guest_shell_page_v2.dart',
    ).readAsStringSync();

    expect(source, contains('if (index == 3) _loadLiveShowcase();'));
    expect(source, contains('onOpenMembership: () => _selectTab(3)'));
    expect(source, contains('onTap: _selectTab'));

    final membershipSource = File(
      'lib/presentation/pages/guest/guest_membership_tab_v2.dart',
    ).readAsStringSync();
    expect(membershipSource, contains('onRefresh: onRetry'));
  });
}
