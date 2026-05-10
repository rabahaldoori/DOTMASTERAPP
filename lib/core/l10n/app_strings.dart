/// Abstract base — defines every translatable string key.
abstract class AppStrings {
  // ── Common ──────────────────────────────────────────────────────────────────
  String get appName;
  String get ok;
  String get cancel;
  String get save;
  String get add;
  String get edit;
  String get delete;
  String get confirm;
  String get loading;
  String get retry;
  String get categories;
  String get items;
  String get error;
  String get success;
  String get submit;
  String get back;
  String get search;
  String get noData;
  String get refresh;

  // ── Auth ────────────────────────────────────────────────────────────────────
  String get login;
  String get logout;
  String get email;
  String get password;
  String get forgotPassword;
  String get signIn;
  String get welcomeBack;
  String get loginSubtitle;
  String get useBiometrics;
  // Login screen
  String get signInToAccount;
  String get emailAddress;
  String get forgotQ;
  String get rememberDevice;
  String get fuelComplianceSubtitle;
  String get signInWithFaceId;
  String get signInWithFingerprint;
  String get invalidCredentials;
  String get sessionExpiredPleaseSignIn;
  String get couldNotRestoreSession;
  String get biometricFailed;
  // Biometric enroll dialog
  String get enableBiometricTitle;       // 'Enable Face ID?' / 'Enable Fingerprint?'
  String get enableBiometricBody;
  String get notNow;
  String get enable;
  // Forgot password dialog
  String get resetPassword;
  String get resetPasswordSubtitle;
  String get sendLink;
  String get resetLinkSent;

  // ── Navigation ──────────────────────────────────────────────────────────────
  String get navHome;
  String get navDashboard;
  String get navTrips;
  String get navFuel;
  String get navMaintenance;
  String get navProfile;
  String get navTruck;
  String get company;
  String get support;
  // ── Dashboard ───────────────────────────────────────────────────────────────
  String get goodMorning;
  String get goodAfternoon;
  String get goodEvening;
  String get quickActions;
  String get myTrips;
  String get logFuel;
  String get profile;
  String get startInspection;
  String get history;
  String get drivers;
  String get trucks;
  String get totalDrivers;
  String get activeTrips;
  String get fuelLogs;
  String get compliance;
  // new
  String get totalMiles;
  String get totalTrips;
  String get totalSpent;
  String get recentFuelLogs;
  String get seeAll;
  String get manage;
  String get iftaFiling;
  String get untilDue;
  String get pendingReports;
  String get reportUnfiled;
  String get reportsFiled;
  String get checklistBuilder;
  String get teamAccounts;
  String get allVehicleRecords;
  String get noMaintenanceYet;
  String get noFuelLogsYet;
  String get lastThirtyDays;
  String get tripsActivity;
  String get fuelExpenses;
  String get fuelStop;
  String get thisMonth;
  String get navReports;
  String get trips;       // chart legend
  String get cost;        // chart legend "Cost ($)"
  // ── Driver Dashboard extras ──────────────────────────────────────────────────
  String get noVehicle;
  String get standby;
  String get expiring;
  String get expired;
  String get tapForDetails;
  String get miLeft;
  String get fromLabel;
  String get toLabel;
  String get noActiveRoute;
  String get tripWillAppearHere;
  String get recentTrips;
  String get noTripsYet;
  String get noFuelLogsYetDash;
  String get pctCompleted;
  String get stayOnRoad;

  // ── Drivers ─────────────────────────────────────────────────────────────────
  String get allDrivers;
  String get addDriver;
  String get driverName;
  String get licenseNumber;
  String get cdlExpiry;
  String get hireDate;
  String get phone;
  String get assignTruck;
  String get hireDriver;
  String get personalInfo;
  String get cdlInformation;
  String get truckAssignment;
  String get accountCredentials;
  String get firstName;
  String get lastName;
  String get noTruck;
  String get active;
  String get inactive;
  String get cdlStatus;
  // Drivers list screen
  String get onLeave;
  String get total;
  String get leave;
  String get searchByName;
  String get noDriversYet;
  String get noDriversMatchSearch;
  String get tapAddDriverToStart;
  // Hire driver form
  String get hireNewDriver;
  String get enterDriverDetails;
  String get cdlState;
  String get cdlNumber;
  String get cdlExpirationLabel;
  String get hireDateLabel;
  String get assignedTruck;
  String get noTruckAssignedOption;
  String get appPassword;
  String get confirmPassword;
  String get minEightChars;
  String get reEnterPassword;
  String get required;
  String get selectADate;
  String get passwordsDoNotMatch;

