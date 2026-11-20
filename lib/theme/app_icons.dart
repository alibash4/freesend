import 'package:material_ui/material_ui.dart';

import 'uicons.dart';

/// Icon set for the whole app: UIcons Regular Rounded. Screens never reach
/// into the font classes directly, so the style is decided in exactly one
/// place.
abstract final class AppIcons {
  // Transfer.
  static final IconData send = UIcons.regularRounded.arrow_up_right;
  static final IconData sendPlane = UIcons.regularRounded.paper_plane;
  static final IconData dataTransfer = UIcons.regularRounded.data_transfer;
  static final IconData receive = UIcons.regularRounded.arrow_down;
  static final IconData hotspot = UIcons.regularRounded.signal_alt;
  static final IconData wifi = UIcons.regularRounded.wifi;
  static final IconData devices = UIcons.regularRounded.laptop_mobile;
  static final IconData vpnShield = UIcons.regularRounded.vpn_globe;
  static final IconData link = UIcons.regularRounded.link;
  static final IconData unlink = UIcons.regularRounded.link_slash;
  static final IconData zap = UIcons.regularRounded.bolt;
  static final IconData device = UIcons.regularRounded.screen;
  static final IconData group = UIcons.regularRounded.network_user;
  static final IconData phone = UIcons.regularRounded.smartphone;

  // Pairing.
  static final IconData scan = UIcons.regularRounded.barcode_scan;
  static final IconData qr = UIcons.regularRounded.qr_scan;
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
  // UIcons arrow-small-left (fi-rr-arrow-small-left), mirrored in RTL.
  static final IconData backSmall = const IconData(
    0xe103,
    fontFamily: 'uicons-regular-rounded',
    matchTextDirection: true,
  );
  static final IconData forward = UIcons.regularRounded.arrow_right;
  static final IconData chevronRight = UIcons.regularRounded.angle_right;
  static final IconData chevronLeft = UIcons.regularRounded.angle_left;
  static final IconData close = UIcons.regularRounded.x;
  static final IconData refresh = UIcons.regularRounded.refresh;
  static final IconData spinner = UIcons.regularRounded.spinner;
  static final IconData loading = UIcons.regularRounded.loading;

  // State.
  static final IconData check = UIcons.regularRounded.check;
  static final IconData checkCircle = UIcons.regularRounded.checkbox;
  static final IconData circle = UIcons.regularRounded.circle;
  static final IconData package = UIcons.regularRounded.package;
  static final IconData android = UIcons.brands.android;
  static final IconData lock = UIcons.regularRounded.lock;
  static final IconData stop = UIcons.regularRounded.stop;
  static final IconData pause = UIcons.regularRounded.pause;
  static final IconData play = UIcons.regularRounded.play;
  static final IconData alert = UIcons.regularRounded.exclamation;
  static final IconData info = UIcons.regularRounded.info;
  static final IconData radar = UIcons.regularRounded.signal_alt;
  static final IconData search = UIcons.regularRounded.search;
  static final IconData cameraOff = UIcons.regularRounded.video_slash;
  static final IconData camera = UIcons.regularRounded.camera;
  static final IconData bell = UIcons.regularRounded.bell;

  // Appearance.
  static final IconData sun = UIcons.regularRounded.sun;
  static final IconData moon = UIcons.regularRounded.moon;
  static final IconData auto = UIcons.regularRounded.screen;

  // System states.
  static final IconData locationPin = UIcons.regularRounded.marker;

  // Settings sections.
  static final IconData deviceMobile = UIcons.regularRounded.smartphone;
  static final IconData palette = UIcons.regularRounded.palette;
  static final IconData compress = UIcons.regularRounded.compress;
  static final IconData database = UIcons.regularRounded.database;
  static final IconData update = UIcons.regularRounded.arrow_circle_up;
  static final IconData sliders = UIcons.regularRounded.settings_sliders;
  static final IconData apps = UIcons.regularRounded.apps;

  // Bottom navigation: regular when idle, solid when active.
  static final IconData homeActive = UIcons.solidRounded.home;
  static final IconData transfersActive = UIcons.solidRounded.bolt;
  static final IconData historyActive = UIcons.solidRounded.time_past;
  static final IconData settingsActive = UIcons.solidRounded.settings;

  /// Every icon in the set, keyed by field name — drives the debug icon
  /// gallery screen.
  static final Map<String, IconData> catalog = {
    'send': send,
    'sendPlane': sendPlane,
    'dataTransfer': dataTransfer,
    'receive': receive,
    'hotspot': hotspot,
    'wifi': wifi,
    'devices': devices,
    'vpnShield': vpnShield,
    'link': link,
    'unlink': unlink,
    'zap': zap,
    'device': device,
    'group': group,
    'phone': phone,
    'scan': scan,
    'qr': qr,
    'copy': copy,
    'paste': paste,
    'address': address,
    'folder': folder,
    'folderOpen': folderOpen,
    'add': add,
    'addCircle': addCircle,
    'download': download,
    'inbox': inbox,
    'trash': trash,
    'image': image,
    'video': video,
    'music': music,
    'file': file,
    'fileText': fileText,
    'pdf': pdf,
    'home': home,
    'history': history,
    'settings': settings,
    'back': back,
    'backSmall': backSmall,
    'forward': forward,
    'chevronRight': chevronRight,
    'chevronLeft': chevronLeft,
    'close': close,
    'refresh': refresh,
    'spinner': spinner,
    'loading': loading,
    'check': check,
    'checkCircle': checkCircle,
    'circle': circle,
    'package': package,
    'android': android,
    'lock': lock,
    'stop': stop,
    'pause': pause,
    'play': play,
    'alert': alert,
    'info': info,
    'radar': radar,
    'search': search,
    'cameraOff': cameraOff,
    'camera': camera,
    'bell': bell,
    'sun': sun,
    'moon': moon,
    'auto': auto,
    'locationPin': locationPin,
    'deviceMobile': deviceMobile,
    'palette': palette,
    'compress': compress,
    'database': database,
    'update': update,
    'sliders': sliders,
    'apps': apps,
    'homeActive': homeActive,
    'transfersActive': transfersActive,
    'historyActive': historyActive,
    'settingsActive': settingsActive,
  };
}
