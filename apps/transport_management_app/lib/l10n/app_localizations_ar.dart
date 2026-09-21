// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'إدارة النقل';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signInPrompt => 'سجّل الدخول إلى مساحة عمل شركتك';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get dashboard => 'لوحة التشغيل';

  @override
  String get clients => 'العملاء';

  @override
  String get trucks => 'الشاحنات';

  @override
  String get drivers => 'السائقون';

  @override
  String get trips => 'الرحلات';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get english => 'English';

  @override
  String get arabic => 'العربية';

  @override
  String get fleetMap => 'خريطة الأسطول';

  @override
  String get simulator => 'محاكي التتبع';

  @override
  String get start => 'بدء';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get resume => 'متابعة';

  @override
  String get stop => 'إيقاف';

  @override
  String get reset => 'إعادة ضبط';

  @override
  String get refresh => 'تحديث';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get required => 'مطلوب';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get close => 'إغلاق';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get genericError => 'تعذر إكمال الطلب.';

  @override
  String get invalidTripTransition =>
      'هذا الإجراء غير متاح في حالة الرحلة الحالية.';

  @override
  String get truckAlreadyAssigned => 'هذه الشاحنة مرتبطة برحلة نشطة أخرى.';

  @override
  String get driverAlreadyAssigned => 'هذا السائق مرتبط برحلة نشطة أخرى.';

  @override
  String get truckNotAvailable => 'الشاحنة المحددة غير متاحة.';

  @override
  String get driverNotAvailable => 'السائق المحدد غير متاح.';

  @override
  String get clientNotFound => 'لم يتم العثور على العميل المحدد.';

  @override
  String get noTrackedTrucks =>
      'لا توجد شاحنات متتبعة. شغّل المحاكي لإنشاء المواقع.';

  @override
  String get totalTrucks => 'إجمالي الشاحنات';

  @override
  String get availableTrucks => 'متاحة';

  @override
  String get onTripTrucks => 'في رحلة';

  @override
  String get maintenanceTrucks => 'صيانة';

  @override
  String get outOfServiceTrucks => 'خارج الخدمة';

  @override
  String get activeTrips => 'الرحلات النشطة';

  @override
  String get completedToday => 'المكتملة اليوم';

  @override
  String get onlineTracked => 'متصلة';

  @override
  String get offlineTracked => 'غير متصلة';

  @override
  String get recentTrips => 'أحدث الرحلات';

  @override
  String get online => 'متصل';

  @override
  String get offline => 'غير متصل';

  @override
  String get speed => 'السرعة';

  @override
  String get lastUpdate => 'آخر تحديث';

  @override
  String get driver => 'السائق';

  @override
  String get activeTrip => 'الرحلة النشطة';

  @override
  String get notAssigned => 'غير معين';

  @override
  String get available => 'متاحة';

  @override
  String get onTrip => 'في رحلة';

  @override
  String get maintenance => 'صيانة';

  @override
  String get outOfService => 'خارج الخدمة';

  @override
  String get unavailable => 'غير متاح';

  @override
  String get draft => 'مسودة';

  @override
  String get assigned => 'معينة';

  @override
  String get started => 'بدأت';

  @override
  String get inTransit => 'قيد النقل';

  @override
  String get delivered => 'تم التسليم';

  @override
  String get completed => 'مكتملة';

  @override
  String get cancelled => 'ملغاة';

  @override
  String get localeSaved => 'تم تحديث اللغة.';

  @override
  String get simulatorDisabled => 'المحاكي معطل في هذه البيئة.';

  @override
  String get noClients => 'لا يوجد عملاء بعد.';

  @override
  String get noTrucks => 'لا توجد شاحنات بعد.';

  @override
  String get noDrivers => 'لا يوجد سائقون بعد.';

  @override
  String get noTrips => 'لا توجد رحلات بعد.';

  @override
  String get newClient => 'عميل جديد';

  @override
  String get newTruck => 'شاحنة جديدة';

  @override
  String get newDriver => 'سائق جديد';

  @override
  String get newTrip => 'رحلة جديدة';

  @override
  String get searchClients => 'بحث عن العملاء';

  @override
  String get name => 'الاسم';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phone => 'الهاتف';

  @override
  String get contactPerson => 'جهة الاتصال';

  @override
  String get address => 'العنوان';

  @override
  String get plateNumber => 'رقم اللوحة';

  @override
  String get make => 'الشركة المصنعة';

  @override
  String get model => 'الطراز';

  @override
  String get year => 'السنة';

  @override
  String get licenseNumber => 'رقم الرخصة';

  @override
  String get licenseExpiry => 'انتهاء الرخصة (YYYY-MM-DD)';

  @override
  String get origin => 'نقطة الانطلاق';

  @override
  String get destination => 'الوجهة';

  @override
  String get cargo => 'الحمولة';

  @override
  String get plannedStart => 'موعد البدء المخطط';

  @override
  String get price => 'السعر';

  @override
  String get assign => 'تعيين';

  @override
  String get markInTransit => 'بدء النقل';

  @override
  String get deliver => 'تسليم';

  @override
  String get complete => 'إكمال';

  @override
  String get edit => 'تعديل';

  @override
  String get deactivate => 'تعطيل';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get createClient => 'إنشاء عميل';

  @override
  String get editClient => 'تعديل العميل';

  @override
  String get createTruck => 'إنشاء شاحنة';

  @override
  String get editTruck => 'تعديل الشاحنة';

  @override
  String get createDriver => 'إنشاء سائق';

  @override
  String get editDriver => 'تعديل السائق';

  @override
  String get createTrip => 'إنشاء رحلة';

  @override
  String get editDraftTrip => 'تعديل مسودة الرحلة';

  @override
  String get editDraft => 'تعديل المسودة';

  @override
  String get setAvailable => 'تعيين كمتاح';

  @override
  String get setUnavailable => 'تعيين كغير متاح';

  @override
  String get setMaintenance => 'تعيين للصيانة';

  @override
  String get status => 'الحالة';

  @override
  String get notes => 'ملاحظات';

  @override
  String get license => 'الرخصة';

  @override
  String get planned => 'الموعد المخطط';

  @override
  String get client => 'العميل';

  @override
  String get truck => 'الشاحنة';

  @override
  String get unknownClient => 'عميل غير معروف';

  @override
  String get unknown => 'غير معروف';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get validYear => 'أدخل سنة صحيحة.';

  @override
  String get validDate => 'أدخل تاريخًا صحيحًا.';

  @override
  String get validPrice => 'أدخل سعرًا صحيحًا.';

  @override
  String get savedSuccessfully => 'تم الحفظ بنجاح.';

  @override
  String get clientDeactivated => 'تم تعطيل العميل.';

  @override
  String get tripStatusUpdated => 'تم تحديث حالة الرحلة.';

  @override
  String get resourcesAssigned => 'تم تعيين الشاحنة والسائق.';

  @override
  String get tripNotFound => 'لم يتم العثور على الرحلة.';

  @override
  String get backToTrips => 'العودة إلى الرحلات';

  @override
  String get assignResources => 'تعيين الموارد';

  @override
  String get authenticationFailed =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة.';

  @override
  String get mapNotConfigured =>
      'نمط الخريطة غير مهيأ. أضف MAP_STYLE_URL لاستخدام الخريطة الجغرافية.';

  @override
  String get loadingMap => 'جارٍ تحميل نمط الخريطة…';

  @override
  String get mapStyleLoaded => 'الخريطة جاهزة (تم تحميل النمط)';

  @override
  String get mapFailed =>
      'تعذر تحميل نمط الخريطة. يمكنك إعادة المحاولة أو استخدام عرض التتبع المبسط.';

  @override
  String get retryMap => 'إعادة تحميل الخريطة';

  @override
  String get useFallback => 'استخدام العرض المبسط';

  @override
  String get fallbackMode => 'عرض تتبع مبسط — ليس خريطة جغرافية';

  @override
  String get step => 'خطوة';

  @override
  String get simulationSpeed => 'سرعة المحاكاة';

  @override
  String get applySpeed => 'تطبيق السرعة';

  @override
  String get selectTruck => 'اختيار الشاحنة';

  @override
  String get setOnline => 'تعيين كمتصلة';

  @override
  String get setOffline => 'تعيين كغير متصلة';

  @override
  String get simulatorCommandSucceeded => 'تم تنفيذ أمر المحاكي.';

  @override
  String get planTrip => 'تخطيط رحلة';

  @override
  String get pickup => 'الاستلام';

  @override
  String get delivery => 'التسليم';

  @override
  String get locationName => 'اسم الموقع';

  @override
  String get searchLocation => 'البحث عن موقع';

  @override
  String get searchResults => 'نتائج المواقع';

  @override
  String get noLocationResults =>
      'لم يتم العثور على مواقع مطابقة. يمكنك إدخال الإحداثيات يدوياً.';

  @override
  String get latitude => 'خط العرض';

  @override
  String get longitude => 'خط الطول';

  @override
  String get invalidCoordinate => 'أدخل إحداثياً صالحاً.';

  @override
  String get routePreview => 'معاينة المسار';

  @override
  String get calculateRoute => 'حساب المسار';

  @override
  String get calculatingRoute => 'جارٍ حساب المسار…';

  @override
  String get calculateRouteHint =>
      'اختر موقعي الاستلام والتسليم ثم احسب مسار الطريق.';

  @override
  String get routeProviderUnavailable =>
      'تعذر حساب المسار. تحقق من مزود التوجيه ثم حاول مجدداً.';

  @override
  String get saveTrip => 'حفظ الرحلة';

  @override
  String get onlineOnly => 'المتصلة فقط';

  @override
  String get movingOnly => 'المتحركة فقط';

  @override
  String get routeProgress => 'تقدم المسار';

  @override
  String get remainingDistance => 'المسافة المتبقية';

  @override
  String get eta => 'وقت الوصول المتوقع';

  @override
  String get offRoute => 'خارج المسار';

  @override
  String get onRoute => 'على المسار';

  @override
  String get legacyTripRouteWarning =>
      'تحتوي هذه الرحلة القديمة على أسماء المواقع فقط. اختر موقعي الاستلام والتسليم قبل الإسناد.';

  @override
  String get routeDistance => 'مسافة المسار';

  @override
  String get routeDuration => 'المدة المقدرة';

  @override
  String get routeProvider => 'مزود التوجيه';

  @override
  String get selectOnMap => 'اختيار من الخريطة';

  @override
  String get tapMapToSelect => 'اضغط على الخريطة لاختيار هذا الموقع';

  @override
  String get moving => 'متحركة';

  @override
  String get stationary => 'متوقفة';

  @override
  String get recenter => 'إعادة التوسيط';

  @override
  String get fitRoute => 'ملاءمة المسار';

  @override
  String get fleetList => 'الأسطول';

  @override
  String get plannedRoute => 'المسار المخطط';

  @override
  String get travelledTrail => 'المسار المقطوع';
}
