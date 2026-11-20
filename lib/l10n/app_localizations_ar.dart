// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'فري سيند';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navTransfers => 'التحويلات';

  @override
  String get navHistory => 'السجل';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get sendFile => 'إرسال ملف';

  @override
  String get receiveFile => 'استلام ملف';

  @override
  String get sendTitle => 'إرسال';

  @override
  String get receiveTitle => 'استلام';

  @override
  String get pickWhatToSend => 'اختر ما تريد إرساله';

  @override
  String get everythingStreamed =>
      'يتم بث كل شيء مباشرة عبر رابط نقطة الاتصال.';

  @override
  String get searchSelectedFiles => 'ابحث في الملفات المحددة';

  @override
  String get nothingSelected => 'لم يتم تحديد شيء';

  @override
  String get chooseFilesMessage =>
      'اختر ملفات من هذا الجهاز. تحتفظ المجلدات بأسمائها عند وصولها.';

  @override
  String get opening => 'جارٍ الفتح…';

  @override
  String get chooseFilesOrFolder => 'اختر ملفات أو مجلدًا';

  @override
  String noSelectedFileMatches(Object query) {
    return 'لا يوجد ملف محدد يطابق «$query».';
  }

  @override
  String get recentFiles => 'الملفات الأخيرة';

  @override
  String get tapToAddAgain => 'اضغط للإضافة مرة أخرى';

  @override
  String get addMore => 'إضافة المزيد';

  @override
  String get startSharing => 'بدء المشاركة';

  @override
  String filesTotal(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0 · $size إجمالي';
  }

  @override
  String get remove => 'إزالة';

  @override
  String get stopSharingTitle => 'إيقاف المشاركة؟';

  @override
  String get stopSharingBody =>
      'ستُغلق نقطة الاتصال وسيفقد الجهاز الآخر الاتصال.';

  @override
  String get keepSharing => 'متابعة المشاركة';

  @override
  String get openingHotspot => 'جارٍ فتح نقطة الاتصال…';

  @override
  String get nearbySessions => 'الجلسات القريبة';

  @override
  String get listeningHotspot =>
      'الاستماع على نقطة الاتصال بحثًا عن جهاز يشارك.';

  @override
  String get scanningPaused => 'تم إيقاف الفحص مؤقتًا.';

  @override
  String get scanPairingCode => 'فحص رمز الاقتران';

  @override
  String get rescan => 'إعادة الفحص';

  @override
  String get enterCode => 'إدخال الرمز';

  @override
  String get joinHotspot => 'الانضمام إلى نقطة اتصال';

  @override
  String get connectByAddress => 'الاتصال عبر العنوان';

  @override
  String get reviewInReceive => 'المراجعة في الاستلام';

  @override
  String get transferData => 'نقل البيانات';

  @override
  String get receiveData => 'استلام البيانات';

  @override
  String get recentlyTransferred => 'المحوّلات الأخيرة';

  @override
  String get nothingSentYet => 'لم يتم الإرسال بعد';

  @override
  String get nothingSentMessage =>
      'الملفات التي ترسلها ستظهر هنا مجمّعة حسب اليوم.';

  @override
  String get history => 'السجل';

  @override
  String get transfers => 'التحويلات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get clear => 'مسح';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get edit => 'تعديل';

  @override
  String get change => 'تغيير';

  @override
  String get clearHistoryTitle => 'مسح السجل؟';

  @override
  String get clearHistoryBody =>
      'هذا يزيل فقط قائمة التحويلات السابقة المحلية. الملفات المستلمة تبقى على القرص.';

  @override
  String get clearHistoryConfirm => 'مسح';

  @override
  String get nothingMoved => 'لم يتم نقل أي شيء بعد.';

  @override
  String transfersMoved(num count, Object size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عمليات نقل',
      one: 'عملية نقل واحدة',
    );
    return '$_temp0 · $size تم نقلها';
  }

  @override
  String get noHistoryTitle => 'لا يوجد سجل';

  @override
  String get noHistoryMessage =>
      'يتم تسجيل التحويلات المكتملة والملغاة هنا، على هذا الجهاز فقط.';

  @override
  String get noHistoryYetTitle => 'لا يوجد سجل بعد';

  @override
  String get noHistoryYetMessage =>
      'يتم تسجيل التحويلات المنتهية والملغاة هنا، على هذا الجهاز فقط.';

  @override
  String get sent => 'أُرسل';

  @override
  String get received => 'استُلم';

  @override
  String get interrupted => 'تمت المقاطعة';

  @override
  String get failed => 'فشل';

  @override
  String sentTo(Object name) {
    return 'أُرسل إلى $name';
  }

  @override
  String receivedFrom(Object name) {
    return 'استُلم من $name';
  }

  @override
  String get waitingForDevice => 'في انتظار جهاز';

  @override
  String get device => 'جهاز';

  @override
  String get paused => 'متوقف مؤقتًا';

  @override
  String get pausedBySender => 'أوقفه المرسل مؤقتًا';

  @override
  String sendingTo(Object name) {
    return 'جارٍ الإرسال إلى $name';
  }

  @override
  String receivingFrom(Object name) {
    return 'جارٍ الاستلام من $name';
  }

  @override
  String get incomingOffer => 'عرض وارد';

  @override
  String get speed => 'السرعة';

  @override
  String get remaining => 'المتبقي';

  @override
  String get files => 'الملفات';

  @override
  String get folders => 'المجلدات';

  @override
  String get music => 'الموسيقى';

  @override
  String get documents => 'المستندات';

  @override
  String get videos => 'الفيديو';

  @override
  String get apk => 'APK';

  @override
  String get largeFiles => 'الملفات الكبيرة';

  @override
  String get select => 'تحديد';

  @override
  String get addFiles => 'إضافة ملفات';

  @override
  String get addFolder => 'إضافة مجلد';

  @override
  String get emptyCategory => 'لا يوجد شيء هنا بعد';

  @override
  String selectedCount(Object count) {
    return '$count محدد';
  }

  @override
  String get done => 'تم';

  @override
  String get gridView => 'شبكة';

  @override
  String get listView => 'قائمة';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get resume => 'استئناف';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get stop => 'إيقاف';

  @override
  String get waitingNotificationTitle => 'بانتظار الملفات';

  @override
  String get cancelTransfer => 'إلغاء التحويل';

  @override
  String get liveOnThisDevice => 'مباشر على هذا الجهاز';

  @override
  String get nothingTransferring => 'لا يوجد تحويل جارٍ';

  @override
  String get nothingTransferringMessage =>
      'ابدأ إرسالًا أو استلامًا وسيظهر التحويل المباشر وقائمة الانتظار وعناصر التحكم هنا.';

  @override
  String get recent => 'الأحدث';

  @override
  String deviceCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهاز',
      many: '$count جهازًا',
      few: '$count أجهزة',
      two: 'جهازان',
      one: 'جهاز واحد',
    );
    return '$_temp0';
  }

  @override
  String fileCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String transferCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عملية نقل',
      many: '$count عملية نقل',
      few: '$count عمليات نقل',
      two: 'عمليتا نقل',
      one: 'عملية نقل واحدة',
    );
    return '$_temp0';
  }

  @override
  String get saved => 'تم الحفظ';

  @override
  String statusSent(Object size) {
    return '$size · أُرسل';
  }

  @override
  String statusSaved(Object size) {
    return '$size · تم الحفظ';
  }

  @override
  String statusPaused(Object sent, Object total) {
    return '$sent من $total · متوقف مؤقتًا';
  }

  @override
  String statusActive(Object sent, Object total) {
    return '$sent من $total';
  }

  @override
  String ofTotal(Object sent, Object total) {
    return '$sent من $total';
  }

  @override
  String get thisDevice => 'هذا الجهاز';

  @override
  String get general => 'عام';

  @override
  String get system => 'النظام';

  @override
  String get deviceName => 'اسم الجهاز';

  @override
  String get deviceNameHint => 'يظهر للجهاز الآخر أثناء التحويل';

  @override
  String platformCanHotspot(Object platform) {
    return '$platform · يمكنه إنشاء نقطة اتصال';
  }

  @override
  String platformSharesNetwork(Object platform) {
    return '$platform · يشارك عبر الشبكة الحالية';
  }

  @override
  String get receivedFiles => 'الملفات المستلمة';

  @override
  String get saveLocation => 'موقع الحفظ';

  @override
  String get notSetYet => 'لم يُحدد بعد';

  @override
  String get changeFolder => 'تغيير المجلد';

  @override
  String get appearance => 'المظهر';

  @override
  String get lookAndFeel => 'المظهر والإحساس';

  @override
  String get language => 'اللغة';

  @override
  String get arabic => 'العربية';

  @override
  String get english => 'الإنجليزية';

  @override
  String get theme => 'السمة';

  @override
  String get light => 'فاتح';

  @override
  String get dark => 'داكن';

  @override
  String get auto => 'تلقائي';

  @override
  String get minimizeToTray => 'التصغير إلى منطقة النظام عند الإغلاق';

  @override
  String get keepRunningInTray =>
      'إبقاء FreeSend يعمل في منطقة النظام عند إغلاق النافذة.';

  @override
  String get black => 'وضع OLED';

  @override
  String get blackThemeSubtitle =>
      'وضع داكن أعمق لشاشات OLED: مريح للعين ويوفّر البطارية.';

  @override
  String get hapticFeedback => 'الاستجابة عند اللمس';

  @override
  String get hapticFeedbackSubtitle =>
      'شعور بنقرة خفيفة عند التنقل بين الأقسام.';

  @override
  String get hapticIntensity => 'الشدة';

  @override
  String get localDataExplanation =>
      'يحتفظ FreeSend بقائمة محلية بالتحويلات السابقة فقط. لا يتم رفع الملفات أبدًا — يتحدث الجهازان مباشرة عبر رابط نقطة الاتصال.';

  @override
  String get clearTransferHistory => 'مسح سجل التحويلات';

  @override
  String get checkAutomatically => 'التحقق تلقائيًا';

  @override
  String get lookForNewerRelease =>
      'ابحث عن إصدار أحدث في كل مرة يبدأ فيها FreeSend.';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get checkingUpdates => 'جارٍ التحقق';

  @override
  String get about => 'حول';

  @override
  String get app => 'التطبيق';

  @override
  String get protocol => 'البروتوكول';

  @override
  String get platform => 'المنصة';

  @override
  String get saveLocationUpdated => 'تم تحديث موقع الحفظ';

  @override
  String get deviceNameUpdated => 'تم تحديث اسم الجهاز';

  @override
  String couldNotChangeFolder(Object error) {
    return 'تعذر تغيير المجلد: $error';
  }

  @override
  String get chooseFolderTitle => 'اختر مكان حفظ الملفات المستلمة';

  @override
  String get clearHistoryQuestion => 'مسح السجل؟';

  @override
  String get receivedFilesStay => 'الملفات المستلمة تبقى على القرص.';

  @override
  String get linkLabel => 'الشبكة';

  @override
  String get linkWifi => 'واي فاي';

  @override
  String get linkEthernet => 'إيثرنت';

  @override
  String get setupBeforeSend => 'قبل الإرسال';

  @override
  String get setupBeforeReceive => 'قبل الاستلام';

  @override
  String get setupIntro =>
      'يحتاج FreeSend إلى هذه الأذونات وإعدادات الجهاز قبل النقل. اسمح بالمطالبات وفعّل الإعدادات ثم عُد إلى هنا، وتُحدَّث هذه الشاشة تلقائيًا.';

  @override
  String get setupNearbyTitle => 'الأجهزة القريبة';

  @override
  String get setupNearbyBody =>
      'يتيح لـ FreeSend العثور على الجهاز الآخر وتشغيل نقطة الاتصال التي يستخدمها النقل.';

  @override
  String get setupNotificationsTitle => 'الإشعارات';

  @override
  String get setupNotificationsBody =>
      'يبقي عملية النقل تعمل عند مغادرة التطبيق.';

  @override
  String get setupWifiTitle => 'الواي فاي مفعّل';

  @override
  String get setupWifiBody =>
      'يعمل FreeSend عبر الواي فاي، أو ينشئ نقطة اتصال خاصة به. فعّل الواي فاي ثم عُد إلى هنا، ويُعاد هذا الفحص تلقائيًا.';

  @override
  String get setupVpnTitle => 'الشبكة الافتراضية الخاصة (VPN) متوقفة';

  @override
  String get setupVpnBody =>
      'يعمل FreeSend عبر الشبكة المحلية التي تخفيها الشبكة الافتراضية الخاصة. أوقفها ثم عُد إلى هنا، ويُعاد هذا الفحص تلقائيًا.';

  @override
  String get setupLocationTitle => 'الموقع مفعّل';

  @override
  String get setupLocationBody =>
      'يحتاج أندرويد إلى خدمات الموقع مفعّلة لتشغيل نقطة الاتصال التي يستخدمها النقل. فعّل الموقع ثم عُد إلى هنا، ويُعاد هذا الفحص تلقائيًا.';

  @override
  String get vpnWarningTitle => 'الشبكة الافتراضية الخاصة (VPN) مفعّلة';

  @override
  String get vpnWarningBody =>
      'يعمل عادة دون مشكلة، لكن إن لم يتمكن الجهاز الآخر من العثور عليك فأوقف الشبكة الافتراضية الخاصة، أو وصّل الجهازين بالشبكة نفسها.';

  @override
  String get setupOptional => 'اختياري';

  @override
  String get setupEnable => 'سماح';

  @override
  String get setupSettings => 'الإعدادات';

  @override
  String get setupDone => 'تم';

  @override
  String get setupActionNeeded => 'يتطلب إجراءً';

  @override
  String get setupCheckAgain => 'تحقق مجددًا';

  @override
  String get updateUpToDate => 'أنت تستخدم أحدث إصدار.';

  @override
  String get updateFailed => 'فشل التحديث';

  @override
  String knockAcceptTitle(Object name) {
    return 'هل تريد قبول ملفات من $name؟';
  }

  @override
  String get knockNote =>
      'يُطلب منك مرة واحدة لكل جهاز؛ الأجهزة المعروفة تتصل تلقائيًا.';

  @override
  String get decline => 'رفض';

  @override
  String get accept => 'قبول';

  @override
  String get invalidPairingCode => 'هذا ليس رمز اقتران FreeSend.';

  @override
  String get waitingHintOpen =>
      'أبقِ هذه الشاشة مفتوحة. سيعثر جهاز الإرسال عليك.';

  @override
  String get waitingHintReady => 'جارٍ التجهيز…';

  @override
  String get otherWaysTitle => 'طرق أخرى للاتصال';

  @override
  String get otherWaysSubtitle =>
      'إذا لم يتمكّن الجهازان من العثور على بعضهما تلقائيًا';

  @override
  String get scanPairingCodeHint => 'وجّه الكاميرا نحو الرمز على جهاز الإرسال';

  @override
  String get enterPairingCode => 'أدخل رمز اقتران';

  @override
  String get enterPairingCodeHint =>
      'الصق رمزًا أُرسل في رسالة أو معروض على الشاشة';

  @override
  String get connectByAddressHint => 'اكتب العنوان الظاهر على جهاز الإرسال';

  @override
  String get qrCodeSemantics => 'رمز اقتران FreeSend';

  @override
  String get qrScanTitle => 'الجهاز الآخر يمسح هذا الرمز';

  @override
  String get qrScanHint => 'على جهاز الإرسال، افتح FreeSend وامسح للاتصال.';

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get noCameraBody =>
      'لا يوجد ما يمكن مسحه هنا. سيعثر الجهاز الآخر على هذا الجهاز بالاسم — أبقِ كليهما على الشبكة نفسها.';

  @override
  String get joinHotspotPromptTitle => 'الاتصال بنقطة اتصال الهاتف';

  @override
  String get joinHotspotPromptBody =>
      'يحتاج هذا الجهاز للانضمام إلى نقطة الاتصال التي ينشئها الهاتف. أدخل اسمها وكلمة المرور أدناه.';

  @override
  String get backToHotspot => 'العودة إلى نقطة الاتصال';

  @override
  String get sameWifiShowCode => 'على الواي فاي نفسه؟ اعرض رمزًا بدلًا من ذلك';

  @override
  String get noLocalAddressBody =>
      'ليس لهذا الجهاز عنوان محلي صالح. صِل الجهازين بالشبكة نفسها أولًا.';

  @override
  String offeringSummary(Object files, Object size) {
    return 'يعرض $files · $size';
  }

  @override
  String get chooseWhatToReceive => 'اختر ما تريد استلامه';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String get clearAll => 'إلغاء تحديد الكل';

  @override
  String savingTo(Object path) {
    return 'يُحفظ في $path';
  }

  @override
  String get encryptedSession => 'جلسة مشفّرة';

  @override
  String get backToSessions => 'العودة إلى الجلسات';

  @override
  String get selectFiles => 'حدد ملفات';

  @override
  String receiveCountLabel(Object count, Object size) {
    return 'استلام $count · $size';
  }

  @override
  String get encryptedTag => 'مشفّر';

  @override
  String get pausedByYou => 'أوقفته مؤقتًا';

  @override
  String get nearbyDevice => 'جهاز قريب';

  @override
  String get fromLabel => 'من';

  @override
  String fileSaved(Object size) {
    return '$size · محفوظ';
  }

  @override
  String filePaused(Object done, Object size) {
    return '$done من $size · متوقف مؤقتًا';
  }

  @override
  String get failedTag => 'فشل';

  @override
  String fileProgress(Object done, Object size) {
    return '$done من $size';
  }

  @override
  String get filesReceivedTitle => 'تم استلام الملفات';

  @override
  String doneSummaryAverage(Object files, Object size, Object speed) {
    return '$files · $size · بمتوسط $speed';
  }

  @override
  String get open => 'فتح';

  @override
  String get receiveMore => 'استلام المزيد';

  @override
  String get transferCancelled => 'أُلغي التحويل';

  @override
  String get couldNotConnect => 'تعذّر الاتصال';

  @override
  String retryFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إعادة محاولة $count ملف',
      many: 'إعادة محاولة $count ملفًا',
      few: 'إعادة محاولة $count ملفات',
      two: 'إعادة محاولة ملفين',
      one: 'إعادة محاولة ملف واحد',
    );
    return '$_temp0';
  }

  @override
  String get scanAgain => 'مسح مجددًا';

  @override
  String get joinHotspotSheetTitle => 'الانضمام إلى نقطة الاتصال';

  @override
  String get hotspotCredentialsHint =>
      'استخدم اسم نقطة الاتصال وكلمة المرور الظاهرين على جهاز الإرسال.';

  @override
  String get hotspotName => 'اسم نقطة الاتصال';

  @override
  String get password => 'كلمة المرور';

  @override
  String get joinAndScan => 'انضم وامسح';

  @override
  String get manualConnectBody =>
      'أدخل العنوان الظاهر على جهاز الإرسال. المنفذ اختياري وافتراضيًا 47811.';

  @override
  String get addressOrHost => 'العنوان أو المضيف:المنفذ';

  @override
  String get connect => 'اتصال';

  @override
  String get pairingCodeSheetTitle => 'أدخل رمز الاقتران';

  @override
  String get pairingCodeHint =>
      'على جهاز الإرسال، اضغط «نسخ الرمز» أسفل رمز QR ثم الصقه هنا. يبدأ الرمز بـ freesend://';

  @override
  String get pairingCodeLabel => 'رمز الاقتران';

  @override
  String get pasteFromClipboard => 'لصق من الحافظة';

  @override
  String filePickerFailed(Object error) {
    return 'تعذّر فتح منتقي الملفات: $error';
  }

  @override
  String get noAppBundles =>
      'لم يتم العثور على حزم تطبيقات قابلة للتثبيت على هذا الجهاز.';

  @override
  String get appBundleUnreadable => 'حزمة التطبيق هذه لم تعد قابلة للقراءة.';

  @override
  String get chooseFolderToSend => 'اختر مجلدًا لإرساله';

  @override
  String get androidFolderUnreadable =>
      'تعذّرت قراءة مجلد Android هذا. اختره مرة أخرى.';

  @override
  String get folderNotReadable => 'هذا المجلد غير قابل للقراءة.';

  @override
  String get folderNoReadableFiles =>
      'لا يحتوي هذا المجلد على ملفات قابلة للقراءة.';

  @override
  String labelCopied(Object label) {
    return 'تم نسخ $label';
  }

  @override
  String portOnly(Object port) {
    return 'المنفذ $port';
  }

  @override
  String get transferringTag => 'جارٍ النقل';

  @override
  String deviceConnected(Object name) {
    return '$name متصل';
  }

  @override
  String get genericDevice => 'جهاز';

  @override
  String get chooseReceivers => 'اختر من يستلم هذه الملفات';

  @override
  String get scanReceiverCode => 'امسح رمز المستلم';

  @override
  String get lookingForReceiver => 'البحث عن جهاز لاستلام هذه الملفات';

  @override
  String get noCandidatesBody =>
      'لا أحد جاهز بعد — على الجهاز الآخر، افتح FreeSend واضغط «استلام».';

  @override
  String get selectDevice => 'حدد جهازًا';

  @override
  String askDevices(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'اسأل $count جهاز',
      many: 'اسأل $count جهازًا',
      few: 'اسأل $count أجهزة',
      two: 'اسأل جهازين',
      one: 'اسأل جهازًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String get scanQrCode => 'مسح رمز QR';

  @override
  String get orJoinManually => 'أو انضم يدويًا';

  @override
  String get networkLabel => 'الشبكة';

  @override
  String get wired => 'سلكي';

  @override
  String get hotspotLabel => 'نقطة الاتصال';

  @override
  String get addressLabel => 'العنوان';

  @override
  String get pairingInstructions =>
      'على الجهاز الآخر، افتح FreeSend واختر «استلام» وامسح الرمز أعلاه — أو انضم إلى نقطة الاتصال هذه وستظهر الجلسة من تلقاء نفسها.';

  @override
  String preparingSummary(Object files, Object size) {
    return 'جارٍ التحضير لـ$files · $size';
  }

  @override
  String get stopSharing => 'إيقاف المشاركة';

  @override
  String sentToName(Object name) {
    return 'أُرسل إلى $name';
  }

  @override
  String get theOtherDevice => 'الجهاز الآخر';

  @override
  String get shareAgain => 'شارك هذه الملفات مجددًا';

  @override
  String get sharingStopped => 'توقفت المشاركة';

  @override
  String get couldNotShare => 'تعذّرت المشاركة';

  @override
  String get tryAgain => 'حاول مجددًا';

  @override
  String get backToFiles => 'العودة إلى الملفات';

  @override
  String get sendAnApp => 'إرسال تطبيق';

  @override
  String get installedApp => 'تطبيق مثبت';

  @override
  String appVersion(Object version) {
    return 'الإصدار $version';
  }

  @override
  String get addToTransfer => 'أضف إلى هذا التحويل';

  @override
  String get anyFileType => 'أي نوع ملف';

  @override
  String get mediaLibrary => 'مكتبة الوسائط';

  @override
  String get mediaLibraryHint => 'صور وفيديوهات وصوت مع معاينات';

  @override
  String get audioLabel => 'الصوت';

  @override
  String get docsHint => 'PDF وOffice ونصوص وCSV';

  @override
  String get appsLabel => 'التطبيقات';

  @override
  String get appsHint => 'حزم تطبيقات قابلة للتثبيت على هذا الجهاز';

  @override
  String get folderLabel => 'مجلد';

  @override
  String get folderHint => 'إرسال شجرة مجلد كاملة';

  @override
  String get waitingAnswer => 'في انتظار الرد';

  @override
  String get acceptedTag => 'مقبول';

  @override
  String get declinedTag => 'مرفوض';

  @override
  String get unreachable => 'تعذّر الوصول';

  @override
  String get shareNearby => 'مشاركة مع الأجهزة القريبة';

  @override
  String get shareNearbyHint => 'اعثر على أجهزة تنتظر الاستلام.';

  @override
  String get scanQrHint => 'اقرأ رمز المستلم بدلًا من انتظار ظهوره.';

  @override
  String get sendToGroup => 'إرسال إلى مجموعة';

  @override
  String get sendToGroupHint => 'اختر عدة أجهزة؛ كل جهاز يقبل بمفرده.';

  @override
  String get howToSend => 'كيف تريد الإرسال؟';

  @override
  String get close => 'إغلاق';

  @override
  String get scanHint => 'وجّه الكاميرا نحو الرمز على جهاز الإرسال.';

  @override
  String get scanWrongCode =>
      'هذا الرمز ليس من FreeSend. وجّه الكاميرا نحو الرمز على جهاز الإرسال.';

  @override
  String get cameraOff => 'الوصول إلى الكاميرا متوقف';

  @override
  String get cameraFailed => 'تعذّر تشغيل الكاميرا';

  @override
  String get cameraDeniedBody =>
      'يحتاج FreeSend إلى الكاميرا فقط لقراءة رمز الاقتران. اسمح به في إعدادات النظام، أو اكتب الرمز بدلًا من ذلك.';

  @override
  String get cameraBusyBody =>
      'قد يكون تطبيق آخر يستخدم الكاميرا. يمكنك أيضًا كتابة الرمز بدلًا من ذلك.';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get enterCodeInstead => 'أدخل الرمز بدلًا من ذلك';

  @override
  String get mediaTitle => 'الوسائط';

  @override
  String get mediaPermissionOff =>
      'الوصول إلى الصور متوقف. اسمح به في إعدادات النظام لتصفح هذا الجهاز.';

  @override
  String mediaReadFailed(Object error) {
    return 'تعذّرت قراءة مكتبة الوسائط: $error';
  }

  @override
  String albumReadFailed(Object error) {
    return 'تعذّرت قراءة هذا الألبوم: $error';
  }

  @override
  String get mediaItemsUnreadable =>
      'هذه العناصر غير قابلة للقراءة على هذا الجهاز.';

  @override
  String get searchAlbum => 'ابحث في هذا الألبوم';

  @override
  String get allFilter => 'الكل';

  @override
  String get photosFilter => 'الصور';

  @override
  String get albumLabel => 'الألبوم';

  @override
  String get preparing => 'جارٍ التحضير…';

  @override
  String sendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count عنصر',
      many: 'إرسال $count عنصرًا',
      few: 'إرسال $count عناصر',
      two: 'إرسال عنصرين',
      one: 'إرسال عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get mediaUnavailable => 'الوسائط غير متاحة';

  @override
  String get noMediaHere => 'لا توجد وسائط هنا';

  @override
  String get noMediaHint => 'اختر ألبومًا آخر أو اختر ملفات عبر منتقي النظام.';

  @override
  String get logsTitle => 'السجلات';

  @override
  String get logsCopied => 'تم نسخ السجلات';

  @override
  String savedTo(Object path) {
    return 'حُفظ في $path';
  }

  @override
  String get clearLogsQuestion => 'مسح السجلات؟';

  @override
  String get clearLogsBody =>
      'يحتفظ ملف السجل على الجهاز بسجله؛ يُفرَّغ هذا العرض فقط.';

  @override
  String get copyAll => 'نسخ الكل';

  @override
  String get saveToFile => 'حفظ في ملف';

  @override
  String get noLogEntries => 'لا توجد إدخالات سجل بعد.';

  @override
  String get logLevelDebug => 'تصحيح';

  @override
  String get logLevelInfo => 'معلومات';

  @override
  String get logLevelWarn => 'تحذير';

  @override
  String get logLevelError => 'خطأ';

  @override
  String get diagnostics => 'التشخيصات';

  @override
  String get diagnosticsBody =>
      'افحص وانسخ أو احفظ كل ما سجّله التطبيق في هذه الجلسة.';

  @override
  String get openLogs => 'فتح السجلات';

  @override
  String get checkingForUpdates => 'جارٍ البحث عن التحديثات';

  @override
  String updateAvailableTitle(Object version) {
    return 'الإصدار $version من FreeSend متاح';
  }

  @override
  String get askingGitLab => 'نسأل GitLab عمّا هو جديد.';

  @override
  String get whatsNew => 'ما الجديد';

  @override
  String youAreOn(Object version) {
    return 'أنت تستخدم الإصدار $version';
  }

  @override
  String sizeYouAreOn(Object size, Object version) {
    return '$size · أنت تستخدم الإصدار $version';
  }

  @override
  String downloadingPercent(Object percent) {
    return 'جارٍ التنزيل… $percent%';
  }

  @override
  String get downloadUpdate => 'تنزيل التحديث';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get installRestart => 'تثبيت وإعادة تشغيل';

  @override
  String get later => 'لاحقًا';

  @override
  String get gotIt => 'حسنًا';

  @override
  String get receivers => 'المستلمون';

  @override
  String peerProgress(Object count, Object done, Object sent, Object total) {
    return '$sent من $total · $done/$count ملفات';
  }

  @override
  String sendingFile(Object name) {
    return 'جارٍ إرسال $name';
  }

  @override
  String get sendingTag => 'جارٍ الإرسال';

  @override
  String get activeTag => 'نشط';

  @override
  String get connectingTag => 'جارٍ الاتصال';

  @override
  String get scanToPair => 'امسح للاقتران';

  @override
  String get pairingHotspotHint =>
      'على الجهاز الآخر، افتح FreeSend واختر «استلام» وامسح هذا. سينضم إلى نقطة الاتصال ويتصل من تلقاء نفسه.';

  @override
  String get pairingNoHotspotHint =>
      'على الجهاز الآخر، افتح FreeSend واختر «استلام» وامسح هذا للاتصال دون كتابة عنوان.';

  @override
  String copyLabel(Object label) {
    return 'نسخ $label';
  }

  @override
  String get etaMoment => 'لحظة';

  @override
  String get etaFinishing => 'يوشك على الانتهاء';

  @override
  String get etaEstimating => 'جارٍ التقدير';

  @override
  String todayAt(Object time) {
    return 'اليوم، $time';
  }

  @override
  String yesterdayAt(Object time) {
    return 'أمس، $time';
  }

  @override
  String get noWiredNetworkReceive =>
      'لم يتم العثور على شبكة سلكية. صِل كابل Ethernet ثم حاول مجددًا.';

  @override
  String get discoveryFailedBody =>
      'تعذّر بدء الاكتشاف. لا يزال بإمكانك الاتصال بعنوان IP.';

  @override
  String connectedLooking(Object ssid) {
    return 'تم الاتصال بـ\"$ssid\". جارٍ البحث عن جهاز المشاركة…';
  }

  @override
  String couldNotJoinHotspot(Object error) {
    return 'تعذّر الانضمام إلى نقطة الاتصال: $error';
  }

  @override
  String joinedHotspotNote(Object ssid) {
    return 'تم الانضمام إلى \"$ssid\".';
  }

  @override
  String joinHotspotManuallyNote(Object ssid) {
    return 'انضم إلى \"$ssid\" من قائمة الواي فاي. ستظهر الجلسة هنا فور اتصالك.';
  }

  @override
  String couldNotReachAddress(Object address) {
    return 'تعذّر الوصول إلى $address. تأكد أن الجهازين على نقطة الاتصال نفسها.';
  }

  @override
  String get transferDidNotFinish => 'لم يكتمل التحويل.';

  @override
  String get receivingFilesTitle => 'جارٍ استلام الملفات';

  @override
  String get retryingTransferTitle => 'جارٍ إعادة محاولة التحويل';

  @override
  String retryFailedFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'فشل $count ملف سابقًا',
      many: 'فشل $count ملفًا سابقًا',
      few: 'فشلت $count ملفات سابقًا',
      two: 'فشل ملفان سابقًا',
      one: 'فشل ملف واحد سابقًا',
    );
    return '$_temp0';
  }

  @override
  String receivingProgressTitle(Object sent, Object total) {
    return 'جارٍ استلام $sent من $total';
  }

  @override
  String get noWiredNetworkSend =>
      'لم يتم العثور على شبكة سلكية. صِل كابل Ethernet أو عُد إلى الواي فاي.';

  @override
  String get noLocalAddressSend =>
      'لم يتمكن FreeSend من العثور على عنوان محلي. اتصل بشبكة واي فاي أو استخدم كابلًا.';

  @override
  String get readyToShare => 'جاهز للمشاركة';

  @override
  String get waitingForReceiverNote => 'بانتظار جهاز مستلم';

  @override
  String listenerFailed(Object error) {
    return 'تعذّر فتح مستقبل التحويل. اسمح لـ FreeSend عبر جدار حماية النظام على الشبكات الخاصة ثم حاول مجددًا ($error).';
  }

  @override
  String couldNotStartSharing(Object error) {
    return 'تعذّر بدء المشاركة: $error';
  }

  @override
  String sendingProgressTitle(Object sent, Object total) {
    return 'جارٍ إرسال $sent من $total';
  }

  @override
  String get cannotJoinHotspot =>
      'لا يمكن لهذا الجهاز الانضمام إلى نقطة اتصال. استخدم شبكة واي فاي مشتركة بدلًا من ذلك.';

  @override
  String get hotspotWinNote =>
      'تتم المشاركة عبر شبكتك الحالية. لأسرع اتصال، فعّل «نقطة الاتصال المحمولة» في إعدادات Windows ثم صِل الجهاز الآخر بها.';

  @override
  String get hotspotMacNote =>
      'تتم المشاركة عبر شبكتك الحالية. لأسرع اتصال، فعّل «مشاركة الإنترنت» في إعدادات النظام ضمن General ثم صِل الجهاز الآخر بها.';

  @override
  String joinHotspotManuallyError(Object ssid) {
    return 'انضم إلى نقطة الاتصال \"$ssid\" من قائمة الواي فاي في نظامك ثم عُد إلى هنا.';
  }

  @override
  String get noWifiInterface => 'لم يتم العثور على واجهة واي فاي.';

  @override
  String couldNotJoinSsid(Object error, Object ssid) {
    return 'تعذّر الانضمام إلى \"$ssid\": $error';
  }

  @override
  String get noWifiAdapter =>
      'لم يتم العثور على محول واي فاي. اتصل بنقطة اتصال الجهاز الآخر بدلًا من ذلك.';

  @override
  String couldNotStartHotspot(Object error) {
    return 'تعذّر تشغيل نقطة الاتصال: $error';
  }

  @override
  String get noHotspotDetails => 'لم يُرجع النظام تفاصيل نقطة الاتصال.';

  @override
  String get couldNotStartHotspotPlain => 'تعذّر تشغيل نقطة الاتصال.';

  @override
  String couldNotJoinPlain(Object ssid) {
    return 'تعذّر الانضمام إلى \"$ssid\".';
  }

  @override
  String get hotspotPermissionRequired =>
      'يتطلب أندرويد إذن الموقع (أو الأجهزة القريبة) لاستخدام نقطة اتصال. فعّله في إعدادات النظام ثم حاول مجددًا.';
}