  // ── Inspections ─────────────────────────────────────────────────────────────
  String get inspectionHistory;
  String get inspectionChecklist;
  String get preTrip;
  String get postTrip;
  String get pass;
  String get fail;
  String get totalInspections;
  String get passed;
  String get failed;
  String get checked;
  String get today;
  String get inspectionProgress;
  String get reviewSubmit;
  String get assignedVehicle;
  String get viewHistory;
  String get editInspection;
  String get allInspections;
  String get noInspectionsYet;
  String get completeFirstInspection;
  String get failedToLoadTapRetry;
  // ── Inspection checklist extras ──────────────────────────────────────────────
  String get preTrip2;               // badge label "Pre-Trip"
  String get allClear;               // "All Clear!" / "!All Clear"
  String get issueFoundSingle;       // "1 Issue Found"
  String get issueFoundPlural;       // "{n} Issues Found"
  String get itemNeedAttentionSingle; // "1 Item Need Attention"
  String get itemNeedAttentionPlural; // "{n} Items Need Attention"
  String get reviewScheduleMaint;     // "Review failed items and schedule maintenance."
  String get complianceScore;        // "Compliance Score"
  String get vehiclePassedSafety;    // "Vehicle passed all safety checks"
  String get editThisInspection;     // "Edit This Inspection"
  String get goBack;                 // "Go Back"
  String get inProgressStatus;       // "In Progress"
  String get notStarted;             // "Not started"
  String get completedStatus;        // "✓ Completed"
  String get issue;                  // "Issue" badge on category
  String get attachPhoto;            // bottom sheet header
  String get removePhoto;            // bottom sheet option
  String get inspectionReport;       // "INSPECTION REPORT" badge
  String get reviewAndSign;          // screen heading
  String get driverSignature;        // section label
  String get signHere;               // signature canvas placeholder
  String get signatureEncrypted;     // "Signature is securely encrypted"
  String get certifyInspection;      // legal certification sentence
  String get submitInspection;       // submit button
  String get submitting;             // "Submitting…"
  String get issueDetected;          // "{n} Issue(s) Detected"
  String get dailyCompliance;        // "Daily Compliance"
  String get safetyRatingHigh;       // "🟢 High"
  String get safetyRatingMedium;     // "🟡 Medium"
  String get safetyRatingLow;        // "🔴 Low"
  String get tasks;                  // "tasks {checked} / {total}"
  String get clearSignature;         // "Clear"
  String get preTripInspection;      // "PRE-TRIP INSPECTION"
  String get issuesReported;         // "⚠️  Issues Reported"
  String get checklistItems;         // "📋  Checklist Items"

