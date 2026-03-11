import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Site Tracker'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @systemOwner.
  ///
  /// In en, this message translates to:
  /// **'System Owner'**
  String get systemOwner;

  /// No description provided for @siteManager.
  ///
  /// In en, this message translates to:
  /// **'Site Manager'**
  String get siteManager;

  /// No description provided for @resident.
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get resident;

  /// No description provided for @siteResident.
  ///
  /// In en, this message translates to:
  /// **'Site Resident'**
  String get siteResident;

  /// No description provided for @residents.
  ///
  /// In en, this message translates to:
  /// **'Residents'**
  String get residents;

  /// No description provided for @addSite.
  ///
  /// In en, this message translates to:
  /// **'Add Site'**
  String get addSite;

  /// No description provided for @sites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get sites;

  /// No description provided for @mySites.
  ///
  /// In en, this message translates to:
  /// **'My Sites'**
  String get mySites;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @dues.
  ///
  /// In en, this message translates to:
  /// **'Dues'**
  String get dues;

  /// No description provided for @requests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requests;

  /// No description provided for @createRequest.
  ///
  /// In en, this message translates to:
  /// **'Create Request'**
  String get createRequest;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials.'**
  String get loginFailed;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New Request'**
  String get newRequest;

  /// No description provided for @requestDescription.
  ///
  /// In en, this message translates to:
  /// **'You can submit your problems or requests here.'**
  String get requestDescription;

  /// No description provided for @requestTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Request Title'**
  String get requestTitleLabel;

  /// No description provided for @requestTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Faucet repair'**
  String get requestTitleHint;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Please describe the problem in detail...'**
  String get descriptionHint;

  /// No description provided for @sendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sendRequest;

  /// No description provided for @newAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'New Announcement'**
  String get newAnnouncement;

  /// No description provided for @announcementPrompt.
  ///
  /// In en, this message translates to:
  /// **'You can write the message you want to reach the site residents here.'**
  String get announcementPrompt;

  /// No description provided for @titleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleLabel;

  /// No description provided for @announcementContentLabel.
  ///
  /// In en, this message translates to:
  /// **'Announcement Text'**
  String get announcementContentLabel;

  /// No description provided for @shareNow.
  ///
  /// In en, this message translates to:
  /// **'Share Now'**
  String get shareNow;

  /// No description provided for @siteNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Site Name'**
  String get siteNameLabel;

  /// No description provided for @siteNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Serenity Sites'**
  String get siteNameHint;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressLabel;

  /// No description provided for @addressHint.
  ///
  /// In en, this message translates to:
  /// **'Full address of the site...'**
  String get addressHint;

  /// No description provided for @saveSite.
  ///
  /// In en, this message translates to:
  /// **'Save Site'**
  String get saveSite;

  /// No description provided for @editSite.
  ///
  /// In en, this message translates to:
  /// **'Edit Site'**
  String get editSite;

  /// No description provided for @siteInfo.
  ///
  /// In en, this message translates to:
  /// **'Site Information'**
  String get siteInfo;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noSitesYet.
  ///
  /// In en, this message translates to:
  /// **'No sites added yet.'**
  String get noSitesYet;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'No announcements found.'**
  String get noAnnouncements;

  /// No description provided for @newBadge.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newBadge;

  /// No description provided for @myDues.
  ///
  /// In en, this message translates to:
  /// **'My Dues'**
  String get myDues;

  /// No description provided for @noDuesFound.
  ///
  /// In en, this message translates to:
  /// **'No dues found.'**
  String get noDuesFound;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get paid;

  /// No description provided for @debt.
  ///
  /// In en, this message translates to:
  /// **'DEBT'**
  String get debt;

  /// No description provided for @residentManagement.
  ///
  /// In en, this message translates to:
  /// **'Resident Management'**
  String get residentManagement;

  /// No description provided for @noResidentsFound.
  ///
  /// In en, this message translates to:
  /// **'No residents found.'**
  String get noResidentsFound;

  /// No description provided for @anonymousResident.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Resident'**
  String get anonymousResident;

  /// No description provided for @apartmentNoInfo.
  ///
  /// In en, this message translates to:
  /// **'Apartment: No Info'**
  String get apartmentNoInfo;

  /// No description provided for @incomingRequests.
  ///
  /// In en, this message translates to:
  /// **'Incoming Requests'**
  String get incomingRequests;

  /// No description provided for @noActiveRequestsFound.
  ///
  /// In en, this message translates to:
  /// **'No active requests found.'**
  String get noActiveRequestsFound;

  /// No description provided for @sender.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get sender;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @changeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change Status'**
  String get changeStatus;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @duesManagement.
  ///
  /// In en, this message translates to:
  /// **'Dues Management'**
  String get duesManagement;

  /// No description provided for @apartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get apartment;

  /// No description provided for @monthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get monthLabel;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// No description provided for @recentActivities.
  ///
  /// In en, this message translates to:
  /// **'Recent Activities'**
  String get recentActivities;

  /// No description provided for @noRecentActivities.
  ///
  /// In en, this message translates to:
  /// **'No recent activities in the system.'**
  String get noRecentActivities;

  /// No description provided for @unknownSite.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Site'**
  String get unknownSite;

  /// No description provided for @noAddressProvided.
  ///
  /// In en, this message translates to:
  /// **'No address provided'**
  String get noAddressProvided;

  /// No description provided for @siteStatus.
  ///
  /// In en, this message translates to:
  /// **'Site Status'**
  String get siteStatus;

  /// No description provided for @pendingTasks.
  ///
  /// In en, this message translates to:
  /// **'Pending Tasks'**
  String get pendingTasks;

  /// No description provided for @newMaintenanceRequests.
  ///
  /// In en, this message translates to:
  /// **'3 New maintenance requests waiting for review.'**
  String get newMaintenanceRequests;

  /// No description provided for @summaryInfo.
  ///
  /// In en, this message translates to:
  /// **'Summary Info'**
  String get summaryInfo;

  /// No description provided for @activeRequests.
  ///
  /// In en, this message translates to:
  /// **'Active Requests'**
  String get activeRequests;

  /// No description provided for @unpaidDues.
  ///
  /// In en, this message translates to:
  /// **'Unpaid Dues'**
  String get unpaidDues;

  /// No description provided for @quickAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'Quick Announcements'**
  String get quickAnnouncements;

  /// No description provided for @noRecentAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'No recent announcements posted.'**
  String get noRecentAnnouncements;

  /// No description provided for @siteManagerRole.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get siteManagerRole;

  /// No description provided for @residentRole.
  ///
  /// In en, this message translates to:
  /// **'Resident'**
  String get residentRole;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add User'**
  String get addUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit User'**
  String get editUser;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @selectManager.
  ///
  /// In en, this message translates to:
  /// **'Select Manager'**
  String get selectManager;

  /// No description provided for @noManager.
  ///
  /// In en, this message translates to:
  /// **'No Manager Assigned'**
  String get noManager;

  /// No description provided for @userCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User created successfully.'**
  String get userCreatedSuccessfully;

  /// No description provided for @userUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User updated successfully.'**
  String get userUpdatedSuccessfully;

  /// No description provided for @assignManager.
  ///
  /// In en, this message translates to:
  /// **'Assign Manager'**
  String get assignManager;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get noUsersFound;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteUserPrompt.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this user? This action cannot be undone.'**
  String get deleteUserPrompt;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @noAssignedSite.
  ///
  /// In en, this message translates to:
  /// **'No site has been assigned to you yet. Please contact the system administrator.'**
  String get noAssignedSite;

  /// No description provided for @delayedDues.
  ///
  /// In en, this message translates to:
  /// **'Delayed Dues'**
  String get delayedDues;

  /// No description provided for @managementTools.
  ///
  /// In en, this message translates to:
  /// **'Management Tools'**
  String get managementTools;

  /// No description provided for @siteYapisi.
  ///
  /// In en, this message translates to:
  /// **'Site Structure'**
  String get siteYapisi;

  /// No description provided for @siteStructureDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage blocks and apartments'**
  String get siteStructureDesc;

  /// No description provided for @residentList.
  ///
  /// In en, this message translates to:
  /// **'Resident List'**
  String get residentList;

  /// No description provided for @allResidents.
  ///
  /// In en, this message translates to:
  /// **'All Residents'**
  String get allResidents;

  /// No description provided for @incomeExpense.
  ///
  /// In en, this message translates to:
  /// **'Income/Expense'**
  String get incomeExpense;

  /// No description provided for @incomeExpenseDesc.
  ///
  /// In en, this message translates to:
  /// **'Site financial records'**
  String get incomeExpenseDesc;

  /// No description provided for @surveys.
  ///
  /// In en, this message translates to:
  /// **'Surveys'**
  String get surveys;

  /// No description provided for @surveyAndVotingDesc.
  ///
  /// In en, this message translates to:
  /// **'Create and manage surveys'**
  String get surveyAndVotingDesc;

  /// No description provided for @seeSiteFinanceDesc.
  ///
  /// In en, this message translates to:
  /// **'View site financial status'**
  String get seeSiteFinanceDesc;

  /// No description provided for @participateSurveyDesc.
  ///
  /// In en, this message translates to:
  /// **'Vote in active surveys'**
  String get participateSurveyDesc;

  /// No description provided for @errorLabel.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get errorLabel;

  /// No description provided for @cannotDeleteSelf.
  ///
  /// In en, this message translates to:
  /// **'You cannot delete yourself'**
  String get cannotDeleteSelf;

  /// No description provided for @createApartments.
  ///
  /// In en, this message translates to:
  /// **'Create Apartments'**
  String get createApartments;

  /// No description provided for @addBlock.
  ///
  /// In en, this message translates to:
  /// **'Add Block'**
  String get addBlock;

  /// No description provided for @blockNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Block Name'**
  String get blockNameLabel;

  /// No description provided for @apartmentCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Apartment Count'**
  String get apartmentCountLabel;

  /// No description provided for @binaYapisi.
  ///
  /// In en, this message translates to:
  /// **'Building Structure'**
  String get binaYapisi;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured yet'**
  String get notConfigured;

  /// No description provided for @apartmentList.
  ///
  /// In en, this message translates to:
  /// **'Apartment List'**
  String get apartmentList;

  /// No description provided for @apartmentsSuffix.
  ///
  /// In en, this message translates to:
  /// **'Apartments'**
  String get apartmentsSuffix;

  /// No description provided for @noApartmentsFound.
  ///
  /// In en, this message translates to:
  /// **'No apartments found'**
  String get noApartmentsFound;

  /// No description provided for @emptyApartment.
  ///
  /// In en, this message translates to:
  /// **'Empty Apartment'**
  String get emptyApartment;

  /// No description provided for @assignResident.
  ///
  /// In en, this message translates to:
  /// **'Assign Resident'**
  String get assignResident;

  /// No description provided for @searchResidentLabel.
  ///
  /// In en, this message translates to:
  /// **'Search Resident'**
  String get searchResidentLabel;

  /// No description provided for @noResultsFoundRedirect.
  ///
  /// In en, this message translates to:
  /// **'No results found. Go to Resident Management?'**
  String get noResultsFoundRedirect;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @addNewRecord.
  ///
  /// In en, this message translates to:
  /// **'Add New Record'**
  String get addNewRecord;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amountLabel;

  /// No description provided for @optionalHint.
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get optionalHint;

  /// No description provided for @createNewSurvey.
  ///
  /// In en, this message translates to:
  /// **'Create New Survey'**
  String get createNewSurvey;

  /// No description provided for @surveyTitle.
  ///
  /// In en, this message translates to:
  /// **'Survey Title'**
  String get surveyTitle;

  /// No description provided for @optionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get optionsLabel;

  /// No description provided for @addOption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addOption;

  /// No description provided for @publishSurvey.
  ///
  /// In en, this message translates to:
  /// **'Publish Survey'**
  String get publishSurvey;

  /// No description provided for @noSurveysFound.
  ///
  /// In en, this message translates to:
  /// **'No surveys found'**
  String get noSurveysFound;

  /// No description provided for @pastSurveys.
  ///
  /// In en, this message translates to:
  /// **'Past Surveys'**
  String get pastSurveys;

  /// No description provided for @closeSurvey.
  ///
  /// In en, this message translates to:
  /// **'Close Survey'**
  String get closeSurvey;

  /// No description provided for @activeSurveys.
  ///
  /// In en, this message translates to:
  /// **'Active Surveys'**
  String get activeSurveys;

  /// No description provided for @pleaseEnterSiteName.
  ///
  /// In en, this message translates to:
  /// **'Please enter site name'**
  String get pleaseEnterSiteName;

  /// No description provided for @sessionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Session not found'**
  String get sessionNotFound;

  /// No description provided for @maxSiteLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum site limit reached'**
  String get maxSiteLimitReached;

  /// No description provided for @siteSavedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Site saved successfully'**
  String get siteSavedSuccessfully;

  /// No description provided for @siteTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Site Type'**
  String get siteTypeLabel;

  /// No description provided for @siteOption.
  ///
  /// In en, this message translates to:
  /// **'Site (Multi-block)'**
  String get siteOption;

  /// No description provided for @apartmentOption.
  ///
  /// In en, this message translates to:
  /// **'Apartment (Single block)'**
  String get apartmentOption;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
