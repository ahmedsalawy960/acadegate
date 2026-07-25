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
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AcadeGate'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your gateway to graduate studies excellence'**
  String get appTagline;

  /// No description provided for @chooseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get chooseLanguage;

  /// No description provided for @chooseLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select Arabic or English before continuing. You can change it later from the welcome screen.'**
  String get chooseLanguageSubtitle;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @googleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleSignIn;

  /// No description provided for @browseGuest.
  ///
  /// In en, this message translates to:
  /// **'Browse as guest'**
  String get browseGuest;

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

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginTitle;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @chooseYourRole.
  ///
  /// In en, this message translates to:
  /// **'Choose your role on the platform'**
  String get chooseYourRole;

  /// No description provided for @registerRoleHint.
  ///
  /// In en, this message translates to:
  /// **'Your role determines what you can add: products, lab, supervisor profile, or research ideas.'**
  String get registerRoleHint;

  /// No description provided for @authErrorUnexpected.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again later.'**
  String get authErrorUnexpected;

  /// No description provided for @authErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authErrorInvalidCredentials;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrorUserDisabled;

  /// No description provided for @authErrorRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create account.'**
  String get authErrorRegisterFailed;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak.'**
  String get authErrorWeakPassword;

  /// No description provided for @portalChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your portal'**
  String get portalChooseTitle;

  /// No description provided for @portalChooseSubtitleLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Pick how you want to use AcadeGate today — you can switch later.'**
  String get portalChooseSubtitleLoggedIn;

  /// No description provided for @portalChooseSubtitleGuest.
  ///
  /// In en, this message translates to:
  /// **'Browsing as guest — sign in later to save your choice.'**
  String get portalChooseSubtitleGuest;

  /// No description provided for @portalUser.
  ///
  /// In en, this message translates to:
  /// **'User portal'**
  String get portalUser;

  /// No description provided for @portalProvider.
  ///
  /// In en, this message translates to:
  /// **'Service provider portal'**
  String get portalProvider;

  /// No description provided for @portalUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For researchers, students, and service consumers'**
  String get portalUserSubtitle;

  /// No description provided for @portalProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For merchants, labs, writers, and content publishers'**
  String get portalProviderSubtitle;

  /// No description provided for @portalUserItem1.
  ///
  /// In en, this message translates to:
  /// **'Find supervisors and labs'**
  String get portalUserItem1;

  /// No description provided for @portalUserItem2.
  ///
  /// In en, this message translates to:
  /// **'Academic store purchases'**
  String get portalUserItem2;

  /// No description provided for @portalUserItem3.
  ///
  /// In en, this message translates to:
  /// **'Research ideas and academic community'**
  String get portalUserItem3;

  /// No description provided for @portalUserItem4.
  ///
  /// In en, this message translates to:
  /// **'AI advisor and smart matchmaking'**
  String get portalUserItem4;

  /// No description provided for @portalProviderItem1.
  ///
  /// In en, this message translates to:
  /// **'Academic merchant / supplier'**
  String get portalProviderItem1;

  /// No description provided for @portalProviderItem2.
  ///
  /// In en, this message translates to:
  /// **'Lab and sample analysis'**
  String get portalProviderItem2;

  /// No description provided for @portalProviderItem3.
  ///
  /// In en, this message translates to:
  /// **'Academic writer and expert'**
  String get portalProviderItem3;

  /// No description provided for @portalProviderItem4.
  ///
  /// In en, this message translates to:
  /// **'Idea publisher and service supervisor'**
  String get portalProviderItem4;

  /// No description provided for @portalSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested for your role'**
  String get portalSuggested;

  /// No description provided for @switchToUserPortal.
  ///
  /// In en, this message translates to:
  /// **'Switch to user portal'**
  String get switchToUserPortal;

  /// No description provided for @switchToProviderPortal.
  ///
  /// In en, this message translates to:
  /// **'Switch to provider portal'**
  String get switchToProviderPortal;

  /// No description provided for @roleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student / Researcher'**
  String get roleStudent;

  /// No description provided for @roleSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Academic supervisor'**
  String get roleSupervisor;

  /// No description provided for @roleMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant / Supplier'**
  String get roleMerchant;

  /// No description provided for @roleLabManager.
  ///
  /// In en, this message translates to:
  /// **'Lab manager'**
  String get roleLabManager;

  /// No description provided for @roleIdeaPublisher.
  ///
  /// In en, this message translates to:
  /// **'Research idea publisher'**
  String get roleIdeaPublisher;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'System admin'**
  String get roleAdmin;

  /// No description provided for @roleUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get roleUser;

  /// No description provided for @providerPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'Service provider portal'**
  String get providerPortalTitle;

  /// No description provided for @userHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'AcadeGate'**
  String get userHomeTitle;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search services, supervisors, labs, products...'**
  String get homeSearchHint;

  /// No description provided for @serviceSupervisors.
  ///
  /// In en, this message translates to:
  /// **'Supervisors'**
  String get serviceSupervisors;

  /// No description provided for @serviceIdeas.
  ///
  /// In en, this message translates to:
  /// **'Research ideas'**
  String get serviceIdeas;

  /// No description provided for @serviceResearchPath.
  ///
  /// In en, this message translates to:
  /// **'Smart research path'**
  String get serviceResearchPath;

  /// No description provided for @serviceLabs.
  ///
  /// In en, this message translates to:
  /// **'Labs & analysis centers'**
  String get serviceLabs;

  /// No description provided for @serviceStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get serviceStore;

  /// No description provided for @serviceCommunity.
  ///
  /// In en, this message translates to:
  /// **'Academic community'**
  String get serviceCommunity;

  /// No description provided for @serviceAiAdvisor.
  ///
  /// In en, this message translates to:
  /// **'AI academic advisor'**
  String get serviceAiAdvisor;

  /// No description provided for @serviceIntegrity.
  ///
  /// In en, this message translates to:
  /// **'AcadeGate Integrity'**
  String get serviceIntegrity;

  /// No description provided for @serviceWriting.
  ///
  /// In en, this message translates to:
  /// **'Writing services'**
  String get serviceWriting;

  /// No description provided for @servicePublish.
  ///
  /// In en, this message translates to:
  /// **'AcadeGate Publish'**
  String get servicePublish;

  /// No description provided for @serviceFund.
  ///
  /// In en, this message translates to:
  /// **'Research Fund'**
  String get serviceFund;

  /// No description provided for @serviceNews.
  ///
  /// In en, this message translates to:
  /// **'Science news'**
  String get serviceNews;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @academicProfile.
  ///
  /// In en, this message translates to:
  /// **'Academic profile'**
  String get academicProfile;

  /// No description provided for @smartMatchmaking.
  ///
  /// In en, this message translates to:
  /// **'Smart matchmaking'**
  String get smartMatchmaking;

  /// No description provided for @contentReview.
  ///
  /// In en, this message translates to:
  /// **'Content review'**
  String get contentReview;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Do you want to sign out of your account?'**
  String get logoutConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @guestBrowsing.
  ///
  /// In en, this message translates to:
  /// **'You are browsing as a guest'**
  String get guestBrowsing;

  /// No description provided for @guestProviderHint.
  ///
  /// In en, this message translates to:
  /// **'Sign in or create a provider account to access the contributor dashboard.'**
  String get guestProviderHint;

  /// No description provided for @sectionIncomingOrders.
  ///
  /// In en, this message translates to:
  /// **'Incoming orders'**
  String get sectionIncomingOrders;

  /// No description provided for @sectionPublishContent.
  ///
  /// In en, this message translates to:
  /// **'Publish your content'**
  String get sectionPublishContent;

  /// No description provided for @sectionTrackOrders.
  ///
  /// In en, this message translates to:
  /// **'Track your requests'**
  String get sectionTrackOrders;

  /// No description provided for @sectionSystemAdmin.
  ///
  /// In en, this message translates to:
  /// **'System administration'**
  String get sectionSystemAdmin;

  /// No description provided for @writingOrdersIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming writing orders'**
  String get writingOrdersIncoming;

  /// No description provided for @writingOrdersIncomingSub.
  ///
  /// In en, this message translates to:
  /// **'Accept, reject, and deliver client requests'**
  String get writingOrdersIncomingSub;

  /// No description provided for @sampleAnalysisIncoming.
  ///
  /// In en, this message translates to:
  /// **'Sample analysis requests'**
  String get sampleAnalysisIncoming;

  /// No description provided for @sampleAnalysisIncomingSub.
  ///
  /// In en, this message translates to:
  /// **'Samples sent by researchers to your lab'**
  String get sampleAnalysisIncomingSub;

  /// No description provided for @supervisionIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming supervision requests'**
  String get supervisionIncoming;

  /// No description provided for @supervisionIncomingSub.
  ///
  /// In en, this message translates to:
  /// **'Messages and requests from students'**
  String get supervisionIncomingSub;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add store product'**
  String get addProduct;

  /// No description provided for @addProductSub.
  ///
  /// In en, this message translates to:
  /// **'Choose a category then add your product'**
  String get addProductSub;

  /// No description provided for @registerLab.
  ///
  /// In en, this message translates to:
  /// **'Register a lab'**
  String get registerLab;

  /// No description provided for @registerLabSub.
  ///
  /// In en, this message translates to:
  /// **'Add your lab and equipment for review'**
  String get registerLabSub;

  /// No description provided for @registerSupervisor.
  ///
  /// In en, this message translates to:
  /// **'Register supervisor profile'**
  String get registerSupervisor;

  /// No description provided for @registerSupervisorSub.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review before publishing'**
  String get registerSupervisorSub;

  /// No description provided for @publishIdea.
  ///
  /// In en, this message translates to:
  /// **'Publish research idea'**
  String get publishIdea;

  /// No description provided for @publishIdeaSub.
  ///
  /// In en, this message translates to:
  /// **'Reviewed before appearing in the marketplace'**
  String get publishIdeaSub;

  /// No description provided for @mySupervisionRequests.
  ///
  /// In en, this message translates to:
  /// **'My supervision requests'**
  String get mySupervisionRequests;

  /// No description provided for @mySupervisionRequestsSub.
  ///
  /// In en, this message translates to:
  /// **'Track what you sent'**
  String get mySupervisionRequestsSub;

  /// No description provided for @mySampleRequests.
  ///
  /// In en, this message translates to:
  /// **'My lab sample requests'**
  String get mySampleRequests;

  /// No description provided for @mySampleRequestsSub.
  ///
  /// In en, this message translates to:
  /// **'Track samples you submitted'**
  String get mySampleRequestsSub;

  /// No description provided for @contentModeration.
  ///
  /// In en, this message translates to:
  /// **'Content review'**
  String get contentModeration;

  /// No description provided for @contentModerationSub.
  ///
  /// In en, this message translates to:
  /// **'Approve or reject supervisors, labs, and products'**
  String get contentModerationSub;

  /// No description provided for @contributorHub.
  ///
  /// In en, this message translates to:
  /// **'Full contributor dashboard'**
  String get contributorHub;

  /// No description provided for @sellProducts.
  ///
  /// In en, this message translates to:
  /// **'Sell academic products'**
  String get sellProducts;

  /// No description provided for @sellProductsSub.
  ///
  /// In en, this message translates to:
  /// **'Merchant / supplier'**
  String get sellProductsSub;

  /// No description provided for @manageLab.
  ///
  /// In en, this message translates to:
  /// **'Manage lab & sample analysis'**
  String get manageLab;

  /// No description provided for @manageLabSub.
  ///
  /// In en, this message translates to:
  /// **'Lab manager'**
  String get manageLabSub;

  /// No description provided for @offerWriting.
  ///
  /// In en, this message translates to:
  /// **'Offer academic writing services'**
  String get offerWriting;

  /// No description provided for @offerWritingSub.
  ///
  /// In en, this message translates to:
  /// **'Writer / expert'**
  String get offerWritingSub;

  /// No description provided for @publishIdeasGuest.
  ///
  /// In en, this message translates to:
  /// **'Publish research ideas'**
  String get publishIdeasGuest;

  /// No description provided for @publishIdeasGuestSub.
  ///
  /// In en, this message translates to:
  /// **'Idea publisher'**
  String get publishIdeasGuestSub;

  /// No description provided for @afterRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'What you can do after signing in'**
  String get afterRegisterTitle;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in from the home screen to continue'**
  String get signInToContinue;

  /// No description provided for @facultyEngineering.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Engineering'**
  String get facultyEngineering;

  /// No description provided for @facultyScience.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Science'**
  String get facultyScience;

  /// No description provided for @facultyMedicine.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Medicine'**
  String get facultyMedicine;

  /// No description provided for @facultyDentistry.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Dentistry'**
  String get facultyDentistry;

  /// No description provided for @facultyPharmacy.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Pharmacy'**
  String get facultyPharmacy;

  /// No description provided for @facultyNursing.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Nursing'**
  String get facultyNursing;

  /// No description provided for @facultyVeterinary.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Veterinary Medicine'**
  String get facultyVeterinary;

  /// No description provided for @facultyLaw.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Law'**
  String get facultyLaw;

  /// No description provided for @facultyCS.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Computer Science'**
  String get facultyCS;

  /// No description provided for @facultyAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Agriculture'**
  String get facultyAgriculture;

  /// No description provided for @facultyBusiness.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Commerce'**
  String get facultyBusiness;

  /// No description provided for @facultyEducation.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Education'**
  String get facultyEducation;

  /// No description provided for @facultyArts.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Arts'**
  String get facultyArts;

  /// No description provided for @facultyArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Architecture'**
  String get facultyArchitecture;

  /// No description provided for @facultyMassCommunication.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Media'**
  String get facultyMassCommunication;

  /// No description provided for @facultyTourism.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Tourism & Hotels'**
  String get facultyTourism;

  /// No description provided for @facultyPhysicalEducation.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Physical Education'**
  String get facultyPhysicalEducation;

  /// No description provided for @facultyFineArts.
  ///
  /// In en, this message translates to:
  /// **'Faculty of Fine Arts'**
  String get facultyFineArts;

  /// No description provided for @storeChemical.
  ///
  /// In en, this message translates to:
  /// **'Chemical store'**
  String get storeChemical;

  /// No description provided for @storeEngineering.
  ///
  /// In en, this message translates to:
  /// **'Engineering store'**
  String get storeEngineering;

  /// No description provided for @storeMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical store'**
  String get storeMedical;

  /// No description provided for @storeAgricultural.
  ///
  /// In en, this message translates to:
  /// **'Agricultural store'**
  String get storeAgricultural;

  /// No description provided for @storeGeneral.
  ///
  /// In en, this message translates to:
  /// **'General store'**
  String get storeGeneral;

  /// No description provided for @writingResearchPapers.
  ///
  /// In en, this message translates to:
  /// **'Research papers'**
  String get writingResearchPapers;

  /// No description provided for @writingThesis.
  ///
  /// In en, this message translates to:
  /// **'Theses'**
  String get writingThesis;

  /// No description provided for @writingStatistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics & analysis'**
  String get writingStatistics;

  /// No description provided for @writingLiteratureReview.
  ///
  /// In en, this message translates to:
  /// **'Literature review'**
  String get writingLiteratureReview;

  /// No description provided for @writingProposal.
  ///
  /// In en, this message translates to:
  /// **'Research proposals'**
  String get writingProposal;

  /// No description provided for @writingEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing & proofreading'**
  String get writingEditing;

  /// No description provided for @writingFormatting.
  ///
  /// In en, this message translates to:
  /// **'Formatting & citations'**
  String get writingFormatting;

  /// No description provided for @writingTranslation.
  ///
  /// In en, this message translates to:
  /// **'Academic translation'**
  String get writingTranslation;

  /// No description provided for @portalProviderDesc.
  ///
  /// In en, this message translates to:
  /// **'Merchant, lab, academic writer, idea publisher, or supervisor offering services'**
  String get portalProviderDesc;

  /// No description provided for @portalUserDesc.
  ///
  /// In en, this message translates to:
  /// **'Student, researcher, supervisor seeking services, or content consumer'**
  String get portalUserDesc;

  /// No description provided for @loginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to AcadeGate'**
  String get loginWelcome;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to continue'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'University / email address'**
  String get emailLabel;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordMinLength;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @orDivider.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// No description provided for @googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get googleLogin;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @emailRequiredShort.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequiredShort;

  /// No description provided for @createAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountButton;

  /// No description provided for @portalProviderSubtitleAlt.
  ///
  /// In en, this message translates to:
  /// **'For those offering services on the platform'**
  String get portalProviderSubtitleAlt;

  /// No description provided for @portalSuggestedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Based on your account role, we suggest:'**
  String get portalSuggestedPrefix;

  /// No description provided for @portalSuggestedBadge.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get portalSuggestedBadge;

  /// No description provided for @portalEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get portalEnter;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled by administration.'**
  String get authErrorAccountDisabled;

  /// No description provided for @userPortalHomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Researcher & student portal'**
  String get userPortalHomeTitle;

  /// No description provided for @switchPortalTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch portal'**
  String get switchPortalTitle;

  /// No description provided for @switchPortalMessage.
  ///
  /// In en, this message translates to:
  /// **'Return to portal selection?\nYou can switch between provider and user portals anytime.'**
  String get switchPortalMessage;

  /// No description provided for @switchPortalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get switchPortalConfirm;
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
    'that was used.',
  );
}
