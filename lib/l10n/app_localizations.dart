import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tl.dart';
import 'app_localizations_war.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tl'),
    Locale('war')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'HATUD'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tricycle Ride Booking'**
  String get appSubtitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @myRides.
  ///
  /// In en, this message translates to:
  /// **'My Rides'**
  String get myRides;

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

  /// No description provided for @freeRides.
  ///
  /// In en, this message translates to:
  /// **'Free Rides'**
  String get freeRides;

  /// No description provided for @loyaltyProgram.
  ///
  /// In en, this message translates to:
  /// **'Loyalty Program'**
  String get loyaltyProgram;

  /// No description provided for @feelGood.
  ///
  /// In en, this message translates to:
  /// **'Feel Good'**
  String get feelGood;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @bookRide.
  ///
  /// In en, this message translates to:
  /// **'Book Ride'**
  String get bookRide;

  /// No description provided for @whereTo.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get whereTo;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @selectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select Vehicle'**
  String get selectVehicle;

  /// No description provided for @tricycle.
  ///
  /// In en, this message translates to:
  /// **'Tricycle'**
  String get tricycle;

  /// No description provided for @motorcycle.
  ///
  /// In en, this message translates to:
  /// **'Motorcycle'**
  String get motorcycle;

  /// No description provided for @estimatedFare.
  ///
  /// In en, this message translates to:
  /// **'Estimated Fare'**
  String get estimatedFare;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book Now'**
  String get bookNow;

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

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @signup.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signup;

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

  /// No description provided for @mobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number'**
  String get mobileNumber;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @welcomeMessage.
  ///
  /// In en, this message translates to:
  /// **'Book your tricycle ride with HATUD'**
  String get welcomeMessage;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @rideHistory.
  ///
  /// In en, this message translates to:
  /// **'Ride History'**
  String get rideHistory;

  /// No description provided for @upcomingRides.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Rides'**
  String get upcomingRides;

  /// No description provided for @completedRides.
  ///
  /// In en, this message translates to:
  /// **'Completed Rides'**
  String get completedRides;

  /// No description provided for @cancelledRides.
  ///
  /// In en, this message translates to:
  /// **'Cancelled Rides'**
  String get cancelledRides;

  /// No description provided for @addPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Add Payment Method'**
  String get addPaymentMethod;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @creditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get creditCard;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Promo Code'**
  String get promoCode;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @rate.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rate;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contactUs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @tagalog.
  ///
  /// In en, this message translates to:
  /// **'Tagalog'**
  String get tagalog;

  /// No description provided for @waray.
  ///
  /// In en, this message translates to:
  /// **'Waray-Waray'**
  String get waray;

  /// No description provided for @meetYourDriver.
  ///
  /// In en, this message translates to:
  /// **'Meet Your Driver'**
  String get meetYourDriver;

  /// No description provided for @trackYourTrip.
  ///
  /// In en, this message translates to:
  /// **'Track Your Trip'**
  String get trackYourTrip;

  /// No description provided for @bookTricycleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Book a tricycle ride and get picked up by a nearby Hatud driver in your area.'**
  String get bookTricycleSubtitle;

  /// No description provided for @meetDriverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with our network of trusted tricycle drivers for safe and affordable rides.'**
  String get meetDriverSubtitle;

  /// No description provided for @trackTripSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your driver\'s location in real-time and know exactly when they\'ll arrive.'**
  String get trackTripSubtitle;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createYourAccount;

  /// No description provided for @accessYourRides.
  ///
  /// In en, this message translates to:
  /// **'Access your rides, loyalty points, and live updates instantly.'**
  String get accessYourRides;

  /// No description provided for @joinOurCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join our community to request or manage rides with real-time tools.'**
  String get joinOurCommunity;

  /// No description provided for @quickBooking.
  ///
  /// In en, this message translates to:
  /// **'Quick booking'**
  String get quickBooking;

  /// No description provided for @securePayments.
  ///
  /// In en, this message translates to:
  /// **'Secure payments'**
  String get securePayments;

  /// No description provided for @liveRideTracking.
  ///
  /// In en, this message translates to:
  /// **'Live ride tracking'**
  String get liveRideTracking;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @bySigningUp.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our'**
  String get bySigningUp;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'Terms and Conditions'**
  String get termsAndConditions;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get and;

  /// No description provided for @bookHistory.
  ///
  /// In en, this message translates to:
  /// **'Book History'**
  String get bookHistory;

  /// No description provided for @emergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get emergency;

  /// No description provided for @whereYouAre.
  ///
  /// In en, this message translates to:
  /// **'Where you are'**
  String get whereYouAre;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @enterDestinationAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter destination address'**
  String get enterDestinationAddress;

  /// No description provided for @enterFareAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter fare amount'**
  String get enterFareAmount;

  /// No description provided for @pickupLocation.
  ///
  /// In en, this message translates to:
  /// **'Pickup Location'**
  String get pickupLocation;

  /// No description provided for @distanceToDestination.
  ///
  /// In en, this message translates to:
  /// **'Distance to destination'**
  String get distanceToDestination;

  /// No description provided for @finalFareMayVary.
  ///
  /// In en, this message translates to:
  /// **'Final fare may vary depending on traffic and exact route.'**
  String get finalFareMayVary;

  /// No description provided for @vehicleType.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Type'**
  String get vehicleType;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @failedToUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get failedToUpdateProfile;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty'**
  String get nameCannotBeEmpty;

  /// No description provided for @phoneNumberCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Phone number cannot be empty'**
  String get phoneNumberCannotBeEmpty;

  /// No description provided for @pleaseEnterDestination.
  ///
  /// In en, this message translates to:
  /// **'Please enter a destination'**
  String get pleaseEnterDestination;

  /// No description provided for @pleaseEnterFareAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a fare amount'**
  String get pleaseEnterFareAmount;

  /// No description provided for @pleaseEnterValidFareAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid fare amount'**
  String get pleaseEnterValidFareAmount;

  /// No description provided for @selectProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Select Profile Picture'**
  String get selectProfilePicture;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @uploadingImage.
  ///
  /// In en, this message translates to:
  /// **'Uploading image...'**
  String get uploadingImage;

  /// No description provided for @profilePictureUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully!'**
  String get profilePictureUpdatedSuccessfully;

  /// No description provided for @failedToUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image'**
  String get failedToUploadImage;

  /// No description provided for @profilePictureRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile picture removed successfully!'**
  String get profilePictureRemovedSuccessfully;

  /// No description provided for @failedToRemoveProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove profile picture'**
  String get failedToRemoveProfilePicture;

  /// No description provided for @driverSelected.
  ///
  /// In en, this message translates to:
  /// **'Driver selected. Review the ride details below before confirming.'**
  String get driverSelected;

  /// No description provided for @bookingRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Booking request sent to {driverName}'**
  String bookingRequestSent(String driverName);

  /// No description provided for @errorSendingBookingRequest.
  ///
  /// In en, this message translates to:
  /// **'Error sending booking request. Please try again.'**
  String get errorSendingBookingRequest;

  /// No description provided for @rideBookedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ride booked successfully!'**
  String get rideBookedSuccessfully;

  /// No description provided for @noUserLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Error: No user logged in'**
  String get noUserLoggedIn;

  /// No description provided for @pickupLocationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Error: Pickup location not set'**
  String get pickupLocationNotSet;

  /// No description provided for @passengerLocation.
  ///
  /// In en, this message translates to:
  /// **'Passenger Location'**
  String get passengerLocation;

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your Location'**
  String get yourLocation;

  /// No description provided for @driverLocation.
  ///
  /// In en, this message translates to:
  /// **'Driver Location'**
  String get driverLocation;

  /// No description provided for @onlineDriver.
  ///
  /// In en, this message translates to:
  /// **'Online Driver'**
  String get onlineDriver;

  /// No description provided for @passenger.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passenger;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @areYouSureLogout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get areYouSureLogout;

  /// No description provided for @newUserRegistered.
  ///
  /// In en, this message translates to:
  /// **'New User Registered'**
  String get newUserRegistered;

  /// No description provided for @newHarassmentReport.
  ///
  /// In en, this message translates to:
  /// **'New Harassment Report'**
  String get newHarassmentReport;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @viewReport.
  ///
  /// In en, this message translates to:
  /// **'View Report'**
  String get viewReport;

  /// No description provided for @systemNotifications.
  ///
  /// In en, this message translates to:
  /// **'System Notifications'**
  String get systemNotifications;

  /// No description provided for @platformAlerts.
  ///
  /// In en, this message translates to:
  /// **'Platform alerts and administrator updates'**
  String get platformAlerts;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications to review right now.'**
  String get noNotifications;

  /// No description provided for @fleetMonitoring.
  ///
  /// In en, this message translates to:
  /// **'Fleet & Ride Monitoring'**
  String get fleetMonitoring;

  /// No description provided for @liveView.
  ///
  /// In en, this message translates to:
  /// **'Live view of active drivers and ride density'**
  String get liveView;

  /// No description provided for @expandMap.
  ///
  /// In en, this message translates to:
  /// **'Expand Map'**
  String get expandMap;

  /// No description provided for @activeDrivers.
  ///
  /// In en, this message translates to:
  /// **'Active Drivers'**
  String get activeDrivers;

  /// No description provided for @liveRides.
  ///
  /// In en, this message translates to:
  /// **'Live Rides'**
  String get liveRides;

  /// No description provided for @alertsToday.
  ///
  /// In en, this message translates to:
  /// **'Alerts Today'**
  String get alertsToday;

  /// No description provided for @recentRideActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Ride Activity'**
  String get recentRideActivity;

  /// No description provided for @refreshData.
  ///
  /// In en, this message translates to:
  /// **'Refresh data'**
  String get refreshData;

  /// No description provided for @harassmentReports.
  ///
  /// In en, this message translates to:
  /// **'Harassment Reports'**
  String get harassmentReports;

  /// No description provided for @monitorVerify.
  ///
  /// In en, this message translates to:
  /// **'Monitor, verify, and act quickly on safety concerns'**
  String get monitorVerify;

  /// No description provided for @downloadCsv.
  ///
  /// In en, this message translates to:
  /// **'Download CSV'**
  String get downloadCsv;

  /// No description provided for @allClear.
  ///
  /// In en, this message translates to:
  /// **'All clear. No harassment reports at the moment.'**
  String get allClear;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @monitoring.
  ///
  /// In en, this message translates to:
  /// **'Monitoring'**
  String get monitoring;

  /// No description provided for @harassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get harassment;

  /// No description provided for @hatudDriver.
  ///
  /// In en, this message translates to:
  /// **'HATUD Driver'**
  String get hatudDriver;

  /// No description provided for @hatudPassenger.
  ///
  /// In en, this message translates to:
  /// **'HATUD Passenger'**
  String get hatudPassenger;

  /// No description provided for @hatudAdmin.
  ///
  /// In en, this message translates to:
  /// **'HATUD Admin'**
  String get hatudAdmin;

  /// No description provided for @useFaceId.
  ///
  /// In en, this message translates to:
  /// **'Use Face ID'**
  String get useFaceId;

  /// No description provided for @mobileNumberOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Mobile Number or Email'**
  String get mobileNumberOrEmail;

  /// No description provided for @pleaseEnterMobileOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter mobile or email'**
  String get pleaseEnterMobileOrEmail;

  /// No description provided for @passwordIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordIsRequired;

  /// No description provided for @minimum6Characters.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get minimum6Characters;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @emailIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailIsRequired;

  /// No description provided for @pleaseEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// No description provided for @mobileNumberIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Mobile number is required'**
  String get mobileNumberIsRequired;

  /// No description provided for @addressIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Address is required'**
  String get addressIsRequired;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @driverLicenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver License Number'**
  String get driverLicenseNumberLabel;

  /// No description provided for @driverLicenseNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Driver license number is required'**
  String get driverLicenseNumberRequired;

  /// No description provided for @tricyclePlateNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tricycle Plate Number'**
  String get tricyclePlateNumberLabel;

  /// No description provided for @tricyclePlateNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Tricycle plate number is required'**
  String get tricyclePlateNumberRequired;

  /// No description provided for @driverLicensePhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Driver license photo required'**
  String get driverLicensePhotoRequired;

  /// No description provided for @tricyclePlatePhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Tricycle plate photo required'**
  String get tricyclePlatePhotoRequired;

  /// No description provided for @bookARide.
  ///
  /// In en, this message translates to:
  /// **'Book a Ride'**
  String get bookARide;

  /// No description provided for @selectDestination.
  ///
  /// In en, this message translates to:
  /// **'Select Destination'**
  String get selectDestination;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm password'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @pleaseSelectRole.
  ///
  /// In en, this message translates to:
  /// **'Please select a role'**
  String get pleaseSelectRole;

  /// No description provided for @accountInactive.
  ///
  /// In en, this message translates to:
  /// **'Your account is inactive. Please contact support.'**
  String get accountInactive;

  /// No description provided for @welcomeBackUser.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {userName}!'**
  String welcomeBackUser(String userName);

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String loginFailed(String error);

  /// No description provided for @accountCreatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully! Please sign in.'**
  String get accountCreatedSuccessfully;

  /// No description provided for @registrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed: {error}'**
  String registrationFailed(String error);

  /// No description provided for @cameraWorksOnMobileOnly.
  ///
  /// In en, this message translates to:
  /// **'Camera works on mobile devices only'**
  String get cameraWorksOnMobileOnly;

  /// No description provided for @failedToCaptureImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to capture image. Please try again.'**
  String get failedToCaptureImage;

  /// No description provided for @storagePermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Storage permission is required. Please enable it in settings.'**
  String get storagePermissionRequired;

  /// No description provided for @cameraPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is required. Please enable it in settings.'**
  String get cameraPermissionRequired;

  /// No description provided for @galleryNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Gallery not supported on this platform. Please use a mobile device or emulator.'**
  String get galleryNotSupported;

  /// No description provided for @selectRole.
  ///
  /// In en, this message translates to:
  /// **'Select Role'**
  String get selectRole;

  /// No description provided for @chooseHowToExperience.
  ///
  /// In en, this message translates to:
  /// **'Choose how you would like to experience HATUD today.'**
  String get chooseHowToExperience;

  /// No description provided for @passengerDescription.
  ///
  /// In en, this message translates to:
  /// **'Book rides quickly with real-time tracking.'**
  String get passengerDescription;

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @driverDescription.
  ///
  /// In en, this message translates to:
  /// **'Accept bookings and manage your daily rides.'**
  String get driverDescription;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @adminDescription.
  ///
  /// In en, this message translates to:
  /// **'Monitor activity and keep the fleet running smoothly.'**
  String get adminDescription;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @sendingBookingRequest.
  ///
  /// In en, this message translates to:
  /// **'Sending booking request...'**
  String get sendingBookingRequest;

  /// No description provided for @tripTracking.
  ///
  /// In en, this message translates to:
  /// **'Trip Tracking'**
  String get tripTracking;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @driverLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverLabel;

  /// No description provided for @plate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get plate;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @noRideHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No ride history yet.'**
  String get noRideHistoryYet;

  /// No description provided for @promoVouchers.
  ///
  /// In en, this message translates to:
  /// **'Promo Vouchers'**
  String get promoVouchers;

  /// No description provided for @welcome20.
  ///
  /// In en, this message translates to:
  /// **'WELCOME20'**
  String get welcome20;

  /// No description provided for @welcome20Description.
  ///
  /// In en, this message translates to:
  /// **'20% off your first ride'**
  String get welcome20Description;

  /// No description provided for @applyCode.
  ///
  /// In en, this message translates to:
  /// **'Apply Code'**
  String get applyCode;

  /// No description provided for @rideWeekend.
  ///
  /// In en, this message translates to:
  /// **'RIDEWEEKEND'**
  String get rideWeekend;

  /// No description provided for @rideWeekendDescription.
  ///
  /// In en, this message translates to:
  /// **'₱50 off weekend rides'**
  String get rideWeekendDescription;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @noDriversAvailable.
  ///
  /// In en, this message translates to:
  /// **'No drivers available at the moment. Please try again later.'**
  String get noDriversAvailable;

  /// No description provided for @rateDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate Driver'**
  String get rateDriver;

  /// No description provided for @rateYourRideWith.
  ///
  /// In en, this message translates to:
  /// **'Rate your ride with'**
  String get rateYourRideWith;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a Review (Optional)'**
  String get writeReview;

  /// No description provided for @writeReviewHint.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get writeReviewHint;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @ratingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Thank you! Your rating has been submitted.'**
  String get ratingSubmitted;

  /// No description provided for @errorSubmittingRating.
  ///
  /// In en, this message translates to:
  /// **'Error submitting rating. Please try again.'**
  String get errorSubmittingRating;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'tl', 'war'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'tl': return AppLocalizationsTl();
    case 'war': return AppLocalizationsWar();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
