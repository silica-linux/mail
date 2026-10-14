import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

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
    Locale('en'),
    Locale('it'),
  ];

  /// The name of the app, in the window title and the menu bar.
  ///
  /// In en, this message translates to:
  /// **'Mail'**
  String get appTitle;

  /// The incoming mailbox of an account.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get mailboxInbox;

  /// Mailbox of unfinished messages.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get mailboxDrafts;

  /// Mailbox of sent messages.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get mailboxSent;

  /// Mailbox of archived messages.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get mailboxArchive;

  /// Mailbox of unwanted messages (spam).
  ///
  /// In en, this message translates to:
  /// **'Junk'**
  String get mailboxJunk;

  /// Mailbox of deleted messages.
  ///
  /// In en, this message translates to:
  /// **'Trash'**
  String get mailboxTrash;

  /// Toolbar button and window title of the composer.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get newMessage;

  /// Toolbar button: answer the sender.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// Toolbar button: answer the sender and every recipient.
  ///
  /// In en, this message translates to:
  /// **'Reply All'**
  String get replyAll;

  /// Toolbar button: send the message to someone else.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// Toolbar button: move the message to the Trash.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Toolbar button: move the message to the Archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// Toolbar button: mark the message as important.
  ///
  /// In en, this message translates to:
  /// **'Flag'**
  String get flag;

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Mark as Read'**
  String get markRead;

  /// Menu item.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unread'**
  String get markUnread;

  /// Placeholder of the search field.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Under the mailbox title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No messages} =1{1 message} other{{count} messages}}'**
  String messageCount(int count);

  /// Accessible text of the unread count in the sidebar.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unread} other{{count} unread}}'**
  String unreadCount(int count);

  /// Empty mailbox.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get noMessages;

  /// Search without results.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get noResults;

  /// Reader with nothing selected.
  ///
  /// In en, this message translates to:
  /// **'No message selected'**
  String get noSelection;

  /// Date of a message received today, before the time when needed.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Date of a message received yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Short month names, comma separated.
  ///
  /// In en, this message translates to:
  /// **'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec'**
  String get monthsShort;

  /// A date in the list.
  ///
  /// In en, this message translates to:
  /// **'{month} {day}, {year}'**
  String dateShort(String day, String month, String year);

  /// Date and time in the reader.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String dateTime(String date, String time);

  /// Header label.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// Header label and composer field.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// Header label and composer field (carbon copy).
  ///
  /// In en, this message translates to:
  /// **'Cc'**
  String get cc;

  /// Composer field.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// Composer button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Button.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Above the attachments in the reader.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attachment} other{{count} attachments}}'**
  String attachmentCount(int count);

  /// Banner above a message with remote content.
  ///
  /// In en, this message translates to:
  /// **'Images and other content from the network were not loaded, to protect your privacy.'**
  String get remoteContentBlocked;

  /// Banner button.
  ///
  /// In en, this message translates to:
  /// **'Load Content'**
  String get loadRemoteContent;

  /// Prefix of the subject of a reply.
  ///
  /// In en, this message translates to:
  /// **'Re: '**
  String get replyPrefix;

  /// Prefix of the subject of a forwarded message.
  ///
  /// In en, this message translates to:
  /// **'Fwd: '**
  String get forwardPrefix;

  /// Line above the quoted text of a reply.
  ///
  /// In en, this message translates to:
  /// **'On {date}, {name} wrote:'**
  String quoteHeader(String date, String name);

  /// Line above a forwarded message.
  ///
  /// In en, this message translates to:
  /// **'Forwarded message'**
  String get forwardHeader;

  /// Composer error.
  ///
  /// In en, this message translates to:
  /// **'The message could not be sent: {error}'**
  String sendFailed(String error);

  /// Composer error.
  ///
  /// In en, this message translates to:
  /// **'Add at least one recipient.'**
  String get noRecipients;

  /// Button and title of the account setup.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// First start, title.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccounts;

  /// First start, text.
  ///
  /// In en, this message translates to:
  /// **'Add an email account to read and send mail.'**
  String get noAccountsHint;

  /// Setup field.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// Setup field.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// Setup field.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Setup button.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// Setup button.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Setup progress.
  ///
  /// In en, this message translates to:
  /// **'Looking for the settings of this address…'**
  String get lookingForSettings;

  /// Setup label (IMAP).
  ///
  /// In en, this message translates to:
  /// **'Incoming server'**
  String get incomingServer;

  /// Setup label (SMTP).
  ///
  /// In en, this message translates to:
  /// **'Outgoing server'**
  String get outgoingServer;

  /// Setup note.
  ///
  /// In en, this message translates to:
  /// **'The password is kept in the system keyring.'**
  String get passwordNote;

  /// Setup error.
  ///
  /// In en, this message translates to:
  /// **'The account could not be added: {error}'**
  String setupFailed(String error);

  /// Banner when the app runs on generated sample mail.
  ///
  /// In en, this message translates to:
  /// **'Sample mail for development (MAIL_SAMPLE_DATA): no real account.'**
  String get sampleData;

  /// Title when the mail engine (a background service) can't be started.
  ///
  /// In en, this message translates to:
  /// **'Mail can\'t reach its mail service'**
  String get engineUnavailable;

  /// Explanation under engineUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service that downloads and sends mail didn\'t start. Check that Mail is installed completely, then try again.'**
  String get engineUnavailableHint;

  /// Button that starts the mail engine again.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// Shown while the engine is being started again.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get engineStarting;

  /// Setup: discovery failed, the manual form follows.
  ///
  /// In en, this message translates to:
  /// **'The settings of this address were not found ({error}). Enter the servers below.'**
  String settingsNotFound(String error);

  /// Setup: the manual server form is incomplete.
  ///
  /// In en, this message translates to:
  /// **'Enter both servers and their ports (1–65535).'**
  String get serverSettingsInvalid;

  /// Setup label of a server port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// Setup label of the login name of the servers.
  ///
  /// In en, this message translates to:
  /// **'User name'**
  String get userName;

  /// Setup link back to the manual server form.
  ///
  /// In en, this message translates to:
  /// **'Edit Server Settings…'**
  String get editServerSettings;

  /// Setup note for Google servers (OAuth is not supported yet).
  ///
  /// In en, this message translates to:
  /// **'Signing in with a Google account page isn\'t supported yet. Use an app password, created in your Google account\'s security settings (2-step verification is required).'**
  String get googleAppPassword;

  /// Setup note for Microsoft servers: they can't be added yet.
  ///
  /// In en, this message translates to:
  /// **'Microsoft accounts sign in only through Microsoft\'s page, which Mail doesn\'t support yet.'**
  String get microsoftNotSupported;

  /// Banner after a sync error.
  ///
  /// In en, this message translates to:
  /// **'Could not sync {account}: {error}'**
  String syncFailed(String account, String error);

  /// A size under 1000 bytes.
  ///
  /// In en, this message translates to:
  /// **'{count} bytes'**
  String sizeBytes(int count);

  /// A size in kilobytes.
  ///
  /// In en, this message translates to:
  /// **'{value} KB'**
  String sizeKb(String value);

  /// A size in megabytes.
  ///
  /// In en, this message translates to:
  /// **'{value} MB'**
  String sizeMb(String value);

  /// The decimal separator of the language.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get decimalSeparator;

  /// Title of the list while searching.
  ///
  /// In en, this message translates to:
  /// **'Searching'**
  String get searching;

  /// Under the title while searching: where and how many.
  ///
  /// In en, this message translates to:
  /// **'All Mailboxes, {count, plural, =0{no results} =1{1 result} other{{count} results}}'**
  String searchScope(int count);

  /// Under the mailbox title when some messages are unread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 message} other{{count} messages}}, {unread} unread'**
  String messageCountUnread(int count, int unread);

  /// Search suggestion: look for the text in the sender only.
  ///
  /// In en, this message translates to:
  /// **'Sender contains:'**
  String get senderContains;

  /// Search suggestion: look for the text in the subject only.
  ///
  /// In en, this message translates to:
  /// **'Subject contains:'**
  String get subjectContains;

  /// Search token before the text (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get tokenSender;

  /// Search token before the text (shown in capitals).
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get tokenSubject;

  /// The senders of a two-person conversation in the list.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String twoSenders(String first, String second);

  /// Date of a message received two days ago.
  ///
  /// In en, this message translates to:
  /// **'Day before yesterday'**
  String get dayBeforeYesterday;

  /// A date in the list, numeric with a two-digit year.
  ///
  /// In en, this message translates to:
  /// **'{month}/{day}/{year}'**
  String dateNumeric(String day, String month, String year);

  /// Toolbar button: show or hide the sidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get sidebar;

  /// Toolbar button: move the message to the Junk mailbox.
  ///
  /// In en, this message translates to:
  /// **'Junk'**
  String get junk;

  /// Accessible label of the help button.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// Placeholder of the address field in the account setup.
  ///
  /// In en, this message translates to:
  /// **'name@example.com'**
  String get addressPlaceholder;
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
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
