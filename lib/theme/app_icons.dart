import 'package:flutter/widgets.dart';

import 'package:lucide_icons_flutter/lucide_icons_400.dart';

/// Icon set for the whole app: Lucide at weight 400, which is the 2px-stroke
/// build of the family. Screens never reach into the package directly, so the
/// stroke weight is decided in exactly one place.
abstract final class AppIcons {
  // Transfer.
  static const IconData send = LucideIcons400.arrowUpRight;
  static const IconData receive = LucideIcons400.arrowDownLeft;
  static const IconData hotspot = LucideIcons400.radioTower;
  static const IconData wifi = LucideIcons400.wifi;
  static const IconData link = LucideIcons400.link;
  static const IconData unlink = LucideIcons400.unlink;
  static const IconData zap = LucideIcons400.zap;
  static const IconData device = LucideIcons400.monitorSmartphone;
  static const IconData phone = LucideIcons400.smartphone;

  // Pairing.
  static const IconData scan = LucideIcons400.scanQrCode;
  static const IconData qr = LucideIcons400.qrCode;
  static const IconData copy = LucideIcons400.copy;
  static const IconData paste = LucideIcons400.clipboardPaste;
  static const IconData address = LucideIcons400.keyboard;

  // Files.
  static const IconData folder = LucideIcons400.folder;
  static const IconData folderOpen = LucideIcons400.folderOpen;
  static const IconData add = LucideIcons400.plus;
  static const IconData addCircle = LucideIcons400.circlePlus;
  static const IconData download = LucideIcons400.download;
  static const IconData inbox = LucideIcons400.inbox;
  static const IconData trash = LucideIcons400.trash2;
  static const IconData image = LucideIcons400.image;
  static const IconData video = LucideIcons400.video;
  static const IconData music = LucideIcons400.music;
  static const IconData fileText = LucideIcons400.fileText;

  // Navigation and chrome.
  static const IconData home = LucideIcons400.house;
  static const IconData history = LucideIcons400.history;
  static const IconData settings = LucideIcons400.settings;
  static const IconData back = LucideIcons400.arrowLeft;
  static const IconData forward = LucideIcons400.arrowRight;
  static const IconData chevronRight = LucideIcons400.chevronRight;
  static const IconData close = LucideIcons400.x;
  static const IconData refresh = LucideIcons400.refreshCw;

  // State.
  static const IconData check = LucideIcons400.check;
  static const IconData checkCircle = LucideIcons400.circleCheck;
  static const IconData stop = LucideIcons400.square;
  static const IconData alert = LucideIcons400.triangleAlert;
  static const IconData info = LucideIcons400.info;
  static const IconData radar = LucideIcons400.radar;
  static const IconData search = LucideIcons400.search;
  static const IconData cameraOff = LucideIcons400.cameraOff;

  // Appearance.
  static const IconData sun = LucideIcons400.sun;
  static const IconData moon = LucideIcons400.moon;
  static const IconData auto = LucideIcons400.sunMoon;
}
