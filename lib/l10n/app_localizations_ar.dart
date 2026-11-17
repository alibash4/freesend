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
  String get notSetYet => 'لم يُحدد بعد';

  @override
  String get changeFolder => 'تغيير المجلد';

  @override
  String get appearance => 'المظهر';

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
  String get systemTray => 'منطقة النظام';

  @override
  String get minimizeToTray => 'التصغير إلى منطقة النظام عند الإغلاق';

  @override
  String get keepRunningInTray =>
      'إبقاء FreeSend يعمل في منطقة النظام عند إغلاق النافذة.';

  @override
  String get hapticFeedback => 'الاستجابة عند اللمس';

  @override
  String get hapticFeedbackSubtitle =>
      'شعور بنقرة خفيفة عند التنقل بين الأقسام.';

  @override
  String get data => 'البيانات';

  @override
  String get localDataExplanation =>
      'يحتفظ FreeSend بقائمة محلية بالتحويلات السابقة فقط. لا يتم رفع الملفات أبدًا — يتحدث الجهازان مباشرة عبر رابط نقطة الاتصال.';

  @override
  String get clearTransferHistory => 'مسح سجل التحويلات';

  @override
  String get updates => 'التحديثات';

  @override
  String get checkAutomatically => 'التحقق تلقائيًا';

  @override
  String get lookForNewerRelease =>
      'ابحث عن إصدار أحدث في كل مرة يبدأ فيها FreeSend.';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

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
      'فعّل هذه بالترتيب. يبقى FreeSend على الرابط المحلي، ولا يمكنه البدء حتى يتم تفعيل ما هو مطلوب.';

  @override
  String get setupNearbyTitle => 'الأجهزة القريبة';

  @override
  String get setupNearbyBody =>
      'يتيح لـ FreeSend فتح نقطة الاتصال التي يستخدمها النقل أو الانضمام إليها.';

  @override
  String get setupNotificationsTitle => 'الإشعارات';

  @override
  String get setupNotificationsBody =>
      'يبقي عملية النقل تعمل عند مغادرة التطبيق.';

  @override
  String get setupCameraTitle => 'الكاميرا';

  @override
  String get setupCameraBody =>
      'تقرأ رمز الإقران المعروض على الجهاز الآخر. يمكنك لصق الرمز بدلًا من ذلك.';

  @override
  String get setupOptional => 'اختياري';

  @override
  String get setupEnable => 'تفعيل';

  @override
  String get setupSettings => 'الإعدادات';

  @override
  String get permTitle => 'قبل أن تبدأ';

  @override
  String get permIntro =>
      'يحتاج FreeSend إلى الوصول إلى الرابط المحلي والكاميرا للعثور على الأجهزة القريبة ومسح رموز الاقتران. لا يغادر أي شيء شبكتك.';

  @override
  String get permSection => 'الأذونات';

  @override
  String get permLocationTitle => 'الموقع / الأجهزة القريبة';

  @override
  String get permLocationBody =>
      'يتطلبه أندرويد لإنشاء نقطة اتصال أو الانضمام إليها واكتشاف أجهزة FreeSend الأخرى.';

  @override
  String get permNearbyTitle => 'أجهزة Wi-Fi القريبة';

  @override
  String get permNearbyBody => 'يُستخدم في أندرويد 13 وما فوق لاكتشاف الأجهزة.';

  @override
  String get permLocalNetworkTitle => 'الشبكة المحلية';

  @override
  String get permNotificationsTitle => 'الإشعارات';

  @override
  String get permNotificationsBody =>
      'يعرض تقدم التحويل أثناء وجود FreeSend في الخلفية.';

  @override
  String get permMediaTitle => 'الصور ومقاطع الفيديو والصوت';

  @override
  String get permMediaBody =>
      'يستخدمه متصفح الوسائط لعرض الصور المصغرة وتتيح لك اختيار الملفات.';

  @override
  String get permCameraTitle => 'الكاميرا';

  @override
  String get permCameraBody =>
      'تُستخدم فقط لمسح رمز QR الخاص بالاقتران. لا يزال بإمكانك الاقتران بكتابة الرمز أو لصقه.';

  @override
  String get permAllowed => 'مسموح';

  @override
  String get permBlocked => 'محظور';

  @override
  String get permNotAsked => 'لم يُطلب';

  @override
  String get permAllSet => 'تم منح الأذونات. FreeSend جاهز.';

  @override
  String get permChangeLater => 'يمكنك تغييرها لاحقًا في إعدادات النظام.';

  @override
  String get permRequesting => 'جارٍ الطلب…';

  @override
  String get permContinue => 'متابعة';

  @override
  String get permAllow => 'السماح بالأذونات';

  @override
  String get permOpenSettings => 'فتح إعدادات النظام';
}
