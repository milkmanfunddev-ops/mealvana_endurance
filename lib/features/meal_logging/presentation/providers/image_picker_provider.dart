import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// The photo picker Log a Meal's Describe tab uses. A provider so widget
/// tests can answer `pickImage` with null, a throw or a file (ticket 60).
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());
