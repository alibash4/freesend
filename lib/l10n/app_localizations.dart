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
  /// **'Turn these on in order. FreeSend stays on the local link, and it cannot start until the required ones are on.'**
  String get setupIntro;

  /// No description provided for @setupNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get setupNearbyTitle;

  /// No description provided for @setupNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Lets FreeSend open or join the hotspot the transfer uses.'**
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

  /// No description provided for @setupCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get setupCameraTitle;

  /// No description provided for @setupCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Reads the pairing code shown on the other device. You can paste a code instead.'**
  String get setupCameraBody;

  /// No description provided for @setupOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get setupOptional;

  /// No description provided for @setupEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get setupEnable;

  /// No description provided for @setupSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setupSettings;

  /// No description provided for @permTitle.
  ///
  /// In en, this message translates to:
  /// **'Please grant the following permissions'**
  String get permTitle;

  /// No description provided for @permIntro.
  ///
  /// In en, this message translates to:
  /// **'FreeSend needs access to the local link and camera to find nearby devices and scan pairing codes. Nothing leaves your network.'**
  String get permIntro;

  /// No description provided for @permSection.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permSection;

  /// No description provided for @permLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location / nearby devices'**
  String get permLocationTitle;

  /// No description provided for @permLocationBody.
  ///
  /// In en, this message translates to:
  /// **'Required by Android to create or join a hotspot and discover other FreeSend devices.'**
  String get permLocationBody;

  /// No description provided for @permNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby Wi-Fi devices'**
  String get permNearbyTitle;

  /// No description provided for @permNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Used on Android 13 and newer for device discovery.'**
  String get permNearbyBody;

  /// No description provided for @permLocalNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get permLocalNetworkTitle;

  /// No description provided for @permNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permNotificationsTitle;

  /// No description provided for @permNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Shows transfer progress while FreeSend is in the background.'**
  String get permNotificationsBody;

  /// No description provided for @permMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos, videos, and audio'**
  String get permMediaTitle;

  /// No description provided for @permMediaBody.
  ///
  /// In en, this message translates to:
  /// **'Used by the media browser to show thumbnails and let you pick files.'**
  String get permMediaBody;

  /// No description provided for @permCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get permCameraTitle;

  /// No description provided for @permCameraBody.
  ///
  /// In en, this message translates to:
  /// **'Only used to scan a pairing QR code. You can still pair by typing or pasting the code.'**
  String get permCameraBody;

  /// No description provided for @permAllowed.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get permAllowed;

  /// No description provided for @permBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get permBlocked;

  /// No description provided for @permNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Not asked'**
  String get permNotAsked;

  /// No description provided for @permAllSet.
  ///
  /// In en, this message translates to:
  /// **'FreeSend is ready.'**
  String get permAllSet;

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

  /// No description provided for @permChangeLater.
  ///
  /// In en, this message translates to:
  /// **'You can change these later in the system settings.'**
  String get permChangeLater;

  /// No description provided for @permRequesting.
  ///
  /// In en, this message translates to:
  /// **'Requesting…'**
  String get permRequesting;

  /// No description provided for @permContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get permContinue;

  /// No description provided for @permAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow permissions'**
  String get permAllow;

  /// No description provided for @permOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get permOpenSettings;
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