  // ── Trips ───────────────────────────────────────────────────────────────────
  String get tripDetails;
  String get origin;
  String get destination;
  String get miles;
  String get startDate;
  String get tripNumber;
  String get liveRoute;
  String get milesLeft;
  String get completed;
  String get started;
  String get eta;
  String get currentVehicle;
  String get noActiveTrip;
  // ── Driver Trips Screen ─────────────────────────────────────────────────────
  String get myTripsTitle;          // screen heading "My Trips"
  String get totalDistance;         // "TOTAL DISTANCE"
  String get searchTripsRoutes;     // search hint
  String get tripHistory;           // section header "TRIP HISTORY"
  String get totalLabel;            // stat pill "Total"
  String get doneLabel;             // stat pill "Done"
  String get activeLabel;           // stat pill "Active"
  String get resultsCount;          // "results {n}"
  String get loadingTrips;          // "Loading trips…"
  String get tryDifferentFilter;    // "Try selecting a different filter"
  String get tripHistoryHere;       // "Your trip history will appear here"
  String get inRoute;               // status badge "IN ROUTE"
  String get startTheTrip;          // button "Start the Trip"
  String get bolUploaded;           // "BOL uploaded ✓"
  String get uploadBol;             // "Upload BOL"
  String get complete;              // button "Complete"
  String get keepGoing;             // button "Keep Going"
  // Start trip dialog
  String get confirmStartOdo;       // "Confirm Start Odometer"
  String get verifyOdoBefore;       // "Verify the truck odometer…"
  String get odometerMiles;         // label "Odometer (miles)"
  String get startTrip;             // button "Start Trip"
  // Complete trip dialog
  String get completeTrip;          // "Complete Trip"
  String get startOdometerRef;      // "Start odometer: "
  String get endOdometerLabel;      // "End Odometer (miles)"
  String get actualMilesDriven;     // "Actual Miles Driven"
  String get saveAndComplete;       // "Save & Complete"
  // Cancel trip dialog
  String get cancelTripTitle;       // "Cancel Trip?"
  String get cancelTripBody;        // "This will stop the trip…"
  // BOL upload dialog
  String get uploadBolTitle;        // "Upload Bill of Lading"
  String get takePhotoOrFile;       // "Take a photo or choose a file"
  String get cameraLabel;           // "Camera"
  String get galleryLabel;          // "Gallery"
  String get fileLabel;             // "File"
  String get uploadingLabel;        // "Uploading…"

