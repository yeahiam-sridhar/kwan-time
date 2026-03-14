// Riverpod providers for invitation join flow.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/invite_service.dart';

final inviteServiceProvider = Provider<InviteService>(
  (ref) => InviteService(),
);
