import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/space_event_model.dart';
import '../models/space_model.dart';
import '../providers/space_calendar_provider.dart';
import '../providers/space_providers.dart';
import '../services/role_permission_service.dart';
import '../widgets/space_calendar_view.dart';
import '../widgets/space_event_detail_sheet.dart';
import '../widgets/space_event_form.dart';
import '../widgets/space_event_list.dart';
import '../widgets/space_management_menu.dart';

class SpaceDetailScreen extends ConsumerStatefulWidget {
  const SpaceDetailScreen({super.key, required this.space});

  final SpaceModel space;

  @override
  ConsumerState<SpaceDetailScreen> createState() => _SpaceDetailScreenState();
}

class _SpaceDetailScreenState extends ConsumerState<SpaceDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedSpaceIdProvider.notifier).state = widget.space.id;
      ref.read(spaceSelectedDateProvider.notifier).state = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final role = uid.isEmpty
        ? SpaceRole.none
        : ref.watch(spaceRoleProvider(widget.space.id));
    final perm = ref.read(rolePermissionServiceProvider);
    final canWrite = perm.canCreateEvent(role);

    final liveSpace = ref
            .watch(spaceListProvider)
            .valueOrNull
            ?.firstWhere(
              (s) => s.id == widget.space.id,
              orElse: () => widget.space,
            ) ??
        widget.space;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B3E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B3E),
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              liveSpace.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              role.label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          SpaceManagementMenu(space: liveSpace),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SpaceCalendarView(spaceId: widget.space.id),
          ),
          SliverToBoxAdapter(
            child: SpaceEventList(
              spaceId: widget.space.id,
              userRole: role,
              onEventTap: (event) => _openEventDetail(context, event, liveSpace),
              onDeleteTap: (event) => unawaited(_deleteEvent(event)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateEvent(context),
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Event',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  void _openCreateEvent(BuildContext context) {
    final selected = ref.read(spaceSelectedDateProvider);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SpaceEventForm(
          space: widget.space,
          initialDate: selected,
        ),
      ),
    );
  }

  void _openEventDetail(
    BuildContext context,
    SpaceEvent event,
    SpaceModel space,
  ) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SpaceEventDetailSheet(event: event, space: space),
      ),
    );
  }

  Future<void> _deleteEvent(SpaceEvent event) async {
    final svc = ref.read(eventServiceProvider);
    await svc.deleteEvent(widget.space.id, event.id);
  }
}
