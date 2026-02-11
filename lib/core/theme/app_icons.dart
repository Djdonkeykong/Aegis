import 'package:flutter/widgets.dart';

class AppIcons {
  AppIcons._();

  static const String _fontFamily = 'snaplook-icons';
  static const String _heartOutlineFamily = 'snaplook-heart-outline';

  // Home tab
  static const IconData homeOutline = IconData(0xe902, fontFamily: _fontFamily);
  static const IconData homeFilled = IconData(0xe903, fontFamily: _fontFamily);

  // Check tab (heart)
  static const IconData heartOutline = IconData(0xe901, fontFamily: _heartOutlineFamily);
  static const IconData heartFilled = IconData(0xe901, fontFamily: _fontFamily);

  // Profile tab
  static const IconData profileOutline = IconData(0xe900, fontFamily: _fontFamily);
  static const IconData profileFilled = IconData(0xe905, fontFamily: _fontFamily);
}
