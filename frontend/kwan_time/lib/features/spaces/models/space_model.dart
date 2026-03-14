import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import '../services/role_permission_service.dart';

enum SpaceType {
  family,
  personal,
  relationship,
  work,
  friends,
  shiftSchedule,
  lessons,
  schoolEvents,
  group,
  hobbies,
  other,
}

enum SpaceStorageType { local, shared }

class SpaceModel extends Equatable {
  final String id;
  final String name;
  final SpaceType type;
  final SpaceStorageType storageType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Canonical: members map, not arrays.
  final Map<String, String> members; // uid -> "admin"|"member"|"viewer"
  final SpaceMeta meta;

  final String? description;
  final String colorHex;
  final String iconName;
  final bool openJoin;
  final bool allowComments;

  const SpaceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.storageType,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.members,
    required this.meta,
    required this.colorHex,
    required this.iconName,
    this.description,
    this.openJoin = false,
    this.allowComments = true,
  });

  factory SpaceModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? const {};
    final settings = d['settings'] as Map<String, dynamic>? ?? const {};

    final String createdBy =
        (d['createdBy'] as String?) ?? (d['ownerId'] as String?) ?? '';

    Map<String, String> members = Map<String, String>.from(
      d['members'] as Map? ?? const {},
    );

    if (members.isEmpty) {
      // Backward compat: convert roles arrays -> members map.
      final roles = d['roles'] as Map<String, dynamic>? ?? const {};
      final admins = List<String>.from(roles['admins'] as List? ?? const []);
      final memberIds = List<String>.from(roles['members'] as List? ?? const []);
      final viewerIds = List<String>.from(roles['viewers'] as List? ?? const []);

      members = <String, String>{};
      for (final uid in admins) {
        members[uid] = 'admin';
      }
      for (final uid in memberIds) {
        members[uid] = 'member';
      }
      for (final uid in viewerIds) {
        members[uid] = 'viewer';
      }
    }

    if (createdBy.isNotEmpty && !members.containsKey(createdBy)) {
      members[createdBy] = 'admin';
    }

    final meta = SpaceMeta.fromMap(d['meta'] as Map<String, dynamic>? ?? const {});

    return SpaceModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      type: SpaceType.values.firstWhere(
        (e) => e.name == d['type'],
        orElse: () => SpaceType.other,
      ),
      storageType: SpaceStorageType.shared,
      createdBy: createdBy,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      members: members,
      meta: meta,
      description: d['description'] as String?,
      colorHex: d['colorHex'] as String? ?? '1565C0',
      iconName: d['iconName'] as String? ?? 'calendar_today',
      openJoin: settings['openJoin'] as bool? ?? false,
      allowComments: settings['allowComments'] as bool? ?? true,
    );
  }

  factory SpaceModel.fromMap(Map<String, dynamic> m) {
    return SpaceModel(
      id: m['id'] as String,
      name: m['name'] as String,
      type: SpaceType.values.firstWhere(
        (e) => e.name == m['type'],
        orElse: () => SpaceType.other,
      ),
      storageType: SpaceStorageType.local,
      createdBy: 'local',
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(m['createdAt'] as int),
      members: const {},
      meta: const SpaceMeta(),
      description: m['description'] as String?,
      colorHex: m['colorHex'] as String? ?? '1565C0',
      iconName: m['iconName'] as String? ?? 'calendar_today',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'type': type.name,
        'storageType': storageType.name,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'members': members,
        'meta': meta.toMap(),
        'description': description,
        'colorHex': colorHex,
        'iconName': iconName,
        'settings': {
          'openJoin': openJoin,
          'allowComments': allowComments,
        },
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'createdBy': createdBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'description': description,
        'colorHex': colorHex,
        'iconName': iconName,
      };

  // Back-compat: old code used ownerId.
  String get ownerId => createdBy;

  // Helpers (canonical members map)
  SpaceRole roleOfOrNone(String uid) => SpaceRoleX.fromString(members[uid]);

  SpaceRole? roleOf(String uid) {
    final role = roleOfOrNone(uid);
    return role == SpaceRole.none ? null : role;
  }

  bool isMember(String uid) => members.containsKey(uid);

  int get memberCount => members.length;

  List<String> get adminIds => members.entries
      .where((e) => e.value == 'admin')
      .map((e) => e.key)
      .toList();

  List<String> get memberIds => members.entries
      .where((e) => e.value == 'member')
      .map((e) => e.key)
      .toList();

  List<String> get viewerIds => members.entries
      .where((e) => e.value == 'viewer')
      .map((e) => e.key)
      .toList();

  SpaceModel copyWith({
    String? name,
    String? description,
    bool? openJoin,
    bool? allowComments,
  }) {
    return SpaceModel(
      id: id,
      name: name ?? this.name,
      type: type,
      storageType: storageType,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      members: members,
      meta: meta,
      description: description ?? this.description,
      colorHex: colorHex,
      iconName: iconName,
      openJoin: openJoin ?? this.openJoin,
      allowComments: allowComments ?? this.allowComments,
    );
  }

  @override
  List<Object?> get props => [id, name, members, updatedAt];

  factory SpaceModel.empty() => SpaceModel(
        id: '',
        name: '',
        type: SpaceType.other,
        storageType: SpaceStorageType.shared,
        createdBy: '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        members: const {},
        meta: const SpaceMeta(),
        description: '',
        colorHex: '1565C0',
        iconName: 'calendar_today',
      );
}

