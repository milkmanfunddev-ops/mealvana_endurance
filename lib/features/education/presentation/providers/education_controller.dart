import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../application/education_service.dart';
import '../../domain/education_content.dart';

part 'education_controller.g.dart';

@riverpod
class EducationController extends _$EducationController {
  EducationService get _service => ref.read(educationServiceProvider);

  @override
  FutureOr<EducationContentGroups> build() async {
    return _service.getContentGroups();
  }

  /// Pull-to-refresh
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _service.getContentGroups());
  }
}
