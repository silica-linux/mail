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
  /// **'No Message Selected'**
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

  /// Label of the attachments row in the composer.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

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

  /// Toolbar button of the list: choose which messages to show.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// Toolbar button of the list: a menu of further actions.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// Filter menu item: show every message.
  ///
  /// In en, this message translates to:
  /// **'All Messages'**
  String get showAllMessages;

  /// Filter menu item: show only unread messages.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get showUnread;

  /// Filter menu item: show only flagged messages.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get showFlagged;

  /// Header in the search results: messages with the text in the sender or the subject.
  ///
  /// In en, this message translates to:
  /// **'Best Matches'**
  String get bestMatches;

  /// Header in the search results: the other matches.
  ///
  /// In en, this message translates to:
  /// **'All Results'**
  String get allResults;

  /// Sidebar row while searching: the search covers every mailbox.
  ///
  /// In en, this message translates to:
  /// **'All Mailboxes'**
  String get allMailboxes;

  /// Sidebar section header while searching.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchSection;

  /// Alert when closing a changed message in the composer.
  ///
  /// In en, this message translates to:
  /// **'Save this message as a draft?'**
  String get saveDraftTitle;

  /// Text of the alert when closing a changed message.
  ///
  /// In en, this message translates to:
  /// **'The message has changes that have not been saved. You can keep it as a draft or discard it.'**
  String get saveDraftMessage;

  /// Alert button: keep the message as a draft.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Alert button: discard the message.
  ///
  /// In en, this message translates to:
  /// **'Don’t Save'**
  String get dontSave;

  /// Under the title of the account setup, first step.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and Mail will find the settings.'**
  String get addAccountHint;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get menuFile;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get menuEdit;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get menuView;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mailbox'**
  String get menuMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get menuMessage;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get menuFormat;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Window'**
  String get menuWindow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get menuHelp;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'About Mail'**
  String get menuAboutMail;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Settings…'**
  String get menuSettingsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Accounts…'**
  String get menuAccountsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Add Account…'**
  String get menuAddAccountDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'New Viewer Window'**
  String get menuNewViewerWindow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Open Message'**
  String get menuOpenMessage;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Open Messages'**
  String get menuOpenMessages;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get menuClose;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get menuSave;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Save As…'**
  String get menuSaveAsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Attach Files…'**
  String get menuAttachFilesDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Save Attachments…'**
  String get menuSaveAttachmentsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Quick Look Attachments…'**
  String get menuQuickLookAttachmentsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Import Mailboxes…'**
  String get menuImportMailboxesDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Export as PDF…'**
  String get menuExportAsPDFDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Print…'**
  String get menuPrintDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get menuComplete;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Paste as Quotation'**
  String get menuPasteAsQuotation;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Paste and Match Style'**
  String get menuPasteAndMatchStyle;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Append Selected Messages'**
  String get menuAppendSelectedMessages;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Add Link…'**
  String get menuAddLinkDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get menuAttachments;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Always Send Windows-Friendly Attachments'**
  String get menuAlwaysSendWindowsFriendlyAttachments;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Always Insert Attachments at End of Message'**
  String get menuAlwaysInsertAttachmentsAtEndOfMessage;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Include Attachments With Replies'**
  String get menuIncludeAttachmentsWithReplies;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get menuAlways;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get menuNever;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'When Adding Recipients'**
  String get menuWhenAddingRecipients;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get menuAsk;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Find'**
  String get menuFind;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mailbox Search'**
  String get menuMailboxSearch;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Find…'**
  String get menuFindDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Find Next'**
  String get menuFindNext;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Find Previous'**
  String get menuFindPrevious;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Use Selection for Find'**
  String get menuUseSelectionForFind;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Jump to Selection'**
  String get menuJumpToSelection;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Jump to Top'**
  String get menuJumpToTop;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Writing Tools'**
  String get menuWritingTools;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Writing Tools'**
  String get menuShowWritingTools;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Proofread'**
  String get menuProofread;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Rewrite'**
  String get menuRewrite;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Friendly'**
  String get menuMakeFriendly;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Professional'**
  String get menuMakeProfessional;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Concise'**
  String get menuMakeConcise;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Summarize'**
  String get menuSummarize;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Create Key Points'**
  String get menuCreateKeyPoints;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make List'**
  String get menuMakeList;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Table'**
  String get menuMakeTable;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Compose…'**
  String get menuComposeDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Spelling and Grammar'**
  String get menuSpellingAndGrammar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Spelling and Grammar'**
  String get menuShowSpellingAndGrammar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Check Document Now'**
  String get menuCheckDocumentNow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Check Spelling'**
  String get menuCheckSpelling;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'While Typing'**
  String get menuWhileTyping;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Before Sending'**
  String get menuBeforeSending;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Check Grammar with Spelling'**
  String get menuCheckGrammarWithSpelling;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Correct Spelling Automatically'**
  String get menuCorrectSpellingAutomatically;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Substitutions'**
  String get menuSubstitutions;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Substitutions'**
  String get menuShowSubstitutions;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smart Copy/Paste'**
  String get menuSmartCopyPaste;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smart Quotes'**
  String get menuSmartQuotes;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smart Lists'**
  String get menuSmartLists;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smart Dashes'**
  String get menuSmartDashes;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smart Links'**
  String get menuSmartLinks;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Text Replacement'**
  String get menuTextReplacement;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Transformations'**
  String get menuTransformations;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Upper Case'**
  String get menuMakeUpperCase;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Lower Case'**
  String get menuMakeLowerCase;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Capitalize'**
  String get menuCapitalize;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get menuSpeech;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Start Speaking'**
  String get menuStartSpeaking;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Stop Speaking'**
  String get menuStopSpeaking;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'AutoFill'**
  String get menuAutoFill;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Contact…'**
  String get menuContactDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Passwords…'**
  String get menuPasswordsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Credit Card…'**
  String get menuCreditCardDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Start Dictation…'**
  String get menuStartDictationDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Emoji & Symbols'**
  String get menuEmojiSymbols;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Tab Bar'**
  String get menuShowTabBar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show All Tabs'**
  String get menuShowAllTabs;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get menuFilter;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Enable Message Filter'**
  String get menuEnableMessageFilter;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Include:'**
  String get menuInclude;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get menuUnread;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get menuFlagged;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Addressed:'**
  String get menuAddressed;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'To: Me'**
  String get menuToMe;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Cc: Me'**
  String get menuCcMe;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Only Mail with Attachments'**
  String get menuOnlyMailWithAttachments;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Only from VIP'**
  String get menuOnlyFromVIP;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get menuSortBy;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get menuDate;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Date Sent'**
  String get menuDateSent;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remind Me'**
  String get menuRemindMe;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send Later'**
  String get menuSendLater;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get menuFlags;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get menuFrom;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get menuSize;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get menuSubject;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get menuTo;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get menuSortUnread;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Oldest Message on Top'**
  String get menuOldestMessageOnTop;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Newest Message on Top'**
  String get menuNewestMessageOnTop;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Use Column Layout'**
  String get menuUseColumnLayout;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Bottom Preview'**
  String get menuShowBottomPreview;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Date and Time'**
  String get menuShowDateAndTime;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show To/Cc Label'**
  String get menuShowToCcLabel;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Message Size'**
  String get menuShowMessageSize;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Contact Photo'**
  String get menuShowContactPhoto;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Mail Categories'**
  String get menuShowMailCategories;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Priority Messages'**
  String get menuShowPriorityMessages;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'About Categories…'**
  String get menuAboutCategoriesDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Highlight Conversations'**
  String get menuHighlightConversations;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Organize by Conversation'**
  String get menuOrganizeByConversation;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Expand All Conversations'**
  String get menuExpandAllConversations;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Collapse All Conversations'**
  String get menuCollapseAllConversations;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Cc Address Field'**
  String get menuCcAddressField;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Bcc Address Field'**
  String get menuBccAddressField;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Reply-To Address Field'**
  String get menuReplyToAddressField;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Priority Field'**
  String get menuPriorityField;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show with Light Background'**
  String get menuShowWithLightBackground;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'All Headers'**
  String get menuAllHeaders;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Raw Source'**
  String get menuRawSource;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Hide Related Messages'**
  String get menuHideRelatedMessages;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Hide Sidebar'**
  String get menuHideSidebar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Sidebar'**
  String get menuShowSidebar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Hide Toolbar'**
  String get menuHideToolbar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Customize Toolbar…'**
  String get menuCustomizeToolbarDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Favorites Bar'**
  String get menuShowFavoritesBar;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Get New Mail'**
  String get menuGetNewMail;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mark All Messages as Read'**
  String get menuMarkAllMessagesAsRead;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Erase Deleted Items'**
  String get menuEraseDeletedItems;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'In All Accounts…'**
  String get menuInAllAccountsDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'In All Accounts'**
  String get menuInAllAccounts;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Erase Junk Mail'**
  String get menuEraseJunkMail;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'New Mailbox…'**
  String get menuNewMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Add Favorite Mailbox…'**
  String get menuAddFavoriteMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'New Smart Mailbox…'**
  String get menuNewSmartMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Edit Smart Mailbox…'**
  String get menuEditSmartMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Smart Mailbox'**
  String get menuDuplicateSmartMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'New Smart Mailbox Folder…'**
  String get menuNewSmartMailboxFolderDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Rename Mailbox…'**
  String get menuRenameMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Delete Mailbox…'**
  String get menuDeleteMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Export Mailbox…'**
  String get menuExportMailboxDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Go to Favorite Mailbox'**
  String get menuGoToFavoriteMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Move to Favorite Mailbox'**
  String get menuMoveToFavoriteMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Go to Previous Mailbox'**
  String get menuGoToPreviousMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Go to Next Mailbox'**
  String get menuGoToNextMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Rebuild'**
  String get menuRebuild;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send Again'**
  String get menuSendAgain;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get menuSend;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send 21:00 Tonight'**
  String get menuSend2100Tonight;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send 08:00 Tomorrow'**
  String get menuSend0800Tomorrow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Send Later…'**
  String get menuSendLaterDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Forward as Attachment'**
  String get menuForwardAsAttachment;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Redirect'**
  String get menuRedirect;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remind Me in 1 Hour'**
  String get menuRemindMeIn1Hour;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remind Me Tonight'**
  String get menuRemindMeTonight;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remind Me Tomorrow'**
  String get menuRemindMeTomorrow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remind Me Later…'**
  String get menuRemindMeLaterDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Clear Reminder'**
  String get menuClearReminder;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Ignore Follow Up'**
  String get menuIgnoreFollowUp;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mark as Unread'**
  String get menuMarkAsUnread;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mark as Read'**
  String get menuMarkAsRead;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Move to Junk'**
  String get menuMoveToJunk;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get menuMute;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get menuUnmute;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Flag'**
  String get menuFlag;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get menuOrange;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get menuRed;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get menuPurple;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get menuBlue;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get menuYellow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get menuGreen;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Gray'**
  String get menuGray;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Clear Flag'**
  String get menuClearFlag;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Toggle Flag'**
  String get menuToggleFlag;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Set Priority'**
  String get menuSetPriority;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get menuLow;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get menuNormal;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get menuHigh;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Move to Predicted Mailbox'**
  String get menuMoveToPredictedMailbox;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get menuMoveTo;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Copy to'**
  String get menuCopyTo;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Move Again'**
  String get menuMoveAgain;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Apply Rules'**
  String get menuApplyRules;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Add Sender to Contacts'**
  String get menuAddSenderToContacts;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Categorize Sender'**
  String get menuCategorizeSender;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Automatically'**
  String get menuAutomatically;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Always Categorize as'**
  String get menuAlwaysCategorizeAs;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get menuPrimary;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get menuTransactions;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get menuUpdates;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get menuPromotions;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remove Attachments'**
  String get menuRemoveAttachments;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Fonts'**
  String get menuShowFonts;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Show Colors'**
  String get menuShowColors;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get menuLists;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Insert Bulleted List'**
  String get menuInsertBulletedList;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Insert Numbered List'**
  String get menuInsertNumberedList;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remove List Formatting'**
  String get menuRemoveListFormatting;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Increase List Level'**
  String get menuIncreaseListLevel;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Decrease List Level'**
  String get menuDecreaseListLevel;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Convert to Numbered List'**
  String get menuConvertToNumberedList;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get menuStyle;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get menuBold;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get menuItalic;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get menuUnderline;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get menuOutline;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Bigger'**
  String get menuBigger;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get menuSmaller;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Copy Style'**
  String get menuCopyStyle;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Paste Style'**
  String get menuPasteStyle;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remove Style'**
  String get menuRemoveStyle;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Styles…'**
  String get menuStylesDots;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get menuAlignment;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Align Left'**
  String get menuAlignLeft;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get menuCenter;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Justify'**
  String get menuJustify;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Align Right'**
  String get menuAlignRight;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Float Left'**
  String get menuFloatLeft;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Float Right'**
  String get menuFloatRight;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Remove Float'**
  String get menuRemoveFloat;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Writing Direction'**
  String get menuWritingDirection;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Paragraph'**
  String get menuParagraph;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get menuSelection;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get menuDefault;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Left to Right'**
  String get menuLeftToRight;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Right to Left'**
  String get menuRightToLeft;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Indentation'**
  String get menuIndentation;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get menuIncrease;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get menuDecrease;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Quote Level'**
  String get menuQuoteLevel;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Rich Text'**
  String get menuMakeRichText;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Make Plain Text'**
  String get menuMakePlainText;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Message Viewer'**
  String get menuMessageViewer;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Photo Browser'**
  String get menuPhotoBrowser;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Previous Recipients'**
  String get menuPreviousRecipients;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get menuActivity;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Connection Doctor'**
  String get menuConnectionDoctor;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'Mail Help'**
  String get menuMailHelp;

  /// Menu bar item.
  ///
  /// In en, this message translates to:
  /// **'What’s New in Mail?'**
  String get menuWhatsNewInMail;

  /// Mailbox menu: fetch the new mail of one account.
  ///
  /// In en, this message translates to:
  /// **'Synchronize “{account}”'**
  String menuSynchronize(String account);

  /// Message menu, Categorize Sender submenu.
  ///
  /// In en, this message translates to:
  /// **'Categorize all messages from “{sender}”'**
  String menuCategorizeAll(String sender);
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
