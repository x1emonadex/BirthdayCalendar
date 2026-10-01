import 'package:birthday_calendar/core/providers/database_provider.dart';
import 'package:birthday_calendar/features/profiles/data/profile_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(appDatabaseProvider)),
);

/// Текущий профиль. В v1 UI профилей нет — это всегда «Мой список».
final FutureProvider<Profile> currentProfileProvider = FutureProvider<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).ensureDefaultProfile(),
);
