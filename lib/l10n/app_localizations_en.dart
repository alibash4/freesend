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
  String get notSetYet => 'Not set yet';

  @override
  String get changeFolder => 'Change folder';

  @override
  String get appearance => 'Appearance';

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
  String get systemTray => 'System tray';

  @override
  String get minimizeToTray => 'Minimize to tray on close';

  @override
  String get keepRunningInTray =>
      'Keep FreeSend running in the tray when the window is closed.';

  @override
  String get data => 'Data';

  @override
  String get localDataExplanation =>
      'FreeSend keeps a local list of past transfers and nothing else. Files are never uploaded — the two devices talk directly over the hotspot link.';

  @override
  String get clearTransferHistory => 'Clear transfer history';

  @override
  String get updates => 'Updates';

  @override
  String get checkAutomatically => 'Check automatically';

  @override
  String get lookForNewerRelease =>
      'Look for a newer release every time FreeSend starts.';

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get about => 'About';

  @override
  String get app => 'App';

  @override
  String get protocol => 'Protocol';

  @override
  String get platform => 'Platform';

  @override
  String get saveLocationUpdated => 'Save location updated';

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
}