class SpaceMeta extends Equatable {
  final int eventCount;
  final int memberCount;
  final DateTime? lastActivityAt;

  const SpaceMeta({
    this.eventCount = 0,
    this.memberCount = 0,
    this.lastActivityAt,
  });

  factory SpaceMeta.fromMap(Map<String, dynamic> m) => SpaceMeta(
        eventCount: (m['eventCount'] as num?)?.toInt() ?? 0,
        memberCount: (m['memberCount'] as num?)?.toInt() ??
            (m['totalMembers'] as num?)?.toInt() ??
            0,
        lastActivityAt: (m['lastActivityAt'] as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'eventCount': eventCount,
        'memberCount': memberCount,
        'lastActivityAt':
            lastActivityAt != null ? Timestamp.fromDate(lastActivityAt!) : null,
      };

  @override
  List<Object?> get props => [eventCount, memberCount, lastActivityAt];
}

class SpaceTypeConfig {
  final SpaceType type;
  final String title;
  final String description;
  final String icon;
  final String gradientStart;
  final String gradientEnd;

  const SpaceTypeConfig({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientStart,
    required this.gradientEnd,
  });
}

const List<SpaceTypeConfig> kSpaceTypes = [
  SpaceTypeConfig(
    type: SpaceType.family,
    title: 'Family',
    description: 'See the whole family schedule at a glance.',
    icon: 'home',
    gradientStart: '1565C0',
    gradientEnd: '0288D1',
  ),
  SpaceTypeConfig(
    type: SpaceType.personal,
    title: 'Personal',
    description: 'Your private timeline for personal plans.',
    icon: 'person',
    gradientStart: '2E7D32',
    gradientEnd: '00ACC1',
  ),
  SpaceTypeConfig(
    type: SpaceType.relationship,
    title: 'Relationship',
    description: 'Plan meaningful time together.',
    icon: 'favorite',
    gradientStart: 'C62828',
    gradientEnd: 'E91E63',
  ),
  SpaceTypeConfig(
    type: SpaceType.work,
    title: 'Work',
    description: 'Meetings, deadlines, and commitments.',
    icon: 'work',
    gradientStart: '0D1B3E',
    gradientEnd: '1565C0',
  ),
  SpaceTypeConfig(
    type: SpaceType.friends,
    title: 'Friends',
    description: 'Coordinate social plans.',
    icon: 'group',
    gradientStart: 'F57F17',
    gradientEnd: 'F9A825',
  ),
  SpaceTypeConfig(
    type: SpaceType.shiftSchedule,
    title: 'Shift Schedule',
    description: 'Organize rotating shifts.',
    icon: 'schedule',
    gradientStart: '4527A0',
    gradientEnd: '7B1FA2',
  ),
  SpaceTypeConfig(
    type: SpaceType.lessons,
    title: 'Lessons',
    description: 'Classes, lectures, study sessions.',
    icon: 'menu_book',
    gradientStart: '00695C',
    gradientEnd: '26A69A',
  ),
  SpaceTypeConfig(
    type: SpaceType.schoolEvents,
    title: 'School Events',
    description: 'Academic events and activities.',
    icon: 'school',
    gradientStart: '1B5E20',
    gradientEnd: '43A047',
  ),
  SpaceTypeConfig(
    type: SpaceType.group,
    title: 'Group',
    description: 'Clubs and organizations.',
    icon: 'groups',
    gradientStart: '0277BD',
    gradientEnd: '039BE5',
  ),
  SpaceTypeConfig(
    type: SpaceType.hobbies,
    title: 'Hobbies',
    description: 'Time for passions and projects.',
    icon: 'palette',
    gradientStart: 'AD1457',
    gradientEnd: 'E91E63',
  ),
  SpaceTypeConfig(
    type: SpaceType.other,
    title: 'Other',
    description: 'Create a custom calendar.',
    icon: 'add_circle',
    gradientStart: '37474F',
    gradientEnd: '546E7A',
  ),
];
