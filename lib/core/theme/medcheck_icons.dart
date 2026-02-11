import 'package:flutter/widgets.dart';

class MedCheckIcons {
  MedCheckIcons._();

  static const String _fontFamily = 'medcheck-icons';

  // Today tab - calendar check
  static const IconData calendarCheckDuotone = IconData(0xFCBB, fontFamily: _fontFamily);
  static const IconData calendarCheckFill = IconData(0xFC76, fontFamily: _fontFamily);

  // Interactions tab - warning diamond
  static const IconData warningDiamond = IconData(0x10113, fontFamily: _fontFamily);
  static const IconData warningDiamondFill = IconData(0xFC36, fontFamily: _fontFamily);

  // Progress tab - chart bar
  static const IconData chartBar = IconData(0xF0FE, fontFamily: _fontFamily);
  static const IconData chartBarFill = IconData(0xF025, fontFamily: _fontFamily);

  // Treatment tab - first aid kit
  static const IconData firstAidKit = IconData(0xFB11, fontFamily: _fontFamily);
  static const IconData firstAidKitFill = IconData(0xFF5E, fontFamily: _fontFamily);
}
