/// What a reverse lookup says about a pair of coordinates.
///
/// Only what the app reads. Optional, because a reverse lookup can land
/// anywhere from a house to a county, and a county has no postcode.
class ReversePlace {
  const ReversePlace({this.postcode});

  final String? postcode;
}
