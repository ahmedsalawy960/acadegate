// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AcadeGate';

  @override
  String get appTagline => 'Your gateway to graduate studies excellence';

  @override
  String get chooseLanguage => 'Choose your language';

  @override
  String get chooseLanguageSubtitle =>
      'Select Arabic or English before continuing. You can change it later from the welcome screen.';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get continueButton => 'Continue';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get login => 'Sign in';

  @override
  String get register => 'Create account';

  @override
  String get googleSignIn => 'Continue with Google';

  @override
  String get browseGuest => 'Browse as guest';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full name';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get registerTitle => 'Create account';

  @override
  String get chooseYourRole => 'Choose your role on the platform';

  @override
  String get registerRoleHint =>
      'Your role determines what you can add: products, lab, supervisor profile, or research ideas.';

  @override
  String get authErrorUnexpected =>
      'An unexpected error occurred. Please try again later.';

  @override
  String get authErrorInvalidCredentials => 'Invalid email or password.';

  @override
  String get authErrorInvalidEmail => 'Invalid email format.';

  @override
  String get authErrorUserDisabled => 'This account has been disabled.';

  @override
  String get authErrorRegisterFailed => 'Could not create account.';

  @override
  String get authErrorEmailInUse => 'This email is already in use.';

  @override
  String get authErrorWeakPassword => 'Password is too weak.';

  @override
  String get portalChooseTitle => 'Choose your portal';

  @override
  String get portalChooseSubtitleLoggedIn =>
      'Pick how you want to use AcadeGate today — you can switch later.';

  @override
  String get portalChooseSubtitleGuest =>
      'Browsing as guest — sign in later to save your choice.';

  @override
  String get portalUser => 'User portal';

  @override
  String get portalProvider => 'Service provider portal';

  @override
  String get portalUserSubtitle =>
      'For researchers, students, and service consumers';

  @override
  String get portalProviderSubtitle =>
      'For merchants, labs, writers, and content publishers';

  @override
  String get portalUserItem1 => 'Find supervisors and labs';

  @override
  String get portalUserItem2 => 'Academic store purchases';

  @override
  String get portalUserItem3 => 'Research ideas and academic community';

  @override
  String get portalUserItem4 => 'AI advisor and smart matchmaking';

  @override
  String get portalProviderItem1 => 'Academic merchant / supplier';

  @override
  String get portalProviderItem2 => 'Lab and sample analysis';

  @override
  String get portalProviderItem3 => 'Academic writer and expert';

  @override
  String get portalProviderItem4 => 'Idea publisher and service supervisor';

  @override
  String get portalSuggested => 'Suggested for your role';

  @override
  String get switchToUserPortal => 'Switch to user portal';

  @override
  String get switchToProviderPortal => 'Switch to provider portal';

  @override
  String get roleStudent => 'Student / Researcher';

  @override
  String get roleSupervisor => 'Academic supervisor';

  @override
  String get roleMerchant => 'Merchant / Supplier';

  @override
  String get roleLabManager => 'Lab manager';

  @override
  String get roleIdeaPublisher => 'Research idea publisher';

  @override
  String get roleAdmin => 'System admin';

  @override
  String get roleUser => 'User';

  @override
  String get providerPortalTitle => 'Service provider portal';

  @override
  String get userHomeTitle => 'AcadeGate';

  @override
  String get homeSearchHint =>
      'Search services, supervisors, labs, products...';

  @override
  String get serviceSupervisors => 'Supervisors';

  @override
  String get serviceIdeas => 'Research ideas';

  @override
  String get serviceResearchPath => 'Smart research path';

  @override
  String get serviceLabs => 'Labs & analysis centers';

  @override
  String get serviceStore => 'Store';

  @override
  String get serviceCommunity => 'Academic community';

  @override
  String get serviceAiAdvisor => 'AI academic advisor';

  @override
  String get serviceIntegrity => 'AcadeGate Integrity';

  @override
  String get serviceWriting => 'Writing services';

  @override
  String get servicePublish => 'AcadeGate Publish';

  @override
  String get serviceFund => 'Research Fund';

  @override
  String get serviceNews => 'Science news';

  @override
  String get notifications => 'Notifications';

  @override
  String get messages => 'Messages';

  @override
  String get academicProfile => 'Academic profile';

  @override
  String get smartMatchmaking => 'Smart matchmaking';

  @override
  String get contentReview => 'Content review';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirmTitle => 'Sign out';

  @override
  String get logoutConfirmMessage => 'Do you want to sign out of your account?';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get loading => 'Loading...';

  @override
  String get guestBrowsing => 'You are browsing as a guest';

  @override
  String get guestProviderHint =>
      'Sign in or create a provider account to access the contributor dashboard.';

  @override
  String get sectionIncomingOrders => 'Incoming orders';

  @override
  String get sectionPublishContent => 'Publish your content';

  @override
  String get sectionTrackOrders => 'Track your requests';

  @override
  String get sectionSystemAdmin => 'System administration';

  @override
  String get writingOrdersIncoming => 'Incoming writing orders';

  @override
  String get writingOrdersIncomingSub =>
      'Accept, reject, and deliver client requests';

  @override
  String get sampleAnalysisIncoming => 'Sample analysis requests';

  @override
  String get sampleAnalysisIncomingSub =>
      'Samples sent by researchers to your lab';

  @override
  String get supervisionIncoming => 'Incoming supervision requests';

  @override
  String get supervisionIncomingSub => 'Messages and requests from students';

  @override
  String get addProduct => 'Add store product';

  @override
  String get addProductSub => 'Choose a category then add your product';

  @override
  String get registerLab => 'Register a lab';

  @override
  String get registerLabSub => 'Add your lab and equipment for review';

  @override
  String get registerSupervisor => 'Register supervisor profile';

  @override
  String get registerSupervisorSub => 'Submitted for review before publishing';

  @override
  String get publishIdea => 'Publish research idea';

  @override
  String get publishIdeaSub => 'Reviewed before appearing in the marketplace';

  @override
  String get mySupervisionRequests => 'My supervision requests';

  @override
  String get mySupervisionRequestsSub => 'Track what you sent';

  @override
  String get mySampleRequests => 'My lab sample requests';

  @override
  String get mySampleRequestsSub => 'Track samples you submitted';

  @override
  String get contentModeration => 'Content review';

  @override
  String get contentModerationSub =>
      'Approve or reject supervisors, labs, and products';

  @override
  String get contributorHub => 'Full contributor dashboard';

  @override
  String get sellProducts => 'Sell academic products';

  @override
  String get sellProductsSub => 'Merchant / supplier';

  @override
  String get manageLab => 'Manage lab & sample analysis';

  @override
  String get manageLabSub => 'Lab manager';

  @override
  String get offerWriting => 'Offer academic writing services';

  @override
  String get offerWritingSub => 'Writer / expert';

  @override
  String get publishIdeasGuest => 'Publish research ideas';

  @override
  String get publishIdeasGuestSub => 'Idea publisher';

  @override
  String get afterRegisterTitle => 'What you can do after signing in';

  @override
  String get signInToContinue => 'Sign in from the home screen to continue';

  @override
  String get facultyEngineering => 'Faculty of Engineering';

  @override
  String get facultyScience => 'Faculty of Science';

  @override
  String get facultyMedicine => 'Faculty of Medicine';

  @override
  String get facultyDentistry => 'Faculty of Dentistry';

  @override
  String get facultyPharmacy => 'Faculty of Pharmacy';

  @override
  String get facultyNursing => 'Faculty of Nursing';

  @override
  String get facultyVeterinary => 'Faculty of Veterinary Medicine';

  @override
  String get facultyLaw => 'Faculty of Law';

  @override
  String get facultyCS => 'Faculty of Computer Science';

  @override
  String get facultyAgriculture => 'Faculty of Agriculture';

  @override
  String get facultyBusiness => 'Faculty of Commerce';

  @override
  String get facultyEducation => 'Faculty of Education';

  @override
  String get facultyArts => 'Faculty of Arts';

  @override
  String get facultyArchitecture => 'Faculty of Architecture';

  @override
  String get facultyMassCommunication => 'Faculty of Media';

  @override
  String get facultyTourism => 'Faculty of Tourism & Hotels';

  @override
  String get facultyPhysicalEducation => 'Faculty of Physical Education';

  @override
  String get facultyFineArts => 'Faculty of Fine Arts';

  @override
  String get storeChemical => 'Chemical store';

  @override
  String get storeEngineering => 'Engineering store';

  @override
  String get storeMedical => 'Medical store';

  @override
  String get storeAgricultural => 'Agricultural store';

  @override
  String get storeGeneral => 'General store';

  @override
  String get writingResearchPapers => 'Research papers';

  @override
  String get writingThesis => 'Theses';

  @override
  String get writingStatistics => 'Statistics & analysis';

  @override
  String get writingLiteratureReview => 'Literature review';

  @override
  String get writingProposal => 'Research proposals';

  @override
  String get writingEditing => 'Editing & proofreading';

  @override
  String get writingFormatting => 'Formatting & citations';

  @override
  String get writingTranslation => 'Academic translation';

  @override
  String get portalProviderDesc =>
      'Merchant, lab, academic writer, idea publisher, or supervisor offering services';

  @override
  String get portalUserDesc =>
      'Student, researcher, supervisor seeking services, or content consumer';

  @override
  String get loginWelcome => 'Welcome to AcadeGate';

  @override
  String get loginSubtitle => 'Please sign in to continue';

  @override
  String get emailLabel => 'University / email address';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get emailRequired => 'Please enter your email';

  @override
  String get loginButton => 'Sign in';

  @override
  String get orDivider => 'or';

  @override
  String get googleLogin => 'Sign in with Google';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get emailRequiredShort => 'Email is required';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get portalProviderSubtitleAlt =>
      'For those offering services on the platform';

  @override
  String get portalSuggestedPrefix => 'Based on your account role, we suggest:';

  @override
  String get portalSuggestedBadge => 'Suggested';

  @override
  String get portalEnter => 'Enter';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Please try again later.';

  @override
  String get authErrorAccountDisabled =>
      'This account has been disabled by administration.';

  @override
  String get userPortalHomeTitle => 'Researcher & student portal';

  @override
  String get switchPortalTitle => 'Switch portal';

  @override
  String get switchPortalMessage =>
      'Return to portal selection?\nYou can switch between provider and user portals anytime.';

  @override
  String get switchPortalConfirm => 'Switch';
}
