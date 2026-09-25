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

  @override
  String get enRouteToPickup => 'في الطريق إلى الاستلام';

  @override
  String get atPickup => 'عند موقع الاستلام';

  @override
  String get previewApproach => 'معاينة المسار إلى الاستلام';

  @override
  String get dispatchToPickup => 'إرسال إلى موقع الاستلام';

  @override
  String get confirmPickupArrival => 'تأكيد الوصول إلى الاستلام';

  @override
  String get alreadyAtPickup => 'الشاحنة موجودة بالفعل ضمن نطاق موقع الاستلام.';

  @override
  String get approachDistance => 'مسافة الوصول إلى الاستلام';

  @override
  String get approachDuration => 'مدة الوصول إلى الاستلام';

  @override
  String get dispatchStarted => 'تم إرسال الشاحنة إلى موقع الاستلام.';

  @override
  String get truckPositionRequired => 'سجّل موقع الشاحنة الحالي قبل الإرسال.';

  @override
  String get truckPositionStale =>
      'موقع الشاحنة قديم. حدّث التتبع ثم حاول مرة أخرى.';

  @override
  String get truckOfflineForDispatch =>
      'يجب أن تكون الشاحنة متصلة قبل الإرسال.';

  @override
  String get repositioningRouteRequired =>
      'عاين مساراً حديثاً إلى الاستلام قبل الإرسال.';

  @override
  String get repositioningRouteStale =>
      'تحركت الشاحنة بعد المعاينة. احسب المسار مرة أخرى.';

  @override
  String get truckNotAtPickup => 'لم تصل الشاحنة إلى نطاق موقع الاستلام بعد.';

  @override
  String get approachRoute => 'المسار إلى الاستلام';

  @override
  String get cargoRoute => 'مسار الحمولة';

  @override
  String get proposed => 'مقترح';

  @override
  String get expired => 'منتهي الصلاحية';

  @override
  String get confirmLocation => 'تأكيد الموقع';

  @override
  String get setSimulatedLocation => 'تعيين موقع محاكى';

  @override
  String get moveSimulatedTruck => 'نقل الشاحنة المحاكاة';

  @override
  String get refreshLocation => 'تحديث الموقع نفسه';

  @override
  String get noLocation => 'لا يوجد موقع';

  @override
  String get currentLocation => 'حالي';

  @override
  String get staleLocation => 'قديم';

  @override
  String get noActiveTrucks => 'لا توجد شاحنات نشطة متاحة.';

  @override
  String get noLocationHelp =>
      'لم ترسل هذه الشاحنة موقعاً بعد. عيّن موقعاً محاكى لإظهارها على الخريطة.';

  @override
  String get currentLocationHelp =>
      'موقع GPS المحاكى حديث وتحافظ عليه نبضات دورية محدودة.';

  @override
  String get staleLocationHelp =>
      'حدّث الإحداثيات نفسها أو اختر موقعاً محاكى جديداً قبل الإرسال.';

  @override
  String get offlineLocationHelp =>
      'هذه الشاحنة غير متصلة صراحةً. عيّنها كمتصلة قبل التحديث أو الإرسال.';

  @override
  String locationAgeSeconds(int seconds) {
    return 'آخر تحديث منذ $seconds ثانية';
  }

  @override
  String locationForTruck(String plateNumber) {
    return 'الموقع المحاكى للشاحنة $plateNumber';
  }

  @override
  String get fixTruckLocation => 'تصحيح موقع الشاحنة';

  @override
  String get locationCorrectedRetry =>
      'تم تحديث موقع الشاحنة. أعد معاينة المسار عندما تكون جاهزاً.';

  @override
  String get pickupMarker => 'علامة الاستلام';

  @override
  String get deliveryMarker => 'علامة التسليم';

  @override
  String get tripTabActive => 'نشطة';

  @override
  String get tripTabPlanned => 'مخططة';

  @override
  String get tripTabCompleted => 'مكتملة';

  @override
  String get tripTabCancelled => 'ملغاة';

  @override
  String get tripTabArchived => 'مؤرشفة';

  @override
  String get searchTrips => 'ابحث برقم الرحلة أو العميل أو الموقع أو اللوحة';

  @override
  String get tripFilters => 'مرشحات الرحلات';

  @override
  String get clearFilters => 'مسح المرشحات';

  @override
  String get previousPage => 'الصفحة السابقة';

  @override
  String get nextPage => 'الصفحة التالية';

  @override
  String pageOf(int page, int pages, int total) {
    return 'الصفحة $page من $pages · $total رحلة';
  }

  @override
  String get incompleteDraft => 'مسودة غير مكتملة';

  @override
  String get draftIncomplete => 'تحتاج تفاصيل التخطيط';

  @override
  String get saveDraft => 'حفظ المسودة';

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get tripBasics => 'أساسيات الرحلة';

  @override
  String get pickupAndDelivery => 'الاستلام والتسليم';

  @override
  String get scheduleAndCommercial => 'الجدول والتفاصيل التجارية';

  @override
  String get routeNotCalculated => 'احفظ المواقع ثم احسب المسار المعتمد.';

  @override
  String get assignmentOptional => 'التعيين (اختياري)';

  @override
  String get assignmentAfterDraft =>
      'أكمل قائمة التخطيط ثم عيّن الموارد المتاحة من تفاصيل الرحلة.';

  @override
  String get review => 'المراجعة';

  @override
  String get saveDraftReview => 'راجع قائمة الجاهزية واحفظ هذه المسودة.';

  @override
  String get delete => 'حذف';

  @override
  String get reassign => 'إعادة تعيين';

  @override
  String get unassign => 'إلغاء التعيين';

  @override
  String get archive => 'أرشفة';

  @override
  String get unarchive => 'إلغاء الأرشفة';

  @override
  String get duplicateAsDraft => 'نسخ كمسودة';

  @override
  String get cancelTrip => 'إلغاء الرحلة';

  @override
  String get cancellationReason => 'سبب الإلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get timeline => 'الخط الزمني';

  @override
  String deleteDraftWarning(String tripNumber) {
    return 'حذف $tripNumber نهائياً؟ لا يمكن التراجع عن ذلك.';
  }

  @override
  String confirmTripAction(String tripNumber) {
    return 'تطبيق هذا الإجراء على $tripNumber؟';
  }

  @override
  String get tripNotReadyForRoute =>
      'أضف إحداثيات صحيحة للاستلام والتسليم قبل حساب المسار.';

  @override
  String get tripNotReadyForAssignment =>
      'أكمل قائمة التخطيط واحسب المسار الحالي قبل التعيين.';

  @override
  String get tripDeleteNotAllowed =>
      'يمكن حذف مسودة لم يبدأ إرسالها فقط حذفاً نهائياً.';

  @override
  String get tripCancelReasonRequired => 'أدخل سبب إلغاء لا يتجاوز 500 حرف.';

  @override
  String get tripArchiveNotAllowed =>
      'يمكن أرشفة أو استعادة الرحلات المكتملة أو الملغاة فقط.';

  @override
  String get tripReassignNotAllowed =>
      'لا يمكن إعادة تعيين هذه الرحلة بعد بدء الإرسال.';

  @override
  String get tripUnassignNotAllowed =>
      'لا يمكن إلغاء تعيين هذه الرحلة بعد بدء الإرسال.';

  @override
  String get tripConcurrencyConflict =>
      'عدّل مستخدم آخر هذه الرحلة. أعد تحميلها ثم حاول مجدداً.';

  @override
  String get eventTripCreated => 'تم إنشاء الرحلة';

  @override
  String get eventDraftUpdated => 'تم تحديث المسودة';

  @override
  String get eventStopsUpdated => 'تم تحديث المواقع';

  @override
  String get eventRouteCalculated => 'تم حساب المسار';

  @override
  String get eventAssigned => 'تم تعيين الموارد';

  @override
  String get eventReassigned => 'تمت إعادة تعيين الموارد';

  @override
  String get eventUnassigned => 'تم إلغاء تعيين الموارد';

  @override
  String get eventDispatchedToPickup => 'تم الإرسال إلى الاستلام';

  @override
  String get eventArrivedAtPickup => 'تم الوصول إلى الاستلام';

  @override
  String get eventTripStarted => 'بدأت الرحلة';

  @override
  String get eventMarkedInTransit => 'تم تحديدها قيد النقل';

  @override
  String get eventDelivered => 'تم التسليم';

  @override
  String get eventCompleted => 'اكتملت الرحلة';

  @override
  String get eventCancelled => 'ألغيت الرحلة';

  @override
  String get eventArchived => 'تمت الأرشفة';

  @override
  String get eventUnarchived => 'تم إلغاء الأرشفة';

  @override
  String get eventImportedBaseline => 'سجل الاستيراد الأساسي';

  @override
  String get eventRouteInvalidated => 'تم إبطال المسار';

  @override
  String get identicalStops => 'يجب أن يكون موقعا الاستلام والتسليم مختلفين.';

  @override
  String get routeStale => 'تغيرت المواقع. أعد حساب المسار قبل المتابعة.';

  @override
  String get routeRequired => 'احسب المسار قبل المتابعة.';

  @override
  String get assignmentSelectionRequired =>
      'اختر شاحنة وسائقاً مؤهلين أو تجاوز التعيين الآن.';

  @override
  String get tripCreatedAndAssigned => 'تم حفظ الرحلة وتعيين الموارد.';

  @override
  String get draftSaved => 'تم حفظ المسودة.';

  @override
  String get tripDetailsStep => 'تفاصيل الرحلة';

  @override
  String get tripNumber => 'رقم الرحلة';

  @override
  String get locationsAndRouteStep => 'الاستلام والتسليم والمسار';

  @override
  String get truckAndDriverStep => 'الشاحنة والسائق';

  @override
  String get reviewAndConfirmStep => 'المراجعة والتأكيد';

  @override
  String get invalidNumber => 'أدخل رقماً صحيحاً غير سالب.';

  @override
  String get recalculateRoute => 'إعادة حساب المسار';

  @override
  String get refreshAvailability => 'تحديث التوفر';

  @override
  String get skipForNow => 'تجاوز التعيين الآن';

  @override
  String get keepAsUnassignedDraft => 'احتفظ بهذه الرحلة كمسودة غير معيّنة.';

  @override
  String get noEligibleTruck => 'لا توجد شاحنة مؤهلة متاحة حالياً.';

  @override
  String get noEligibleDriver => 'لا يوجد سائق مؤهل متاح حالياً.';

  @override
  String get allocatedAfterSave => 'يُخصّص بعد الحفظ';

  @override
  String get notAvailable => 'غير متوفر';

  @override
  String get distance => 'المسافة';

  @override
  String get estimatedDuration => 'المدة المقدرة';

  @override
  String get readiness => 'الجاهزية';

  @override
  String get ready => 'جاهزة';

  @override
  String get editTripDetails => 'تعديل تفاصيل الرحلة';

  @override
  String get editLocationsAndRoute => 'تعديل المواقع والمسار';

  @override
  String get editAssignment => 'تعديل التعيين';

  @override
  String get createAndAssignTrip => 'إنشاء الرحلة وتعيينها';

  @override
  String get assignTrip => 'تعيين الرحلة';

  @override
  String get routeSummary => 'ملخص المسار';

  @override
  String get resourceInactive => 'غير نشط';

  @override
  String get truckInMaintenance => 'قيد الصيانة';

  @override
  String get truckOutOfServiceReason => 'خارج الخدمة';

  @override
  String resourceAssignedToTrip(String tripNumber) {
    return 'محجوز للرحلة $tripNumber';
  }

  @override
  String get details => 'التفاصيل';

  @override
  String get legalName => 'الاسم القانوني';

  @override
  String get lifecycle => 'دورة الحالة';

  @override
  String get all => 'الكل';

  @override
  String get suspended => 'موقوف';

  @override
  String get reserved => 'محجوز';

  @override
  String get archived => 'مؤرشف';

  @override
  String get contacts => 'جهات الاتصال';

  @override
  String get sites => 'المواقع المحفوظة';

  @override
  String get addContact => 'إضافة جهة اتصال';

  @override
  String get jobTitle => 'المسمى الوظيفي';

  @override
  String get whatsApp => 'واتساب';

  @override
  String get primaryContact => 'جهة الاتصال الرئيسية';

  @override
  String get addSite => 'إضافة موقع';

  @override
  String get siteType => 'نوع الموقع';

  @override
  String get latitude => 'خط العرض';

  @override
  String get longitude => 'خط الطول';

  @override
  String get instructions => 'التعليمات';

  @override
  String get restore => 'استعادة';

  @override
  String get suspend => 'إيقاف';

  @override
  String get reactivate => 'إعادة تنشيط';

  @override
  String get plannedTrips => 'الرحلات المخططة';

  @override
  String get completedTrips => 'الرحلات المكتملة';

  @override
  String get cancelledTrips => 'الرحلات الملغاة';

  @override
  String get activity => 'النشاط';

  @override
  String get noActivity => 'لا يوجد نشاط بعد';

  @override
  String get fleetCode => 'رمز الأسطول';

  @override
  String get searchTrucks => 'البحث عن الشاحنات';

  @override
  String get vin => 'رقم الهيكل';

  @override
  String get truckType => 'نوع الشاحنة';

  @override
  String get payloadCapacity => 'سعة الحمولة';

  @override
  String get payloadUnit => 'وحدة الحمولة';

  @override
  String get fuelType => 'نوع الوقود';

  @override
  String get odometer => 'عداد المسافة (كم)';

  @override
  String get correctOdometer => 'تصحيح عداد المسافة';

  @override
  String get correctionReason => 'سبب التصحيح';

  @override
  String get defaultDriver => 'السائق الافتراضي';

  @override
  String get baseStatus => 'الحالة الأساسية';

  @override
  String get operationalState => 'الحالة التشغيلية';

  @override
  String get currentTrip => 'الرحلة الحالية';

  @override
  String get latestPosition => 'آخر موقع';

  @override
  String get noPosition => 'لم يتم الإبلاغ عن موقع';

  @override
  String get clientArchived => 'تمت أرشفة العميل.';

  @override
  String get clientRestored => 'تمت استعادة العميل.';

  @override
  String get truckArchived => 'تمت أرشفة الشاحنة.';

  @override
  String get truckRestored => 'تمت استعادة الشاحنة.';

  @override
  String get factory => 'مصنع';

  @override
  String get warehouse => 'مستودع';

  @override
  String get office => 'مكتب';

  @override
  String get other => 'أخرى';

  @override
  String get kilograms => 'كيلوغرام';

  @override
  String get tonnes => 'طن';

  @override
  String get diesel => 'ديزل';

  @override
  String get petrol => 'بنزين';

  @override
  String get electric => 'كهربائي';

  @override
  String get hybrid => 'هجين';

  @override
  String get boxTruck => 'شاحنة صندوقية';

  @override
  String get flatbed => 'سطحة';

  @override
  String get refrigerated => 'مبردة';

  @override
  String get tanker => 'صهريج';

  @override
  String get tractorTrailer => 'قاطرة ومقطورة';

  @override
  String get dumpTruck => 'شاحنة قلابة';

  @override
  String get savedSite => 'موقع عميل محفوظ';

  @override
  String get siteSaved => 'تم حفظ موقع العميل.';

  @override
  String get defaultDriverSuggested => 'تم اقتراح السائق الافتراضي';

  @override
  String get eventClientCreated => 'تم إنشاء العميل';

  @override
  String get eventClientProfileUpdated => 'تم تحديث ملف العميل';

  @override
  String get eventClientSuspended => 'تم إيقاف العميل';

  @override
  String get eventClientReactivated => 'تمت إعادة تنشيط العميل';

  @override
  String get eventClientArchived => 'تمت أرشفة العميل';

  @override
  String get eventClientContactAdded => 'تمت إضافة جهة اتصال';

  @override
  String get eventClientContactUpdated => 'تم تحديث جهة الاتصال';

  @override
  String get eventClientContactRemoved => 'تم حذف جهة الاتصال';

  @override
  String get eventClientPrimaryContactChanged =>
      'تم تغيير جهة الاتصال الرئيسية';

  @override
  String get eventClientSiteAdded => 'تمت إضافة موقع';

  @override
  String get eventClientSiteUpdated => 'تم تحديث الموقع';

  @override
  String get eventClientSiteArchived => 'تمت أرشفة الموقع';

  @override
  String get eventClientSiteRestored => 'تمت استعادة الموقع';

  @override
  String get eventTruckCreated => 'تم إنشاء الشاحنة';

  @override
  String get eventTruckProfileUpdated => 'تم تحديث ملف الشاحنة';

  @override
  String get eventTruckDefaultDriverChanged => 'تم تغيير السائق الافتراضي';

  @override
  String get eventTruckOdometerUpdated => 'تم تحديث عداد المسافة';

  @override
  String get eventTruckOdometerCorrected => 'تم تصحيح عداد المسافة';

  @override
  String get eventTruckBaseStatusChanged => 'تم تغيير الحالة الأساسية';

  @override
  String get eventTruckArchived => 'تمت أرشفة الشاحنة';

  @override
  String get eventTruckRestored => 'تمت استعادة الشاحنة';

  @override
  String get clientArchiveRequired => 'أرشف العميل قبل حذفه.';

  @override
  String get deleteClientWarning =>
      'حذف هذا العميل غير المستخدم نهائياً؟ لا يمكن التراجع عن ذلك.';

  @override
  String get clientHasHistory => 'لهذا العميل سجل رحلات ولا يمكن حذفه.';

  @override
  String get truckArchiveRequired => 'أرشف الشاحنة قبل حذفها.';

  @override
  String get deleteTruckWarning =>
      'حذف هذه الشاحنة غير المستخدمة نهائياً؟ لا يمكن التراجع عن ذلك.';

  @override
  String get truckHasHistory =>
      'لهذه الشاحنة سجل رحلات أو تتبع ولا يمكن حذفها.';

  @override
  String get truckReserved => 'هذه الشاحنة محجوزة لرحلة نشطة.';

  @override
  String get odometerCorrectionRequired =>
      'استخدم مسار التصحيح وأدخل سبباً لتخفيض عداد المسافة.';

  @override
  String get defaultDriverInactive => 'يجب أن يكون السائق الافتراضي نشطاً.';

  @override
  String get duplicateTruckIdentity =>
      'رقم اللوحة أو الهيكل أو رمز الأسطول مستخدم بالفعل.';

  @override
  String get uploadTruckPhoto => 'رفع صورة الشاحنة';

  @override
  String get removeTruckPhoto => 'إزالة صورة الشاحنة';

  @override
  String get notifications => 'الإشعارات';

  @override
  String get markAllRead => 'تعليم الكل كمقروء';

  @override
  String get noNotifications => 'لا توجد إشعارات بعد';

  @override
  String get markRead => 'تعليم كمقروء';

  @override
  String get notificationArrivedPickup => 'وصلت الشاحنة إلى موقع الاستلام';

  @override
  String get notificationArrivedDelivery => 'وصلت الشاحنة إلى موقع التسليم';

  @override
  String get notificationDepartureConfirmed =>
      'تم تأكيد تحميل الشحنة والمغادرة';

  @override
  String get notificationDeliveryConfirmed => 'تم تأكيد التسليم';

  @override
  String get operationalUpdate => 'تحديث تشغيلي';

  @override
  String get myTrip => 'رحلتي';

  @override
  String get noAssignedTrip => 'لا توجد رحلة نشطة مسندة إليك';

  @override
  String get confirmLoaded => 'تأكيد التحميل وبدء الرحلة';

  @override
  String get confirmLoadedWarning =>
      'هل تؤكد تحميل الشحنة والمغادرة من موقع الاستلام؟';

  @override
  String get confirmDelivery => 'تأكيد التسليم';

  @override
  String get confirmDeliveryWarning =>
      'هل تؤكد اكتمال تسليم الشحنة؟ سيؤدي ذلك إلى إكمال الرحلة.';

  @override
  String get atDelivery => 'عند موقع التسليم';

  @override
  String get managerOverrideDeparture => 'تجاوز تأكيد المغادرة';

  @override
  String get managerOverrideDelivery => 'تجاوز تأكيد التسليم';

  @override
  String get managerOverride => 'تجاوز المدير';

  @override
  String get managerOverrideWarning =>
      'استخدم هذا فقط عندما يتعذر على السائق المرتبط التأكيد. سيتم تدقيق السبب وهويتك.';

  @override
  String get overrideReason => 'سبب التجاوز';

  @override
  String get resumeFollow => 'استئناف التتبع';

  @override
  String get showFullRoute => 'عرض المسار بالكامل';

  @override
  String get actionConfirmed => 'تم حفظ التأكيد.';

  @override
  String get backToTruck => 'العودة إلى الشاحنة';

  @override
  String get companyUsers => 'مستخدمو الشركة';

  @override
  String get allUsers => 'جميع المستخدمين';

  @override
  String get activeUsers => 'المستخدمون النشطون';

  @override
  String get inactiveUsers => 'المستخدمون غير النشطين';

  @override
  String get createDriverAccount => 'إنشاء حساب سائق';

  @override
  String get noCompanyUsers => 'لا يوجد مستخدمون يطابقون هذا الفلتر.';

  @override
  String get noDriverLinked => 'غير مرتبط بسجل سائق';

  @override
  String get resetTemporaryPassword => 'إعادة تعيين كلمة المرور المؤقتة';

  @override
  String get unlinkDriverAccount => 'إلغاء ربط حساب السائق';

  @override
  String get unlinkDriverAccountConfirmation =>
      'هل تريد إلغاء ربط حساب التطبيق بسجل السائق؟ لن يتمكن السائق بعد ذلك من استلام الرحلات أو تأكيدها في وضع السائق.';

  @override
  String get displayName => 'اسم العرض';

  @override
  String get linkDriver => 'ربط سجل السائق (اختياري)';

  @override
  String get temporaryPassword => 'كلمة المرور المؤقتة';

  @override
  String get temporaryPasswordOnce =>
      'تظهر كلمة المرور الآن فقط. انسخها وشاركها مع السائق بطريقة آمنة.';

  @override
  String get copy => 'نسخ';

  @override
  String get done => 'تم';

  @override
  String get create => 'إنشاء';

  @override
  String get noAppAccount => 'لا يوجد حساب تطبيق';

  @override
  String get appAccountLinked => 'حساب التطبيق مرتبط';

  @override
  String get accountInactive => 'الحساب غير نشط';

  @override
  String get accountInactiveWarning =>
      'حساب التطبيق المرتبط غير نشط؛ لا يمكن لهذا السائق استخدام وضع السائق.';

  @override
  String get noAppAccountWarning =>
      'لا يملك هذا السائق حساب تطبيق ولا يمكنه استلام الرحلة أو تأكيدها في وضع السائق.';

  @override
  String get driverAppAccountWarning => 'تحذير حساب تطبيق السائق';

  @override
  String get accountInactiveAssignmentConfirmation =>
      'هل تريد إسناد الرحلة رغم أن حساب السائق المرتبط غير نشط؟';

  @override
  String get unlinkedAssignmentConfirmation =>
      'هل تريد إسناد الرحلة رغم أن السائق لا يملك حساب تطبيق؟';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get driverAppAccount => 'حساب تطبيق السائق';

  @override
  String get createAndLinkAccount => 'إنشاء الحساب وربطه';

  @override
  String get linkExistingAccount => 'ربط حساب موجود';

  @override
  String get noUnlinkedDriverAccounts =>
      'لا توجد حسابات سائق نشطة وغير مرتبطة.';

  @override
  String get loadingSavedSites => 'جارٍ تحميل المواقع المحفوظة…';

  @override
  String get savedSitesLoadFailed => 'تعذر تحميل المواقع المحفوظة';

  @override
  String get noSavedSites => 'لا توجد مواقع محفوظة لهذا العميل';

  @override
  String get driverAccountNotLinked => 'حسابك غير مرتبط بسجل سائق';

  @override
  String get contactOwnerToLinkDriver =>
      'تواصل مع مالك الشركة لربط تسجيل الدخول بسجل السائق الخاص بك.';

  @override
  String get noAssignedTripExplanation =>
      'سيظهر أي إسناد جديد هنا تلقائياً. يمكنك السحب للتحديث في أي وقت.';

  @override
  String get nextStop => 'المحطة التالية';

  @override
  String get estimatedArrival => 'وقت الوصول المتوقع';

  @override
  String get lastPositionUpdate => 'آخر تحديث للموقع';

  @override
  String get allowedDriverAction => 'الإجراء المتاح للسائق';

  @override
  String get noActionAvailable => 'لا يوجد إجراء متاح حالياً';

  @override
  String get trackingNotStarted => 'لم يبدأ التتبع';

  @override
  String get trackingStale => 'الموقع قديم';

  @override
  String get trackingOffline => 'الشاحنة غير متصلة';

  @override
  String get trackingCurrent => 'الموقع محدّث';

  @override
  String nonProductionEnvironment(String environment) {
    return 'بيئة غير إنتاجية: $environment';
  }

  @override
  String get accountIdentity => 'الحساب والبيئة';

  @override
  String get signedInEmail => 'البريد المسجل';

  @override
  String get companyName => 'اسم الشركة';

  @override
  String get role => 'الدور';

  @override
  String get environment => 'البيئة';

  @override
  String get notificationSounds => 'أصوات الإشعارات';

  @override
  String get notificationSoundsDescription =>
      'تشغيل صوت قصير واحد للتنبيهات التشغيلية الجديدة أثناء فتح التطبيق.';

  @override
  String get soundTestPlayed => 'تم طلب تشغيل صوت الاختبار.';

  @override
  String get testSound => 'اختبار الصوت';

  @override
  String get enableNotificationSound => 'تفعيل صوت الإشعارات';

  @override
  String get dismiss => 'إغلاق';

  @override
  String get view => 'عرض';

  @override
  String get notificationTripAssigned => 'تم إسناد رحلة جديدة';

  @override
  String get notificationTruckOffline => 'انقطع اتصال الشاحنة';

  @override
  String get notificationPositionStale => 'أصبح موقع الشاحنة قديماً';

  @override
  String get operationalAlertMessage =>
      'يوجد حدث تشغيلي جديد يحتاج إلى انتباهك.';

  @override
  String get operationalTripAlertMessage =>
      'يوجد حدث تشغيلي متعلق برحلة يحتاج إلى انتباهك.';
}
