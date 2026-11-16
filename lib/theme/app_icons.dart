import 'package:flutter/widgets.dart';

import 'package:uicons/uicons.dart';
import 'package:uicons_brands/uicons_brands.dart';

/// Icon set for the whole app: UIcons Regular Rounded. Screens never reach
/// into the package directly, so the style is decided in exactly one place.
abstract final class AppIcons {
  // Transfer.
  static final IconData send = UIcons.regularRounded.arrow_up_right;
  static final IconData sendPlane = UIcons.regularRounded.paper_plane;
  static final IconData receive = UIcons.regularRounded.arrow_down;
  static final IconData hotspot = UIcons.regularRounded.signal_alt;
  static final IconData wifi = UIcons.regularRounded.wifi_alt;
  static final IconData link = UIcons.regularRounded.link;
  static final IconData unlink = UIcons.regularRounded.link_slash;
  static final IconData zap = UIcons.regularRounded.bolt;
  static final IconData device = UIcons.regularRounded.screen;
  static final IconData phone = UIcons.regularRounded.smartphone;

  // Pairing.
  static final IconData scan = UIcons.regularRounded.barcode_scan;
  static final IconData qr = UIcons.regularRounded.qrcode;
  static final IconData copy = UIcons.regularRounded.copy;
  static final IconData paste = UIcons.regularRounded.clipboard_list;
  static final IconData address = UIcons.regularRounded.keyboard;

  // Files.
  static final IconData folder = UIcons.regularRounded.folder;
  static final IconData folderOpen = UIcons.regularRounded.folder;
  static final IconData add = UIcons.regularRounded.plus;
  static final IconData addCircle = UIcons.regularRounded.plus;
  static final IconData download = UIcons.regularRounded.download;
  static final IconData inbox = UIcons.regularRounded.inbox;
  static final IconData trash = UIcons.regularRounded.trash;
  static final IconData image = UIcons.regularRounded.picture;
  static final IconData video = UIcons.regularRounded.video_camera;
  static final IconData music = UIcons.regularRounded.music;
  static final IconData file = UIcons.regularRounded.file;
  static final IconData fileText = UIcons.regularRounded.document;
  static final IconData pdf = UIcons.regularRounded.file_invoice;

  // Navigation and chrome.
  static final IconData home = UIcons.regularRounded.home;
  static final IconData history = UIcons.regularRounded.time_past;
  static final IconData settings = UIcons.regularRounded.settings;
  static final IconData back = UIcons.regularRounded.arrow_left;
  static final IconData forward = UIcons.regularRounded.arrow_right;
  static final IconData chevronRight = UIcons.regularRounded.angle_right;
  static final IconData close = UIcons.regularRounded.x;
  static final IconData refresh = UIcons.regularRounded.refresh;

  // State.
  static final IconData check = UIcons.regularRounded.check;
  static final IconData checkCircle = UIcons.regularRounded.checkbox;
  static final IconData circle = UIcons.regularRounded.circle;
  static final IconData package = UIcons.regularRounded.package;
  static final IconData android = const UIconsBrands().android;
  static final IconData lock = UIcons.regularRounded.lock;
  static final IconData stop = UIcons.regularRounded.stop;
  static final IconData pause = UIcons.regularRounded.pause;
  static final IconData play = UIcons.regularRounded.play;
  static final IconData alert = UIcons.regularRounded.exclamation;
  static final IconData info = UIcons.regularRounded.info;
  static final IconData radar = UIcons.regularRounded.signal_alt;
  static final IconData search = UIcons.regularRounded.search;
  static final IconData cameraOff = UIcons.regularRounded.video_slash;

  // Appearance.
  static final IconData sun = UIcons.regularRounded.sun;
  static final IconData moon = UIcons.regularRounded.moon;
  static final IconData auto = UIcons.regularRounded.sun;

  // Settings sections.
  static final IconData deviceMobile = UIcons.regularRounded.smartphone;
  static final IconData palette = UIcons.regularRounded.palette;
  static final IconData compress = UIcons.regularRounded.compress;
  static final IconData database = UIcons.regularRounded.database;
  static final IconData update = UIcons.regularRounded.arrow_circle_up;

  // Bottom navigation: regular when idle, solid when active.
  static final IconData homeActive = UIcons.solidRounded.home;
  static final IconData transfersActive = UIcons.solidRounded.bolt;
  static final IconData historyActive = UIcons.solidRounded.time_past;
  static final IconData settingsActive = UIcons.solidRounded.settings;
}