  // ── Fuel ────────────────────────────────────────────────────────────────────
  String get fuelLog;
  String get addFuelLog;
  String get gallons;
  String get pricePerGallon;
  String get state;
  String get fuelType;
  String get logs;
  String get stops;
  String get recentPurchases;
  String get searchByTruckId;
  String get receiptAttached;
  String get pendingReceipt;
  String get compliant;
  String get tapToAddFirst;
  // Fuel Detail
  String get fuelLogDetail;
  String get fuelDetails;
  String get totalCost;
  String get location;
  String get payment;
  String get station;
  String get address;
  String get jurisdiction;
  String get method;
  String get receiptNumber;
  String get odometer;
  String get receiptSection;
  String get noReceiptAttached;
  String get tapToUploadReceipt;
  String get uploadReceipt;
  String get uploading;
  String get takePhoto;
  String get chooseFromGallery;
  String get takeAPhoto;
  String get browseFilesPdfImage;
  String get receiptUploaded;
  String get uploadFailed;
  // Fuel stop form
  String get logFuelStop;
  String get saveFuelLog;
  String get tripInfo;
  String get purchaseDate;
  String get vendorStation;
  String get pricePerGal;
  String get paymentMethod;
  String get locating;
  String get tapToGetLocation;
  String get noTruckAssigned;
  String get autoCalculated;
  String get totalAmount;
  String get receiptTapToChange;
  String get tapToUploadReceiptFmt;
  String get failedSave;
  // Trips page
  String get states;
  String get filterAll;
  String get noTripsFound;
  String get adjustFilterSearch;
  String get newTrip;
  String get searchByTruckDriverState;
  String get statusActive;
  String get statusComplete;
  // Trip Detail
  String get from;
  String get to;
  String get driver;
  String get truck;
  String get carrier;
  String get dotNumber;
  String get endDate;
  String get departure;
  String get estArrival;
  String get quarter;
  String get year;
  String get odoStart;
  String get odoEnd;
  String get driven;
  String get driverAndTruck;
  String get routeAndDates;
  String get statesTraveled;
  String get fuelEntries;
  String get notes;
  String get couldNotLoadTrip;
  // IFTA Reports page
  String get iftaReports;
  String get fullyCompliant;
  String get noReports;
  String get taxDue;
  String get drafts;
  String get qtdMetrics;
  String get totalGallons;
  String get avgMpg;
  String get estTaxDue;
  String get complianceHealth;
  String get missingFuelReceipts;
  String get tripsNeedingReview;
  String get tripsMissingMileage;
  String get odometerVerified;
  String get missingReceipts;
  String get tripsForReview;
  String get milesByJurisdiction;
  String get currentQuarter;
  String get showAllStates;
  String get hide;
  String get filed;
  String get reportHistory;
  String get allQuarterlyFilings;
  String get jurisdictions;
  String get netTax;
  String get details;
  String get readyToFile;
  String get resume;
  String get noReportsYet;
  String get generateFirstReport;
  String get generateQReport;
  String get generateIftaReport;
  String get selectQuarterFromTrips;
  String get noCompletedTrips;
  String get completeTripsFirst;
  String get generating;
  String get selectQuarter;
  String get dataQualityWarning;
  String get abnormalMpgDetected;
  String get deleteReport;
  String get deleteReportConfirm;
  String get cannotDeleteFiled;
  String get deleteFailed;
  String get couldNotDeleteReport;
  String get quartersFiledOf;
  String get readyToFileLabel;
  String get draftLabel;
  String get filedLabel;
  String get couldNotLoadQuarters;
  // Report Detail screen
  String get reportDetails;
  String get quarterlyReport;
  String get avgMpgLabel;
  String get milesByJurisdictionTitle;
  String get stateCol;
  String get milesCol;
  String get gallonsCol;
  String get taxCol;
  String get refNum;
  String get viewDownloadPdf;
  String get downloadShareCsv;
  String get downloading;
  String get couldNotLoadReportDetails;
  String get failedDownloadPdf;
  String get failedDownloadCsv;
  String get sharePdf;
  String get pageOf;
  String get page;
  String get q1Months;
  String get q2Months;
  String get q3Months;
  String get q4Months;
  // Truck screen
  String get myTrucks;
  String get addTruck;
  String get fleetManagement;
  String get trucksRegistered;
  String get truckRegistered;
  String get noTrucksYet;
  String get addFirstTruck;
  String get couldNotLoadTrucks;
  String get statusMaintenance;
  String get statusInactive;
  String get statusRetired;
  // Truck edit screen
  String get editTruck;
  String get addNewTruck;
  String get updateTruckInfo;
  String get registerNewTruck;
  String get saveFailed;
  String get vehicleIdentity;
  String get unitNumber;
  String get make;
  String get model;
  String get vinLabel;
  String get registration;
  String get licensePlate;
  String get licenseState;
  String get fuelAndStatus;
  String get additionalInfo;
  String get odometerMi;
  String get notesOptional;
  String get requiredField;
  // Profile screen
  String get myProfile;
  String get fleetAdministrator;
  String get fleetManager;
  String get dispatcher;
  String get fleetMember;
  String get noContactInfo;
  String get securityPrivacy;
  String get notificationSettings;
  String get appLanguage;
  String get helpSupport;
  String get aboutDotComply;
  String get personalInformation;
  String get fullName;
  String get role;
  String get changePassword;
  String get updatePassword;
  String get currentPassword;
  String get newPassword;
  String get confirmNewPassword;
  String get updateLoginPassword;
  String get pleaseUpdateLoginPassword;
  String get fillAllFields;
  String get passwordMin8;
  String get passwordsNoMatch;
  String get passwordChanged;
  String get failedChangePassword;
  String get currentPasswordIncorrect;
  String get faceIdBiometric;
  String get signInWithoutPassword;
  String get privacyPolicy;
  String get howWeHandleData;
  String get pushNotifications;
  String get pushNotifSubtitle;
  String get emailNotifications;
  String get emailNotifSubtitle;
  String get smsNotifications;
  String get smsNotifSubtitle;
  String get chooseNotifications;
  String get emailSupport;
  String get callSupport;
  String get whatsappSupport;
  String get frequentlyAsked;
  String get weAreHereToHelp;
  String get privacyPolicyNotSet;
  String get couldNotUploadPhoto;
  String get areYouSureSignOut;
  String get photoUpdated;
  String get profileSection;
  String get licenseInfoSection;
  String get settingsSection;
  String get supportSection;
  String get cdlExpiresDays;  // e.g. "CDL expires in {n} days. Renew soon."

