// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FreeSend';

  @override
  String get navHome => 'Home';

  @override
  String get navTransfers => 'Transfers';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get sendFile => 'Send File';

  @override
  String get receiveFile => 'Receive File';

  @override
  String get sendTitle => 'Send';

  @override
  String get receiveTitle => 'Receive';

  @override
  String get pickWhatToSend => 'Pick what to send';

  @override
  String get everythingStreamed =>
      'Everything is streamed straight over the hotspot link.';

  @override
  String get searchSelectedFiles => 'Search selected files';

  @override
  String get nothingSelected => 'Nothing selected';

  @override
  String get chooseFilesMessage =>
      'Choose files from this device. Folders keep their names when they arrive.';

  @override
  String get opening => 'Opening…';

  @override
  String get chooseFilesOrFolder => 'Choose files or folder';

  @override
  String noSelectedFileMatches(Object query) {
    return 'No selected file matches “$query”.';
  }

  @override
  String get recentFiles => 'Recent files';

  @override
  String get tapToAddAgain => 'Tap to add again';

  @override
  String get addMore => 'Add more';

  @override
  String get startSharing => 'Start sharing';

  @override
  String filesTotal(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0 · $size total';
  }

  @override
  String get remove => 'Remove';

  @override
  String get stopSharingTitle => 'Stop sharing?';

  @override
  String get stopSharingBody =>
      'The hotspot will close and the other device will lose the connection.';

  @override
  String get keepSharing => 'Keep sharing';

  @override
  String get openingHotspot => 'Opening the hotspot…';

  @override
  String get nearbySessions => 'Nearby sessions';

  @override
  String get listeningHotspot =>
      'Listening on the hotspot for a device that is sharing.';

  @override
  String get scanningPaused => 'Scanning is paused.';

  @override
  String get scanPairingCode => 'Scan pairing code';

  @override
  String get rescan => 'Rescan';

  @override
  String get enterCode => 'Enter code';

  @override
  String get joinHotspot => 'Join a hotspot';

  @override
  String get connectByAddress => 'Connect by address';

  @override
  String get reviewInReceive => 'Review in Receive';

  @override
  String get transferData => 'Transfer Data';

  @override
  String get receiveData => 'Receive Data';

  @override
  String get recentlyTransferred => 'Recently transferred';

  @override
  String get nothingSentYet => 'Nothing sent yet';

  @override
  String get nothingSentMessage =>
      'Files you send will show up here, grouped by day.';

  @override
  String get history => 'History';

  @override
  String get transfers => 'Transfers';

  @override
  String get settings => 'Settings';

  @override
  String get clear => 'Clear';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get change => 'Change';

  @override
  String get clearHistoryTitle => 'Clear history?';

  @override
  String get clearHistoryBody =>
      'This only removes the local list of past transfers. Received files stay on disk.';

  @override
  String get clearHistoryConfirm => 'Clear';

  @override
  String get nothingMoved => 'Nothing has moved yet.';

  @override
  String transfersMoved(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
    );
    return '$_temp0 · $size moved';
  }

  @override
  String get noHistoryTitle => 'No history';

  @override
  String get noHistoryMessage =>
      'Completed and cancelled transfers are recorded here, on this device only.';

  @override
  String get noHistoryYetTitle => 'No history yet';

  @override
  String get noHistoryYetMessage =>
      'Finished and cancelled transfers are recorded here, on this device only.';

  @override
  String get sent => 'Sent';

  @override
  String get received => 'Received';

  @override
  String get interrupted => 'Interrupted';

  @override
  String get failed => 'Failed';

  @override
  String sentTo(Object name) {
    return 'Sent to $name';
  }

  @override
  String receivedFrom(Object name) {
    return 'Received from $name';
  }

  @override
  String get waitingForDevice => 'Waiting for a device';

  @override
  String get device => 'device';

  @override
  String get paused => 'Paused';

  @override
  String get pausedBySender => 'Paused by sender';

  @override
  String sendingTo(Object name) {
    return 'Sending to $name';
  }

  @override
  String receivingFrom(Object name) {
    return 'Receiving from $name';
  }

  @override
  String get incomingOffer => 'Incoming offer';

  @override
  String get speed => 'Speed';

  @override
  String get remaining => 'Remaining';

  @override
  String get files => 'Files';

  @override
  String get folders => 'Folders';

  @override
  String get music => 'Music';

  @override
  String get documents => 'Documents';

  @override
  String get videos => 'Videos';

  @override
  String get apk => 'APK';

  @override
  String get largeFiles => 'Large files';

  @override
  String get select => 'Select';

  @override
  String get addFiles => 'Add files';

  @override
  String get addFolder => 'Add folder';

  @override
  String get emptyCategory => 'Nothing here yet';

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get done => 'Done';

  @override
  String get gridView => 'Grid';

  @override
  String get listView => 'List';

  @override
  String get loading => 'Loading…';

  @override
  String get resume => 'Resume';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get waitingNotificationTitle => 'Waiting for files';

  @override
  String get cancelTransfer => 'Cancel transfer';

  @override
  String get liveOnThisDevice => 'Live on this device';

  @override
  String get nothingTransferring => 'Nothing transferring';

  @override
  String get nothingTransferringMessage =>
      'Start a send or receive and the live transfer, its queue, and its controls will appear here.';

  @override
  String get recent => 'Recent';

  @override
  String deviceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String fileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
    );
    return '$_temp0';
  }

  @override
  String transferCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transfers',
      one: '1 transfer',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'Saved';

  @override
  String statusSent(Object size) {
    return '$size · sent';
  }

  @override
  String statusSaved(Object size) {
    return '$size · saved';
  }

  @override
  String statusPaused(Object sent, Object total) {
    return '$sent of $total · paused';
  }

  @override
  String statusActive(Object sent, Object total) {
    return '$sent of $total';
  }

  @override
  String ofTotal(Object sent, Object total) {
    return '$sent of $total';
  }

  @override
  String get thisDevice => 'This device';

  @override
  String get general => 'General';

  @override
  String get system => 'System';

  @override
  String get deviceName => 'Device name';

  @override
  String get deviceNameHint => 'Shown to the other device during a transfer';

  @override
  String platformCanHotspot(Object platform) {
    return '$platform · can create a hotspot';
  }

  @override
  String platformSharesNetwork(Object platform) {
    return '$platform · shares over the current network';
  }

  @override
  String get receivedFiles => 'Received files';

  @override
  String get saveLocation => 'Save location';

  @override
  String get notSetYet => 'Not set yet';

  @override
  String get changeFolder => 'Change folder';

  @override
  String get appearance => 'Appearance';

  @override
  String get lookAndFeel => 'Look and feel';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get theme => 'Theme';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get auto => 'Auto';

  @override
  String get minimizeToTray => 'Minimize to tray on close';

  @override
  String get keepRunningInTray =>
      'Keep FreeSend running in the tray when the window is closed.';

  @override
  String get black => 'OLED Mode';

  @override
  String get blackThemeSubtitle =>
      'A deeper dark made for OLED screens: easy on the eyes, easy on battery.';

  @override
  String get hapticFeedback => 'Tap feedback';

  @override
  String get hapticFeedbackSubtitle =>
      'Feel a light tap when you switch sections.';

  @override
  String get hapticIntensity => 'Intensity';

  @override
  String get localDataExplanation =>
      'FreeSend keeps a local list of past transfers and nothing else. Files are never uploaded — the two devices talk directly over the hotspot link.';

  @override
  String get clearTransferHistory => 'Clear transfer history';

  @override
  String get checkAutomatically => 'Check automatically';

  @override
  String get lookForNewerRelease =>
      'Look for a newer release every time FreeSend starts.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get checkingUpdates => 'Checking';

  @override
  String get about => 'About';

  @override
  String get app => 'App';

  @override
  String get protocol => 'Protocol';

  @override
  String get platform => 'Platform';

  @override
  String get iconGallery => 'Icon gallery';

  @override
  String get saveLocationUpdated => 'Save location updated';

  @override
  String get deviceNameUpdated => 'Device name updated';

  @override
  String couldNotChangeFolder(Object error) {
    return 'Could not change folder: $error';
  }

  @override
  String get chooseFolderTitle => 'Choose where received files go';

  @override
  String get clearHistoryQuestion => 'Clear history?';

  @override
  String get receivedFilesStay => 'Received files stay on disk.';

  @override
  String get linkLabel => 'Network';

  @override
  String get linkWifi => 'Wi-Fi';

  @override
  String get linkEthernet => 'Ethernet';

  @override
  String get setupBeforeSend => 'Before you send';

  @override
  String get setupBeforeReceive => 'Before you receive';

  @override
  String get setupIntro =>
      'FreeSend needs these permissions and device settings before a transfer. Allow the prompts, turn on the settings, then come back - this screen updates itself.';

  @override
  String get setupNearbyTitle => 'Nearby devices';

  @override
  String get setupNearbyBody =>
      'Lets FreeSend find the other device and run the hotspot the transfer uses.';

  @override
  String get setupNotificationsTitle => 'Notifications';

  @override
  String get setupNotificationsBody =>
      'Keeps the transfer running when you leave the app.';

  @override
  String get setupWifiTitle => 'Wi-Fi is on';

  @override
  String get setupWifiBody =>
      'FreeSend shares over Wi-Fi or a hotspot it creates. Turn Wi-Fi on and come back - this check repeats automatically.';

  @override
  String get setupVpnTitle => 'VPN is off';

  @override
  String get setupVpnBody =>
      'FreeSend shares over the local network, which a VPN hides. Turn your VPN off and come back - this check repeats automatically.';

  @override
  String get setupLocationTitle => 'Location is on';

  @override
  String get setupLocationBody =>
      'Android needs location services on to run the hotspot a transfer uses. Turn location on and come back - this check repeats automatically.';

  @override
  String get vpnWarningTitle => 'A VPN is on';

  @override
  String get vpnWarningBody =>
      'It usually still works, but if the other device cannot find you, turn the VPN off - or connect both devices to the same network.';

  @override
  String get setupOptional => 'Optional';

  @override
  String get setupEnable => 'Allow';

  @override
  String get setupSettings => 'Settings';

  @override
  String get setupDone => 'Done';

  @override
  String get updateUpToDate => 'You\'re on the latest version.';

  @override
  String get updateFailed => 'Update failed';

  @override
  String knockAcceptTitle(Object name) {
    return 'Accept files from $name?';
  }

  @override
  String get knockNote =>
      'You are asked once per device; known devices connect automatically.';

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get invalidPairingCode => 'That is not a FreeSend pairing code.';

  @override
  String get waitingHintOpen =>
      'Keep this screen open. The sending device will find you.';

  @override
  String get waitingHintReady => 'Getting ready…';

  @override
  String get otherWaysTitle => 'Other ways to connect';

  @override
  String get otherWaysSubtitle =>
      'If the devices do not find each other on their own';

  @override
  String get scanPairingCodeHint =>
      'Point the camera at the code on the sending device';

  @override
  String get enterPairingCode => 'Enter a pairing code';

  @override
  String get enterPairingCodeHint =>
      'Paste a code sent in a message or shown on screen';

  @override
  String get connectByAddressHint =>
      'Type the address shown on the sending device';

  @override
  String get qrCodeSemantics => 'FreeSend pairing code';

  @override
  String get qrScanTitle => 'The other device scans this code';

  @override
  String get qrScanHint =>
      'On the sending device, open FreeSend and scan to connect.';

  @override
  String get copyCode => 'Copy code';

  @override
  String get noCameraBody =>
      'There\'s nothing to scan here. The other device will find this one by name - keep both on the same network.';

  @override
  String get joinHotspotPromptTitle => 'Connect to the phone\'s hotspot';

  @override
  String get joinHotspotPromptBody =>
      'This device needs to join the hotspot the phone creates. Enter its name and password below.';

  @override
  String get backToHotspot => 'Back to the hotspot';

  @override
  String get sameWifiShowCode => 'On the same Wi-Fi? Show a code instead';

  @override
  String get noLocalAddressBody =>
      'This device has no usable local address. Connect both devices to the same network first.';

  @override
  String offeringSummary(Object files, Object size) {
    return 'Offering $files · $size';
  }

  @override
  String get chooseWhatToReceive => 'Choose what to receive';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearAll => 'Clear all';

  @override
  String savingTo(Object path) {
    return 'Saving to $path';
  }

  @override
  String get encryptedSession => 'Encrypted session';

  @override
  String get backToSessions => 'Back to sessions';

  @override
  String get selectFiles => 'Select files';

  @override
  String receiveCountLabel(Object count, Object size) {
    return 'Receive $count · $size';
  }

  @override
  String get encryptedTag => 'Encrypted';

  @override
  String get pausedByYou => 'Paused by you';

  @override
  String get nearbyDevice => 'Nearby device';

  @override
  String get fromLabel => 'From';

  @override
  String fileSaved(Object size) {
    return '$size · saved';
  }

  @override
  String filePaused(Object done, Object size) {
    return '$done of $size · paused';
  }

  @override
  String get failedTag => 'Failed';

  @override
  String fileProgress(Object done, Object size) {
    return '$done of $size';
  }

  @override
  String get filesReceivedTitle => 'Files received';

  @override
  String doneSummaryAverage(Object files, Object size, Object speed) {
    return '$files · $size · $speed average';
  }

  @override
  String get open => 'Open';

  @override
  String get receiveMore => 'Receive more';

  @override
  String get transferCancelled => 'Transfer cancelled';

  @override
  String get couldNotConnect => 'Could not connect';

  @override
  String retryFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retry $count files',
      one: 'Retry 1 file',
    );
    return '$_temp0';
  }

  @override
  String get scanAgain => 'Scan again';

  @override
  String get joinHotspotSheetTitle => 'Join the hotspot';

  @override
  String get hotspotCredentialsHint =>
      'Use the hotspot name and password shown on the sending device.';

  @override
  String get hotspotName => 'Hotspot name';

  @override
  String get password => 'Password';

  @override
  String get joinAndScan => 'Join and scan';

  @override
  String get manualConnectBody =>
      'Enter the address shown on the sending device. The port is optional and defaults to 47811.';

  @override
  String get addressOrHost => 'Address or host:port';

  @override
  String get connect => 'Connect';

  @override
  String get pairingCodeSheetTitle => 'Enter pairing code';

  @override
  String get pairingCodeHint =>
      'On the sending device, tap Copy code under the QR code, then paste it here. The code starts with freesend://';

  @override
  String get pairingCodeLabel => 'Pairing code';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String filePickerFailed(Object error) {
    return 'Could not open the file picker: $error';
  }

  @override
  String get noAppBundles =>
      'No installable app bundles were found on this device.';

  @override
  String get appBundleUnreadable => 'That app bundle is no longer readable.';

  @override
  String get chooseFolderToSend => 'Choose a folder to send';

  @override
  String get androidFolderUnreadable =>
      'That Android folder could not be read. Choose it again.';

  @override
  String get folderNotReadable => 'That folder is not readable.';

  @override
  String get folderNoReadableFiles => 'That folder has no readable files.';

  @override
  String labelCopied(Object label) {
    return '$label copied';
  }

  @override
  String portOnly(Object port) {
    return 'Port $port';
  }

  @override
  String get transferringTag => 'Transferring';

  @override
  String deviceConnected(Object name) {
    return '$name connected';
  }

  @override
  String get genericDevice => 'Device';

  @override
  String get chooseReceivers => 'Choose who receives these';

  @override
  String get scanReceiverCode => 'Scan the receiver\'s code';

  @override
  String get lookingForReceiver => 'Looking for a device to receive these';

  @override
  String get noCandidatesBody =>
      'Nobody is ready yet - on the other device, open FreeSend and tap Receive.';

  @override
  String get selectDevice => 'Select a device';

  @override
  String askDevices(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ask $count devices',
      one: 'Ask 1 device',
    );
    return '$_temp0';
  }

  @override
  String get scanQrCode => 'Scan a QR code';

  @override
  String get orJoinManually => 'Or join manually';

  @override
  String get networkLabel => 'Network';

  @override
  String get wired => 'Wired';

  @override
  String get hotspotLabel => 'Hotspot';

  @override
  String get addressLabel => 'Address';

  @override
  String get pairingInstructions =>
      'On the other device, open FreeSend, choose Receive, and scan the code above — or join this hotspot and the session appears on its own.';

  @override
  String preparingSummary(Object files, Object size) {
    return 'Preparing $files · $size';
  }

  @override
  String get stopSharing => 'Stop sharing';

  @override
  String sentToName(Object name) {
    return 'Sent to $name';
  }

  @override
  String get theOtherDevice => 'the other device';

  @override
  String get shareAgain => 'Share these files again';

  @override
  String get sharingStopped => 'Sharing stopped';

  @override
  String get couldNotShare => 'Could not share';

  @override
  String get tryAgain => 'Try again';

  @override
  String get backToFiles => 'Back to files';

  @override
  String get sendAnApp => 'Send an app';

  @override
  String get installedApp => 'Installed app';

  @override
  String appVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get addToTransfer => 'Add to this transfer';

  @override
  String get anyFileType => 'Any file type';

  @override
  String get mediaLibrary => 'Media library';

  @override
  String get mediaLibraryHint => 'Photos, videos, and audio with thumbnails';

  @override
  String get audioLabel => 'Audio';

  @override
  String get docsHint => 'PDF, Office, text, CSV';

  @override
  String get appsLabel => 'Apps';

  @override
  String get appsHint => 'Installable app bundles on this device';

  @override
  String get folderLabel => 'Folder';

  @override
  String get folderHint => 'Send a whole folder tree';

  @override
  String get waitingAnswer => 'Waiting for an answer';

  @override
  String get acceptedTag => 'Accepted';

  @override
  String get declinedTag => 'Declined';

  @override
  String get unreachable => 'Unreachable';

  @override
  String get shareNearby => 'Share to nearby';

  @override
  String get shareNearbyHint => 'Find devices that are waiting to receive.';

  @override
  String get scanQrHint =>
      'Read a receiver\'s code instead of waiting for it to appear.';

  @override
  String get sendToGroup => 'Send to a group';

  @override
  String get sendToGroupHint =>
      'Pick several devices; each one accepts on its own.';

  @override
  String get howToSend => 'How do you want to send?';

  @override
  String get close => 'Close';

  @override
  String get scanHint => 'Point the camera at the code on the sending device.';

  @override
  String get scanWrongCode =>
      'That code is not from FreeSend. Point the camera at the code on the sending device.';

  @override
  String get cameraOff => 'Camera access is off';

  @override
  String get cameraFailed => 'The camera could not start';

  @override
  String get cameraDeniedBody =>
      'FreeSend needs the camera only to read the pairing code. Allow it in system settings, or type the code instead.';

  @override
  String get cameraBusyBody =>
      'Another app may be using the camera. You can also type the code instead.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get enterCodeInstead => 'Enter the code instead';

  @override
  String get mediaTitle => 'Media';

  @override
  String get mediaPermissionOff =>
      'Photo access is off. Allow it in system settings to browse this device.';

  @override
  String mediaReadFailed(Object error) {
    return 'Could not read the media library: $error';
  }

  @override
  String albumReadFailed(Object error) {
    return 'Could not read that album: $error';
  }

  @override
  String get mediaItemsUnreadable =>
      'Those items are not readable on this device.';

  @override
  String get searchAlbum => 'Search this album';

  @override
  String get allFilter => 'All';

  @override
  String get photosFilter => 'Photos';

  @override
  String get albumLabel => 'Album';

  @override
  String get preparing => 'Preparing…';

  @override
  String sendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count items',
      one: 'Send 1 item',
    );
    return '$_temp0';
  }

  @override
  String get mediaUnavailable => 'Media unavailable';

  @override
  String get noMediaHere => 'No media here';

  @override
  String get noMediaHint =>
      'Pick another album or choose files with the system picker.';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsCopied => 'Logs copied';

  @override
  String savedTo(Object path) {
    return 'Saved to $path';
  }

  @override
  String get clearLogsQuestion => 'Clear logs?';

  @override
  String get clearLogsBody =>
      'The on-device log file keeps its history; only this view empties.';

  @override
  String get copyAll => 'Copy all';

  @override
  String get saveToFile => 'Save to file';

  @override
  String get noLogEntries => 'No log entries yet.';

  @override
  String get logLevelDebug => 'debug';

  @override
  String get logLevelInfo => 'info';

  @override
  String get logLevelWarn => 'warning';

  @override
  String get logLevelError => 'error';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get diagnosticsBody =>
      'Inspect, copy or save everything the app logged this session.';

  @override
  String get openLogs => 'Open logs';

  @override
  String get checkingForUpdates => 'Checking for updates';

  @override
  String updateAvailableTitle(Object version) {
    return 'FreeSend $version is available';
  }

  @override
  String get askingGitLab => 'Asking GitLab what is new.';

  @override
  String get whatsNew => 'What is new';

  @override
  String youAreOn(Object version) {
    return 'You are on $version';
  }

  @override
  String sizeYouAreOn(Object size, Object version) {
    return '$size · you are on $version';
  }

  @override
  String downloadingPercent(Object percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get notNow => 'Not now';

  @override
  String get installRestart => 'Install and restart';

  @override
  String get later => 'Later';

  @override
  String get gotIt => 'Got it';

  @override
  String get receivers => 'Receivers';

  @override
  String peerProgress(Object count, Object done, Object sent, Object total) {
    return '$sent of $total · $done/$count files';
  }

  @override
  String sendingFile(Object name) {
    return 'Sending $name';
  }

  @override
  String get sendingTag => 'Sending';

  @override
  String get activeTag => 'Active';

  @override
  String get connectingTag => 'Connecting';

  @override
  String get scanToPair => 'Scan to pair';

  @override
  String get pairingHotspotHint =>
      'On the other device, open FreeSend, choose Receive, and scan this. It joins the hotspot and connects on its own.';

  @override
  String get pairingNoHotspotHint =>
      'On the other device, open FreeSend, choose Receive, and scan this to connect without typing an address.';

  @override
  String copyLabel(Object label) {
    return 'Copy $label';
  }

  @override
  String get etaMoment => 'a moment';

  @override
  String get etaFinishing => 'finishing';

  @override
  String get etaEstimating => 'estimating';

  @override
  String todayAt(Object time) {
    return 'Today, $time';
  }

  @override
  String yesterdayAt(Object time) {
    return 'Yesterday, $time';
  }

  @override
  String get noWiredNetworkReceive =>
      'No wired network was found. Connect an Ethernet cable, then try again.';

  @override
  String get discoveryFailedBody =>
      'Discovery could not start. You can still connect by IP address.';

  @override
  String connectedLooking(Object ssid) {
    return 'Connected to \"$ssid\". Looking for the sharing device…';
  }

  @override
  String couldNotJoinHotspot(Object error) {
    return 'Could not join the hotspot: $error';
  }

  @override
  String joinedHotspotNote(Object ssid) {
    return 'Joined \"$ssid\".';
  }

  @override
  String joinHotspotManuallyNote(Object ssid) {
    return 'Join \"$ssid\" from your Wi-Fi menu. The session appears here as soon as you are connected.';
  }

  @override
  String couldNotReachAddress(Object address) {
    return 'Could not reach $address. Make sure both devices are on the same hotspot.';
  }

  @override
  String get transferDidNotFinish => 'The transfer did not finish.';

  @override
  String get receivingFilesTitle => 'Receiving files';

  @override
  String get retryingTransferTitle => 'Retrying transfer';

  @override
  String retryFailedFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files failed earlier',
      one: '1 file failed earlier',
    );
    return '$_temp0';
  }

  @override
  String receivingProgressTitle(Object sent, Object total) {
    return 'Receiving $sent of $total';
  }

  @override
  String get noWiredNetworkSend =>
      'No wired network was found. Connect an Ethernet cable, or switch back to Wi-Fi.';

  @override
  String get noLocalAddressSend =>
      'FreeSend could not find a local address. Connect to a Wi-Fi network, or use a cable.';

  @override
  String get readyToShare => 'Ready to share';

  @override
  String get waitingForReceiverNote => 'waiting for a receiver';

  @override
  String listenerFailed(Object error) {
    return 'Could not open the transfer listener. Allow FreeSend through the system firewall on private networks, then try again ($error).';
  }

  @override
  String couldNotStartSharing(Object error) {
    return 'Could not start sharing: $error';
  }

  @override
  String sendingProgressTitle(Object sent, Object total) {
    return 'Sending $sent of $total';
  }

  @override
  String get cannotJoinHotspot =>
      'This device cannot join a hotspot. Use a shared Wi-Fi network instead.';

  @override
  String get hotspotWinNote =>
      'Sharing over your current network. For the fastest link, turn on Mobile hotspot in Windows Settings, then connect the other device to it.';

  @override
  String get hotspotMacNote =>
      'Sharing over your current network. For the fastest link, turn on Internet Sharing in System Settings under General, then connect the other device to it.';

  @override
  String joinHotspotManuallyError(Object ssid) {
    return 'Join the hotspot \"$ssid\" from your system Wi-Fi menu, then come back here.';
  }

  @override
  String get noWifiInterface => 'No Wi-Fi interface found.';

  @override
  String couldNotJoinSsid(Object error, Object ssid) {
    return 'Could not join \"$ssid\": $error';
  }

  @override
  String get noWifiAdapter =>
      'No Wi-Fi adapter found. Connect to the other device\'s hotspot instead.';

  @override
  String couldNotStartHotspot(Object error) {
    return 'Could not start the hotspot: $error';
  }

  @override
  String get noHotspotDetails => 'The system did not return hotspot details.';

  @override
  String get couldNotStartHotspotPlain => 'Could not start the hotspot.';

  @override
  String couldNotJoinPlain(Object ssid) {
    return 'Could not join \"$ssid\".';
  }

  @override
  String get hotspotPermissionRequired =>
      'Android requires the location (or nearby devices) permission to use a hotspot. Enable it in system settings and try again.';
}
