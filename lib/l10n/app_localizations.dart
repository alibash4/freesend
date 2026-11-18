import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FreeSend'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTransfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get navTransfers;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @sendFile.
  ///
  /// In en, this message translates to:
  /// **'Send File'**
  String get sendFile;

  /// No description provided for @receiveFile.
  ///
  /// In en, this message translates to:
  /// **'Receive File'**
  String get receiveFile;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get sendTitle;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receiveTitle;

  /// No description provided for @pickWhatToSend.
  ///
  /// In en, this message translates to:
  /// **'Pick what to send'**
  String get pickWhatToSend;

  /// No description provided for @everythingStreamed.
  ///
  /// In en, this message translates to:
  /// **'Everything is streamed straight over the hotspot link.'**
  String get everythingStreamed;

  /// No description provided for @searchSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Search selected files'**
  String get searchSelectedFiles;

  /// No description provided for @nothingSelected.
  ///
  /// In en, this message translates to:
  /// **'Nothing selected'**
  String get nothingSelected;

  /// No description provided for @chooseFilesMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose files from this device. Folders keep their names when they arrive.'**
  String get chooseFilesMessage;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening…'**
  String get opening;

  /// No description provided for @chooseFilesOrFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose files or folder'**
  String get chooseFilesOrFolder;

  /// No description provided for @noSelectedFileMatches.
  ///
  /// In en, this message translates to:
  /// **'No selected file matches “{query}”.'**
  String noSelectedFileMatches(Object query);

  /// No description provided for @recentFiles.
  ///
  /// In en, this message translates to:
  /// **'Recent files'**
  String get recentFiles;

  /// No description provided for @tapToAddAgain.
  ///
  /// In en, this message translates to:
  /// **'Tap to add again'**
  String get tapToAddAgain;

  /// No description provided for @addMore.
  ///
  /// In en, this message translates to:
  /// **'Add more'**
  String get addMore;

  /// No description provided for @startSharing.
  ///
  /// In en, this message translates to:
  /// **'Start sharing'**
  String get startSharing;

  /// No description provided for @filesTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}} · {size} total'**
  String filesTotal(num count, Object size);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @stopSharingTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing?'**
  String get stopSharingTitle;

  /// No description provided for @stopSharingBody.
  ///
  /// In en, this message translates to:
  /// **'The hotspot will close and the other device will lose the connection.'**
  String get stopSharingBody;

  /// No description provided for @keepSharing.
  ///
  /// In en, this message translates to:
  /// **'Keep sharing'**
  String get keepSharing;

  /// No description provided for @openingHotspot.
  ///
  /// In en, this message translates to:
  /// **'Opening the hotspot…'**
  String get openingHotspot;

  /// No description provided for @nearbySessions.
  ///
  /// In en, this message translates to:
  /// **'Nearby sessions'**
  String get nearbySessions;

  /// No description provided for @listeningHotspot.
  ///
  /// In en, this message translates to:
  /// **'Listening on the hotspot for a device that is sharing.'**
  String get listeningHotspot;

  /// No description provided for @scanningPaused.
  ///
  /// In en, this message translates to:
  /// **'Scanning is paused.'**
  String get scanningPaused;

  /// No description provided for @scanPairingCode.
  ///
  /// In en, this message translates to:
  /// **'Scan pairing code'**
  String get scanPairingCode;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @enterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter code'**
  String get enterCode;

  /// No description provided for @joinHotspot.
  ///
  /// In en, this message translates to:
  /// **'Join a hotspot'**
  String get joinHotspot;

  /// No description provided for @connectByAddress.
  ///
  /// In en, this message translates to:
  /// **'Connect by address'**
  String get connectByAddress;

  /// No description provided for @reviewInReceive.
  ///
  /// In en, this message translates to:
  /// **'Review in Receive'**
  String get reviewInReceive;

  /// No description provided for @transferData.
  ///
  /// In en, this message translates to:
  /// **'Transfer Data'**
  String get transferData;

  /// No description provided for @receiveData.
  ///
  /// In en, this message translates to:
  /// **'Receive Data'**
  String get receiveData;

  /// No description provided for @recentlyTransferred.
  ///
  /// In en, this message translates to:
  /// **'Recently transferred'**
  String get recentlyTransferred;

  /// No description provided for @nothingSentYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing sent yet'**
  String get nothingSentYet;

  /// No description provided for @nothingSentMessage.
  ///
  /// In en, this message translates to:
  /// **'Files you send will show up here, grouped by day.'**
  String get nothingSentMessage;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get transfers;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'This only removes the local list of past transfers. Received files stay on disk.'**
  String get clearHistoryBody;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearHistoryConfirm;

  /// No description provided for @nothingMoved.
  ///
  /// In en, this message translates to:
  /// **'Nothing has moved yet.'**
  String get nothingMoved;

  /// No description provided for @transfersMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transfer} other{{count} transfers}} · {size} moved'**
  String transfersMoved(num count, Object size);

  /// No description provided for @noHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get noHistoryTitle;

  /// No description provided for @noHistoryMessage.
  ///
  /// In en, this message translates to:
  /// **'Completed and cancelled transfers are recorded here, on this device only.'**
  String get noHistoryMessage;

  /// No description provided for @noHistoryYetTitle.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get noHistoryYetTitle;

  /// No description provided for @noHistoryYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Finished and cancelled transfers are recorded here, on this device only.'**
  String get noHistoryYetMessage;

  /// No description provided for @sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sent;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @interrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get interrupted;

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @sentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String sentTo(Object name);

  /// No description provided for @receivedFrom.
  ///
  /// In en, this message translates to:
  /// **'Received from {name}'**
  String receivedFrom(Object name);

  /// No description provided for @waitingForDevice.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a device'**
  String get waitingForDevice;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'device'**
  String get device;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @pausedBySender.
  ///
  /// In en, this message translates to:
  /// **'Paused by sender'**
  String get pausedBySender;

  /// No description provided for @sendingTo.
  ///
  /// In en, this message translates to:
  /// **'Sending to {name}'**
  String sendingTo(Object name);

  /// No description provided for @receivingFrom.
  ///
  /// In en, this message translates to:
  /// **'Receiving from {name}'**
  String receivingFrom(Object name);

  /// No description provided for @incomingOffer.
  ///
  /// In en, this message translates to:
  /// **'Incoming offer'**
  String get incomingOffer;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @folders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get folders;

  /// No description provided for @music.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get music;

  /// No description provided for @documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No description provided for @videos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get videos;

  /// No description provided for @apk.
  ///
  /// In en, this message translates to:
  /// **'APK'**
  String get apk;

  /// No description provided for @largeFiles.
  ///
  /// In en, this message translates to:
  /// **'Large files'**
  String get largeFiles;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// No description provided for @addFolder.
  ///
  /// In en, this message translates to:
  /// **'Add folder'**
  String get addFolder;

  /// No description provided for @emptyCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyCategory;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get gridView;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listView;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @cancelTransfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get cancelTransfer;

  /// No description provided for @liveOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Live on this device'**
  String get liveOnThisDevice;

  /// No description provided for @nothingTransferring.
  ///
  /// In en, this message translates to:
  /// **'Nothing transferring'**
  String get nothingTransferring;

  /// No description provided for @nothingTransferringMessage.
  ///
  /// In en, this message translates to:
  /// **'Start a send or receive and the live transfer, its queue, and its controls will appear here.'**
  String get nothingTransferringMessage;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @deviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 device} other{{count} devices}}'**
  String deviceCount(num count);

  /// No description provided for @fileCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file} other{{count} files}}'**
  String fileCount(num count);

  /// No description provided for @transferCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 transfer} other{{count} transfers}}'**
  String transferCount(num count);

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'{size} · sent'**
  String statusSent(Object size);

  /// No description provided for @statusSaved.
  ///
  /// In en, this message translates to:
  /// **'{size} · saved'**
  String statusSaved(Object size);

  /// No description provided for @statusPaused.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {total} · paused'**
  String statusPaused(Object sent, Object total);

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {total}'**
  String statusActive(Object sent, Object total);

  /// No description provided for @ofTotal.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {total}'**
  String ofTotal(Object sent, Object total);

  /// No description provided for @thisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get thisDevice;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device name'**
  String get deviceName;

  /// No description provided for @deviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Shown to the other device during a transfer'**
  String get deviceNameHint;

  /// No description provided for @platformCanHotspot.
  ///
  /// In en, this message translates to:
  /// **'{platform} · can create a hotspot'**
  String platformCanHotspot(Object platform);

  /// No description provided for @platformSharesNetwork.
  ///
  /// In en, this message translates to:
  /// **'{platform} · shares over the current network'**
  String platformSharesNetwork(Object platform);

  /// No description provided for @receivedFiles.
  ///
  /// In en, this message translates to:
  /// **'Received files'**
  String get receivedFiles;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get saveLocation;

  /// No description provided for @notSetYet.
  ///
  /// In en, this message translates to:
  /// **'Not set yet'**
  String get notSetYet;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change folder'**
  String get changeFolder;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @lookAndFeel.
  ///
  /// In en, this message translates to:
  /// **'Look and feel'**
  String get lookAndFeel;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @minimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray on close'**
  String get minimizeToTray;

  /// No description provided for @keepRunningInTray.
  ///
  /// In en, this message translates to:
  /// **'Keep FreeSend running in the tray when the window is closed.'**
  String get keepRunningInTray;

  /// No description provided for @black.
  ///
  /// In en, this message translates to:
  /// **'OLED Mode'**
  String get black;

  /// No description provided for @blackThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A deeper dark made for OLED screens: easy on the eyes, easy on battery.'**
  String get blackThemeSubtitle;

  /// No description provided for @hapticFeedback.
  ///
  /// In en, this message translates to:
  /// **'Tap feedback'**
  String get hapticFeedback;

  /// No description provided for @hapticFeedbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Feel a light tap when you switch sections.'**
  String get hapticFeedbackSubtitle;

  /// No description provided for @hapticIntensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get hapticIntensity;

  /// No description provided for @localDataExplanation.
  ///
  /// In en, this message translates to:
  /// **'FreeSend keeps a local list of past transfers and nothing else. Files are never uploaded — the two devices talk directly over the hotspot link.'**
  String get localDataExplanation;

  /// No description provided for @clearTransferHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear transfer history'**
  String get clearTransferHistory;

  /// No description provided for @checkAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Check automatically'**
  String get checkAutomatically;

  /// No description provided for @lookForNewerRelease.
  ///
  /// In en, this message translates to:
  /// **'Look for a newer release every time FreeSend starts.'**
  String get lookForNewerRelease;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkForUpdates;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get checkingUpdates;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @app.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get app;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @saveLocationUpdated.
  ///
  /// In en, this message translates to:
  /// **'Save location updated'**
  String get saveLocationUpdated;

  /// No description provided for @deviceNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Device name updated'**
  String get deviceNameUpdated;

  /// No description provided for @couldNotChangeFolder.
  ///
  /// In en, this message translates to:
  /// **'Could not change folder: {error}'**
  String couldNotChangeFolder(Object error);

  /// No description provided for @chooseFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose where received files go'**
  String get chooseFolderTitle;

  /// No description provided for @clearHistoryQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear history?'**
  String get clearHistoryQuestion;

  /// No description provided for @receivedFilesStay.
  ///
  /// In en, this message translates to:
  /// **'Received files stay on disk.'**
  String get receivedFilesStay;

  /// No description provided for @linkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get linkLabel;

  /// No description provided for @linkWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi'**
  String get linkWifi;

  /// No description provided for @linkEthernet.
  ///
  /// In en, this message translates to:
  /// **'Ethernet'**
  String get linkEthernet;

  /// No description provided for @setupBeforeSend.
  ///
  /// In en, this message translates to:
  /// **'Before you send'**
  String get setupBeforeSend;

  /// No description provided for @setupBeforeReceive.
  ///
  /// In en, this message translates to:
  /// **'Before you receive'**
  String get setupBeforeReceive;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'FreeSend needs these permissions and device settings before a transfer. Allow the prompts, turn on the settings, then come back - this screen updates itself.'**
  String get setupIntro;

  /// No description provided for @setupNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get setupNearbyTitle;

  /// No description provided for @setupNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Lets FreeSend find the other device and run the hotspot the transfer uses.'**
  String get setupNearbyBody;

  /// No description provided for @setupNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get setupNotificationsTitle;

  /// No description provided for @setupNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Keeps the transfer running when you leave the app.'**
  String get setupNotificationsBody;

  /// No description provided for @setupWifiTitle.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi is on'**
  String get setupWifiTitle;

  /// No description provided for @setupWifiBody.
  ///
  /// In en, this message translates to:
  /// **'FreeSend shares over Wi-Fi or a hotspot it creates. Turn Wi-Fi on and come back - this check repeats automatically.'**
  String get setupWifiBody;

  /// No description provided for @setupVpnTitle.
  ///
  /// In en, this message translates to:
  /// **'VPN is off'**
  String get setupVpnTitle;

  /// No description provided for @setupVpnBody.
  ///
  /// In en, this message translates to:
  /// **'FreeSend shares over the local network, which a VPN hides. Turn your VPN off and come back - this check repeats automatically.'**
  String get setupVpnBody;

  /// No description provided for @setupLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location is on'**
  String get setupLocationTitle;

  /// No description provided for @setupLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Android needs location services on to run the hotspot a transfer uses. Turn location on and come back - this check repeats automatically.'**
  String get setupLocationBody;

  /// No description provided for @setupOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get setupOptional;

  /// No description provided for @setupEnable.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get setupEnable;

  /// No description provided for @setupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setupSettings;

  /// No description provided for @setupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get setupDone;

  /// No description provided for @setupActionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Action needed'**
  String get setupActionNeeded;

  /// No description provided for @setupCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get setupCheckAgain;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get updateFailed;

  /// No description provided for @knockAcceptTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept files from {name}?'**
  String knockAcceptTitle(Object name);

  /// No description provided for @knockNote.
  ///
  /// In en, this message translates to:
  /// **'You are asked once per device; known devices connect automatically.'**
  String get knockNote;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @invalidPairingCode.
  ///
  /// In en, this message translates to:
  /// **'That is not a FreeSend pairing code.'**
  String get invalidPairingCode;

  /// No description provided for @waitingHintOpen.
  ///
  /// In en, this message translates to:
  /// **'Keep this screen open. The sending device will find you.'**
  String get waitingHintOpen;

  /// No description provided for @waitingHintReady.
  ///
  /// In en, this message translates to:
  /// **'Getting ready…'**
  String get waitingHintReady;

  /// No description provided for @otherWaysTitle.
  ///
  /// In en, this message translates to:
  /// **'Other ways to connect'**
  String get otherWaysTitle;

  /// No description provided for @otherWaysSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If the devices do not find each other on their own'**
  String get otherWaysSubtitle;

  /// No description provided for @scanPairingCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the code on the sending device'**
  String get scanPairingCodeHint;

  /// No description provided for @enterPairingCode.
  ///
  /// In en, this message translates to:
  /// **'Enter a pairing code'**
  String get enterPairingCode;

  /// No description provided for @enterPairingCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a code sent in a message or shown on screen'**
  String get enterPairingCodeHint;

  /// No description provided for @connectByAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Type the address shown on the sending device'**
  String get connectByAddressHint;

  /// No description provided for @qrCodeSemantics.
  ///
  /// In en, this message translates to:
  /// **'FreeSend pairing code'**
  String get qrCodeSemantics;

  /// No description provided for @qrScanTitle.
  ///
  /// In en, this message translates to:
  /// **'The other device scans this code'**
  String get qrScanTitle;

  /// No description provided for @qrScanHint.
  ///
  /// In en, this message translates to:
  /// **'On the sending device, open FreeSend and scan to connect.'**
  String get qrScanHint;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get copyCode;

  /// No description provided for @noCameraBody.
  ///
  /// In en, this message translates to:
  /// **'There\'s nothing to scan here. The other device will find this one by name - keep both on the same network.'**
  String get noCameraBody;

  /// No description provided for @joinHotspotPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to the phone\'s hotspot'**
  String get joinHotspotPromptTitle;

  /// No description provided for @joinHotspotPromptBody.
  ///
  /// In en, this message translates to:
  /// **'This device needs to join the hotspot the phone creates. Enter its name and password below.'**
  String get joinHotspotPromptBody;

  /// No description provided for @backToHotspot.
  ///
  /// In en, this message translates to:
  /// **'Back to the hotspot'**
  String get backToHotspot;

  /// No description provided for @sameWifiShowCode.
  ///
  /// In en, this message translates to:
  /// **'On the same Wi-Fi? Show a code instead'**
  String get sameWifiShowCode;

  /// No description provided for @noLocalAddressBody.
  ///
  /// In en, this message translates to:
  /// **'This device has no usable local address. Connect both devices to the same network first.'**
  String get noLocalAddressBody;

  /// No description provided for @offeringSummary.
  ///
  /// In en, this message translates to:
  /// **'Offering {files} · {size}'**
  String offeringSummary(Object files, Object size);

  /// No description provided for @chooseWhatToReceive.
  ///
  /// In en, this message translates to:
  /// **'Choose what to receive'**
  String get chooseWhatToReceive;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @savingTo.
  ///
  /// In en, this message translates to:
  /// **'Saving to {path}'**
  String savingTo(Object path);

  /// No description provided for @encryptedSession.
  ///
  /// In en, this message translates to:
  /// **'Encrypted session'**
  String get encryptedSession;

  /// No description provided for @backToSessions.
  ///
  /// In en, this message translates to:
  /// **'Back to sessions'**
  String get backToSessions;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select files'**
  String get selectFiles;

  /// No description provided for @receiveCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Receive {count} · {size}'**
  String receiveCountLabel(Object count, Object size);

  /// No description provided for @encryptedTag.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get encryptedTag;

  /// No description provided for @pausedByYou.
  ///
  /// In en, this message translates to:
  /// **'Paused by you'**
  String get pausedByYou;

  /// No description provided for @nearbyDevice.
  ///
  /// In en, this message translates to:
  /// **'Nearby device'**
  String get nearbyDevice;

  /// No description provided for @fromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromLabel;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'{size} · saved'**
  String fileSaved(Object size);

  /// No description provided for @filePaused.
  ///
  /// In en, this message translates to:
  /// **'{done} of {size} · paused'**
  String filePaused(Object done, Object size);

  /// No description provided for @failedTag.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedTag;

  /// No description provided for @fileProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {size}'**
  String fileProgress(Object done, Object size);

  /// No description provided for @filesReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Files received'**
  String get filesReceivedTitle;

  /// No description provided for @doneSummaryAverage.
  ///
  /// In en, this message translates to:
  /// **'{files} · {size} · {speed} average'**
  String doneSummaryAverage(Object files, Object size, Object speed);

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @receiveMore.
  ///
  /// In en, this message translates to:
  /// **'Receive more'**
  String get receiveMore;

  /// No description provided for @transferCancelled.
  ///
  /// In en, this message translates to:
  /// **'Transfer cancelled'**
  String get transferCancelled;

  /// No description provided for @couldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect'**
  String get couldNotConnect;

  /// No description provided for @retryFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Retry 1 file} other{Retry {count} files}}'**
  String retryFiles(num count);

  /// No description provided for @scanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// No description provided for @joinHotspotSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the hotspot'**
  String get joinHotspotSheetTitle;

  /// No description provided for @hotspotCredentialsHint.
  ///
  /// In en, this message translates to:
  /// **'Use the hotspot name and password shown on the sending device.'**
  String get hotspotCredentialsHint;

  /// No description provided for @hotspotName.
  ///
  /// In en, this message translates to:
  /// **'Hotspot name'**
  String get hotspotName;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @joinAndScan.
  ///
  /// In en, this message translates to:
  /// **'Join and scan'**
  String get joinAndScan;

  /// No description provided for @manualConnectBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the address shown on the sending device. The port is optional and defaults to 47811.'**
  String get manualConnectBody;

  /// No description provided for @addressOrHost.
  ///
  /// In en, this message translates to:
  /// **'Address or host:port'**
  String get addressOrHost;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @pairingCodeSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter pairing code'**
  String get pairingCodeSheetTitle;

  /// No description provided for @pairingCodeHint.
  ///
  /// In en, this message translates to:
  /// **'On the sending device, tap Copy code under the QR code, then paste it here. The code starts with freesend://'**
  String get pairingCodeHint;

  /// No description provided for @pairingCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCodeLabel;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @filePickerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the file picker: {error}'**
  String filePickerFailed(Object error);

  /// No description provided for @noAppBundles.
  ///
  /// In en, this message translates to:
  /// **'No installable app bundles were found on this device.'**
  String get noAppBundles;

  /// No description provided for @appBundleUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That app bundle is no longer readable.'**
  String get appBundleUnreadable;

  /// No description provided for @chooseFolderToSend.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder to send'**
  String get chooseFolderToSend;

  /// No description provided for @androidFolderUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That Android folder could not be read. Choose it again.'**
  String get androidFolderUnreadable;

  /// No description provided for @folderNotReadable.
  ///
  /// In en, this message translates to:
  /// **'That folder is not readable.'**
  String get folderNotReadable;

  /// No description provided for @folderNoReadableFiles.
  ///
  /// In en, this message translates to:
  /// **'That folder has no readable files.'**
  String get folderNoReadableFiles;

  /// No description provided for @labelCopied.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String labelCopied(Object label);

  /// No description provided for @portOnly.
  ///
  /// In en, this message translates to:
  /// **'Port {port}'**
  String portOnly(Object port);

  /// No description provided for @transferringTag.
  ///
  /// In en, this message translates to:
  /// **'Transferring'**
  String get transferringTag;

  /// No description provided for @deviceConnected.
  ///
  /// In en, this message translates to:
  /// **'{name} connected'**
  String deviceConnected(Object name);

  /// No description provided for @genericDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get genericDevice;

  /// No description provided for @chooseReceivers.
  ///
  /// In en, this message translates to:
  /// **'Choose who receives these'**
  String get chooseReceivers;

  /// No description provided for @scanReceiverCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the receiver\'s code'**
  String get scanReceiverCode;

  /// No description provided for @lookingForReceiver.
  ///
  /// In en, this message translates to:
  /// **'Looking for a device to receive these'**
  String get lookingForReceiver;

  /// No description provided for @noCandidatesBody.
  ///
  /// In en, this message translates to:
  /// **'Nobody is ready yet - on the other device, open FreeSend and tap Receive.'**
  String get noCandidatesBody;

  /// No description provided for @selectDevice.
  ///
  /// In en, this message translates to:
  /// **'Select a device'**
  String get selectDevice;

  /// No description provided for @askDevices.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Ask 1 device} other{Ask {count} devices}}'**
  String askDevices(num count);

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan a QR code'**
  String get scanQrCode;

  /// No description provided for @orJoinManually.
  ///
  /// In en, this message translates to:
  /// **'Or join manually'**
  String get orJoinManually;

  /// No description provided for @networkLabel.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkLabel;

  /// No description provided for @wired.
  ///
  /// In en, this message translates to:
  /// **'Wired'**
  String get wired;

  /// No description provided for @hotspotLabel.
  ///
  /// In en, this message translates to:
  /// **'Hotspot'**
  String get hotspotLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @pairingInstructions.
  ///
  /// In en, this message translates to:
  /// **'On the other device, open FreeSend, choose Receive, and scan the code above — or join this hotspot and the session appears on its own.'**
  String get pairingInstructions;

  /// No description provided for @preparingSummary.
  ///
  /// In en, this message translates to:
  /// **'Preparing {files} · {size}'**
  String preparingSummary(Object files, Object size);

  /// No description provided for @stopSharing.
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get stopSharing;

  /// No description provided for @sentToName.
  ///
  /// In en, this message translates to:
  /// **'Sent to {name}'**
  String sentToName(Object name);

  /// No description provided for @theOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'the other device'**
  String get theOtherDevice;

  /// No description provided for @shareAgain.
  ///
  /// In en, this message translates to:
  /// **'Share these files again'**
  String get shareAgain;

  /// No description provided for @sharingStopped.
  ///
  /// In en, this message translates to:
  /// **'Sharing stopped'**
  String get sharingStopped;

  /// No description provided for @couldNotShare.
  ///
  /// In en, this message translates to:
  /// **'Could not share'**
  String get couldNotShare;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @backToFiles.
  ///
  /// In en, this message translates to:
  /// **'Back to files'**
  String get backToFiles;

  /// No description provided for @sendAnApp.
  ///
  /// In en, this message translates to:
  /// **'Send an app'**
  String get sendAnApp;

  /// No description provided for @installedApp.
  ///
  /// In en, this message translates to:
  /// **'Installed app'**
  String get installedApp;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String appVersion(Object version);

  /// No description provided for @addToTransfer.
  ///
  /// In en, this message translates to:
  /// **'Add to this transfer'**
  String get addToTransfer;

  /// No description provided for @anyFileType.
  ///
  /// In en, this message translates to:
  /// **'Any file type'**
  String get anyFileType;

  /// No description provided for @mediaLibrary.
  ///
  /// In en, this message translates to:
  /// **'Media library'**
  String get mediaLibrary;

  /// No description provided for @mediaLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Photos, videos, and audio with thumbnails'**
  String get mediaLibraryHint;

  /// No description provided for @audioLabel.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audioLabel;

  /// No description provided for @docsHint.
  ///
  /// In en, this message translates to:
  /// **'PDF, Office, text, CSV'**
  String get docsHint;

  /// No description provided for @appsLabel.
  ///
  /// In en, this message translates to:
  /// **'Apps'**
  String get appsLabel;

  /// No description provided for @appsHint.
  ///
  /// In en, this message translates to:
  /// **'Installable app bundles on this device'**
  String get appsHint;

  /// No description provided for @folderLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folderLabel;

  /// No description provided for @folderHint.
  ///
  /// In en, this message translates to:
  /// **'Send a whole folder tree'**
  String get folderHint;

  /// No description provided for @waitingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an answer'**
  String get waitingAnswer;

  /// No description provided for @acceptedTag.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get acceptedTag;

  /// No description provided for @declinedTag.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declinedTag;

  /// No description provided for @unreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get unreachable;

  /// No description provided for @shareNearby.
  ///
  /// In en, this message translates to:
  /// **'Share to nearby'**
  String get shareNearby;

  /// No description provided for @shareNearbyHint.
  ///
  /// In en, this message translates to:
  /// **'Find devices that are waiting to receive.'**
  String get shareNearbyHint;

  /// No description provided for @scanQrHint.
  ///
  /// In en, this message translates to:
  /// **'Read a receiver\'s code instead of waiting for it to appear.'**
  String get scanQrHint;

  /// No description provided for @sendToGroup.
  ///
  /// In en, this message translates to:
  /// **'Send to a group'**
  String get sendToGroup;

  /// No description provided for @sendToGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Pick several devices; each one accepts on its own.'**
  String get sendToGroupHint;

  /// No description provided for @howToSend.
  ///
  /// In en, this message translates to:
  /// **'How do you want to send?'**
  String get howToSend;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the code on the sending device.'**
  String get scanHint;

  /// No description provided for @scanWrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not from FreeSend. Point the camera at the code on the sending device.'**
  String get scanWrongCode;

  /// No description provided for @cameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off'**
  String get cameraOff;

  /// No description provided for @cameraFailed.
  ///
  /// In en, this message translates to:
  /// **'The camera could not start'**
  String get cameraFailed;

  /// No description provided for @cameraDeniedBody.
  ///
  /// In en, this message translates to:
  /// **'FreeSend needs the camera only to read the pairing code. Allow it in system settings, or type the code instead.'**
  String get cameraDeniedBody;

  /// No description provided for @cameraBusyBody.
  ///
  /// In en, this message translates to:
  /// **'Another app may be using the camera. You can also type the code instead.'**
  String get cameraBusyBody;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @enterCodeInstead.
  ///
  /// In en, this message translates to:
  /// **'Enter the code instead'**
  String get enterCodeInstead;

  /// No description provided for @mediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get mediaTitle;

  /// No description provided for @mediaPermissionOff.
  ///
  /// In en, this message translates to:
  /// **'Photo access is off. Allow it in system settings to browse this device.'**
  String get mediaPermissionOff;

  /// No description provided for @mediaReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read the media library: {error}'**
  String mediaReadFailed(Object error);

  /// No description provided for @albumReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read that album: {error}'**
  String albumReadFailed(Object error);

  /// No description provided for @mediaItemsUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Those items are not readable on this device.'**
  String get mediaItemsUnreadable;

  /// No description provided for @searchAlbum.
  ///
  /// In en, this message translates to:
  /// **'Search this album'**
  String get searchAlbum;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @photosFilter.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photosFilter;

  /// No description provided for @albumLabel.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get albumLabel;

  /// No description provided for @preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing…'**
  String get preparing;

  /// No description provided for @sendItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Send 1 item} other{Send {count} items}}'**
  String sendItems(num count);

  /// No description provided for @mediaUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Media unavailable'**
  String get mediaUnavailable;

  /// No description provided for @noMediaHere.
  ///
  /// In en, this message translates to:
  /// **'No media here'**
  String get noMediaHere;

  /// No description provided for @noMediaHint.
  ///
  /// In en, this message translates to:
  /// **'Pick another album or choose files with the system picker.'**
  String get noMediaHint;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @logsCopied.
  ///
  /// In en, this message translates to:
  /// **'Logs copied'**
  String get logsCopied;

  /// No description provided for @savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String savedTo(Object path);

  /// No description provided for @clearLogsQuestion.
  ///
  /// In en, this message translates to:
  /// **'Clear logs?'**
  String get clearLogsQuestion;

  /// No description provided for @clearLogsBody.
  ///
  /// In en, this message translates to:
  /// **'The on-device log file keeps its history; only this view empties.'**
  String get clearLogsBody;

  /// No description provided for @copyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy all'**
  String get copyAll;

  /// No description provided for @saveToFile.
  ///
  /// In en, this message translates to:
  /// **'Save to file'**
  String get saveToFile;

  /// No description provided for @noLogEntries.
  ///
  /// In en, this message translates to:
  /// **'No log entries yet.'**
  String get noLogEntries;

  /// No description provided for @logLevelDebug.
  ///
  /// In en, this message translates to:
  /// **'debug'**
  String get logLevelDebug;

  /// No description provided for @logLevelInfo.
  ///
  /// In en, this message translates to:
  /// **'info'**
  String get logLevelInfo;

  /// No description provided for @logLevelWarn.
  ///
  /// In en, this message translates to:
  /// **'warning'**
  String get logLevelWarn;

  /// No description provided for @logLevelError.
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get logLevelError;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @diagnosticsBody.
  ///
  /// In en, this message translates to:
  /// **'Inspect, copy or save everything the app logged this session.'**
  String get diagnosticsBody;

  /// No description provided for @openLogs.
  ///
  /// In en, this message translates to:
  /// **'Open logs'**
  String get openLogs;

  /// No description provided for @checkingForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates'**
  String get checkingForUpdates;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'FreeSend {version} is available'**
  String updateAvailableTitle(Object version);

  /// No description provided for @askingGitLab.
  ///
  /// In en, this message translates to:
  /// **'Asking GitLab what is new.'**
  String get askingGitLab;

  /// No description provided for @whatsNew.
  ///
  /// In en, this message translates to:
  /// **'What is new'**
  String get whatsNew;

  /// No description provided for @youAreOn.
  ///
  /// In en, this message translates to:
  /// **'You are on {version}'**
  String youAreOn(Object version);

  /// No description provided for @sizeYouAreOn.
  ///
  /// In en, this message translates to:
  /// **'{size} · you are on {version}'**
  String sizeYouAreOn(Object size, Object version);

  /// No description provided for @downloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String downloadingPercent(Object percent);

  /// No description provided for @downloadUpdate.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get downloadUpdate;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @installRestart.
  ///
  /// In en, this message translates to:
  /// **'Install and restart'**
  String get installRestart;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @receivers.
  ///
  /// In en, this message translates to:
  /// **'Receivers'**
  String get receivers;

  /// No description provided for @peerProgress.
  ///
  /// In en, this message translates to:
  /// **'{sent} of {total} · {done}/{count} files'**
  String peerProgress(Object count, Object done, Object sent, Object total);

  /// No description provided for @sendingFile.
  ///
  /// In en, this message translates to:
  /// **'Sending {name}'**
  String sendingFile(Object name);

  /// No description provided for @sendingTag.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get sendingTag;

  /// No description provided for @activeTag.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeTag;

  /// No description provided for @connectingTag.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connectingTag;

  /// No description provided for @scanToPair.
  ///
  /// In en, this message translates to:
  /// **'Scan to pair'**
  String get scanToPair;

  /// No description provided for @pairingHotspotHint.
  ///
  /// In en, this message translates to:
  /// **'On the other device, open FreeSend, choose Receive, and scan this. It joins the hotspot and connects on its own.'**
  String get pairingHotspotHint;

  /// No description provided for @pairingNoHotspotHint.
  ///
  /// In en, this message translates to:
  /// **'On the other device, open FreeSend, choose Receive, and scan this to connect without typing an address.'**
  String get pairingNoHotspotHint;

  /// No description provided for @copyLabel.
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String copyLabel(Object label);

  /// No description provided for @etaMoment.
  ///
  /// In en, this message translates to:
  /// **'a moment'**
  String get etaMoment;

  /// No description provided for @etaFinishing.
  ///
  /// In en, this message translates to:
  /// **'finishing'**
  String get etaFinishing;

  /// No description provided for @etaEstimating.
  ///
  /// In en, this message translates to:
  /// **'estimating'**
  String get etaEstimating;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAt(Object time);

  /// No description provided for @yesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String yesterdayAt(Object time);

  /// No description provided for @noWiredNetworkReceive.
  ///
  /// In en, this message translates to:
  /// **'No wired network was found. Connect an Ethernet cable, then try again.'**
  String get noWiredNetworkReceive;

  /// No description provided for @discoveryFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Discovery could not start. You can still connect by IP address.'**
  String get discoveryFailedBody;

  /// No description provided for @connectedLooking.
  ///
  /// In en, this message translates to:
  /// **'Connected to \"{ssid}\". Looking for the sharing device…'**
  String connectedLooking(Object ssid);

  /// No description provided for @couldNotJoinHotspot.
  ///
  /// In en, this message translates to:
  /// **'Could not join the hotspot: {error}'**
  String couldNotJoinHotspot(Object error);

  /// No description provided for @joinedHotspotNote.
  ///
  /// In en, this message translates to:
  /// **'Joined \"{ssid}\".'**
  String joinedHotspotNote(Object ssid);

  /// No description provided for @joinHotspotManuallyNote.
  ///
  /// In en, this message translates to:
  /// **'Join \"{ssid}\" from your Wi-Fi menu. The session appears here as soon as you are connected.'**
  String joinHotspotManuallyNote(Object ssid);

  /// No description provided for @couldNotReachAddress.
  ///
  /// In en, this message translates to:
  /// **'Could not reach {address}. Make sure both devices are on the same hotspot.'**
  String couldNotReachAddress(Object address);

  /// No description provided for @transferDidNotFinish.
  ///
  /// In en, this message translates to:
  /// **'The transfer did not finish.'**
  String get transferDidNotFinish;

  /// No description provided for @receivingFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Receiving files'**
  String get receivingFilesTitle;

  /// No description provided for @retryingTransferTitle.
  ///
  /// In en, this message translates to:
  /// **'Retrying transfer'**
  String get retryingTransferTitle;

  /// No description provided for @retryFailedFiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 file failed earlier} other{{count} files failed earlier}}'**
  String retryFailedFiles(num count);

  /// No description provided for @receivingProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Receiving {sent} of {total}'**
  String receivingProgressTitle(Object sent, Object total);

  /// No description provided for @noWiredNetworkSend.
  ///
  /// In en, this message translates to:
  /// **'No wired network was found. Connect an Ethernet cable, or switch back to Wi-Fi.'**
  String get noWiredNetworkSend;

  /// No description provided for @noLocalAddressSend.
  ///
  /// In en, this message translates to:
  /// **'FreeSend could not find a local address. Connect to a Wi-Fi network, or use a cable.'**
  String get noLocalAddressSend;

  /// No description provided for @readyToShare.
  ///
  /// In en, this message translates to:
  /// **'Ready to share'**
  String get readyToShare;

  /// No description provided for @waitingForReceiverNote.
  ///
  /// In en, this message translates to:
  /// **'waiting for a receiver'**
  String get waitingForReceiverNote;

  /// No description provided for @listenerFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the transfer listener. Allow FreeSend through the system firewall on private networks, then try again ({error}).'**
  String listenerFailed(Object error);

  /// No description provided for @couldNotStartSharing.
  ///
  /// In en, this message translates to:
  /// **'Could not start sharing: {error}'**
  String couldNotStartSharing(Object error);

  /// No description provided for @sendingProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Sending {sent} of {total}'**
  String sendingProgressTitle(Object sent, Object total);

  /// No description provided for @cannotJoinHotspot.
  ///
  /// In en, this message translates to:
  /// **'This device cannot join a hotspot. Use a shared Wi-Fi network instead.'**
  String get cannotJoinHotspot;

  /// No description provided for @hotspotWinNote.
  ///
  /// In en, this message translates to:
  /// **'Sharing over your current network. For the fastest link, turn on Mobile hotspot in Windows Settings, then connect the other device to it.'**
  String get hotspotWinNote;

  /// No description provided for @hotspotMacNote.
  ///
  /// In en, this message translates to:
  /// **'Sharing over your current network. For the fastest link, turn on Internet Sharing in System Settings under General, then connect the other device to it.'**
  String get hotspotMacNote;

  /// No description provided for @joinHotspotManuallyError.
  ///
  /// In en, this message translates to:
  /// **'Join the hotspot \"{ssid}\" from your system Wi-Fi menu, then come back here.'**
  String joinHotspotManuallyError(Object ssid);

  /// No description provided for @noWifiInterface.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi interface found.'**
  String get noWifiInterface;

  /// No description provided for @couldNotJoinSsid.
  ///
  /// In en, this message translates to:
  /// **'Could not join \"{ssid}\": {error}'**
  String couldNotJoinSsid(Object error, Object ssid);

  /// No description provided for @noWifiAdapter.
  ///
  /// In en, this message translates to:
  /// **'No Wi-Fi adapter found. Connect to the other device\'s hotspot instead.'**
  String get noWifiAdapter;

  /// No description provided for @couldNotStartHotspot.
  ///
  /// In en, this message translates to:
  /// **'Could not start the hotspot: {error}'**
  String couldNotStartHotspot(Object error);

  /// No description provided for @noHotspotDetails.
  ///
  /// In en, this message translates to:
  /// **'The system did not return hotspot details.'**
  String get noHotspotDetails;

  /// No description provided for @couldNotStartHotspotPlain.
  ///
  /// In en, this message translates to:
  /// **'Could not start the hotspot.'**
  String get couldNotStartHotspotPlain;

  /// No description provided for @couldNotJoinPlain.
  ///
  /// In en, this message translates to:
  /// **'Could not join \"{ssid}\".'**
  String couldNotJoinPlain(Object ssid);

  /// No description provided for @hotspotPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Android requires the location (or nearby devices) permission to use a hotspot. Enable it in system settings and try again.'**
  String get hotspotPermissionRequired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