  // ── Maintenance ─────────────────────────────────────────────────────────────
  String get maintenance;
  String get addMaintenance;
  String get pending;
  String get inProgress;
  String get critical;
  String get priority;
  String get status;
  // List screen
  String get reportMaintenance;
  String get tapAddToReportIssue;
  String get failedToLoad;
  String get totalStat;
  String get doneStat;
  String get criticalStat;
  // Status labels
  String get statusCompleted;
  String get statusCancelled;
  // Form screen
  String get editRecord;
  String get truckAndTitleRequired;
  String get selectTruckHint;
  String get typeTruck;
  String get typeLabel;
  String get titleRequired;
  String get titleHint;
  String get priorityLow;
  String get priorityMedium;
  String get priorityHigh;
  String get typeTires;
  String get typeBrakes;
  String get typeEngine;
  String get typeTransmission;
  String get typeElectrical;
  String get typeHvac;
  String get typeSuspension;
  String get typeLights;
  String get typeWindshield;
  String get typeDotPrep;
  String get typeOther;
  String get datePerformed;
  String get selectDateHint;
  String get costDollar;
  String get vendorShop;
  String get vendorShopHint;
  String get descriptionHint;
  String get invoiceReceipt;
  String get tapAttachInvoice;
  String get pdfJpgPng;
  String get tapToChange;
  String get existingInvoiceOnFile;
  String get submitReport;
  String get updateRecord;
  String get oilChange;
  String get description;

  // ── Settings / Profile ──────────────────────────────────────────────────────
  String get settings;
  String get language;
  String get english;
  String get arabic;
  String get spanish;
  String get changeLanguage;
  String get darkMode;
  String get notifications;
  String get about;
  String get version;
  String get signOut;
  // Inspection Template screen
  String get inspectionTemplates;
  String get vehicleSafetyChecklist;
  String get addCategory;
  String get editCategory;
  String get addItem;
  String get editItem;
  String get categoryName;
  String get itemLabel;
  String get noCategoriesYet;
  String get tapAddCategoryHint;
  String get categoryAddedOk;
  String get categoryUpdatedOk;
  String get failedToAddCategory;
  String get failedToUpdateCategory;
  String get failedToDeleteCategory;
  String get itemAddedOk;
  String get itemUpdatedOk;
  String get itemRemovedOk;
  String get failedToAddItem;
  String get failedToUpdateItem;
  String get failedToDeleteItem;
  String get deleteCategoryConfirmFmt;
  String get removeItemConfirmFmt;
  // Route picker
  String get chooseYourRoute;
  String get selectRouteSubtitle;
  String get startTripWithRoute;
  String get findingBestRoutes;
  String get routeLabelFastest;
  String get routeLabelAvoidTolls;
  String get routeLabelAvoidHighways;
  String get couldNotLoadRoutes;
  String get tryAgain;
  String get miTotal;
  String get via;
  // Trip detail sheet
  String get tripDetailFrom;
  String get tripDetailTo;
  String get tripDetailDriver;
  String get tripDetailTruck;
  String get tripDetailDateRange;
  String get tripDetailTotalMiles;
  String get tripDetailDepartureTime;
  String get tripDetailDriveDuration;
  String get tripDetailEstArrival;
  String get tripDetailMilesByState;
  String get tripDetailRouteProgress;
  String get tripDetailOvernightRequired;
  String get tripDetailBreakRequired;
  String get tripDetailOvernightExceeds;
  String get tripDetailBreak30minRule;
  String get tripDetailOvernightStop;
  String get tripDetailMiDriven;
  String get tripDetailMiLeft;
  String get tripDetailMinBreakDay;
  String get tripDetailAfter8hBy;
  String get tripDetailStopBy;
  String get tripDetailHourRest;
  String get tripDetailResume;
  String get tripDetailRemaining;
}
