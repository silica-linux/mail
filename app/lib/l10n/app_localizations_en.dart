// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mail';

  @override
  String get mailboxInbox => 'Inbox';

  @override
  String get mailboxDrafts => 'Drafts';

  @override
  String get mailboxSent => 'Sent';

  @override
  String get mailboxArchive => 'Archive';

  @override
  String get mailboxJunk => 'Junk';

  @override
  String get mailboxTrash => 'Trash';

  @override
  String get newMessage => 'New Message';

  @override
  String get reply => 'Reply';

  @override
  String get replyAll => 'Reply All';

  @override
  String get forward => 'Forward';

  @override
  String get delete => 'Delete';

  @override
  String get archive => 'Archive';

  @override
  String get flag => 'Flag';

  @override
  String get markRead => 'Mark as Read';

  @override
  String get markUnread => 'Mark as Unread';

  @override
  String get search => 'Search';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'No messages',
    );
    return '$_temp0';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get noMessages => 'No messages';

  @override
  String get noResults => 'Nothing found';

  @override
  String get noSelection => 'No message selected';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get monthsShort => 'Jan,Feb,Mar,Apr,May,Jun,Jul,Aug,Sep,Oct,Nov,Dec';

  @override
  String dateShort(String day, String month, String year) {
    return '$month $day, $year';
  }

  @override
  String dateTime(String date, String time) {
    return '$date at $time';
  }

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get cc => 'Cc';

  @override
  String get subject => 'Subject';

  @override
  String get send => 'Send';

  @override
  String get cancel => 'Cancel';

  @override
  String attachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get remoteContentBlocked =>
      'Images and other content from the network were not loaded, to protect your privacy.';

  @override
  String get loadRemoteContent => 'Load Content';

  @override
  String get replyPrefix => 'Re: ';

  @override
  String get forwardPrefix => 'Fwd: ';

  @override
  String quoteHeader(String date, String name) {
    return 'On $date, $name wrote:';
  }

  @override
  String get forwardHeader => 'Forwarded message';

  @override
  String sendFailed(String error) {
    return 'The message could not be sent: $error';
  }

  @override
  String get noRecipients => 'Add at least one recipient.';

  @override
  String get addAccount => 'Add Account';

  @override
  String get noAccounts => 'No accounts yet';

  @override
  String get noAccountsHint => 'Add an email account to read and send mail.';

  @override
  String get emailAddress => 'Email address';

  @override
  String get yourName => 'Your name';

  @override
  String get password => 'Password';

  @override
  String get continueButton => 'Continue';

  @override
  String get signIn => 'Sign In';

  @override
  String get lookingForSettings => 'Looking for the settings of this address…';

  @override
  String get incomingServer => 'Incoming server';

  @override
  String get outgoingServer => 'Outgoing server';

  @override
  String get passwordNote => 'The password is kept in the system keyring.';

  @override
  String setupFailed(String error) {
    return 'The account could not be added: $error';
  }

  @override
  String get sampleData =>
      'Sample mail for development (MAIL_SAMPLE_DATA): no real account.';

  @override
  String get engineUnavailable => 'Mail can\'t reach its mail service';

  @override
  String get engineUnavailableHint =>
      'The service that downloads and sends mail didn\'t start. Check that Mail is installed completely, then try again.';

  @override
  String get tryAgain => 'Try Again';

  @override
  String get engineStarting => 'Starting…';

  @override
  String settingsNotFound(String error) {
    return 'The settings of this address were not found ($error). Enter the servers below.';
  }

  @override
  String get serverSettingsInvalid =>
      'Enter both servers and their ports (1–65535).';

  @override
  String get port => 'Port';

  @override
  String get userName => 'User name';

  @override
  String get editServerSettings => 'Edit Server Settings…';

  @override
  String get googleAppPassword =>
      'Signing in with a Google account page isn\'t supported yet. Use an app password, created in your Google account\'s security settings (2-step verification is required).';

  @override
  String get microsoftNotSupported =>
      'Microsoft accounts sign in only through Microsoft\'s page, which Mail doesn\'t support yet.';

  @override
  String syncFailed(String account, String error) {
    return 'Could not sync $account: $error';
  }

  @override
  String sizeBytes(int count) {
    return '$count bytes';
  }

  @override
  String sizeKb(String value) {
    return '$value KB';
  }

  @override
  String sizeMb(String value) {
    return '$value MB';
  }

  @override
  String get decimalSeparator => '.';

  @override
  String get searching => 'Searching';

  @override
  String searchScope(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
      zero: 'no results',
    );
    return 'All Mailboxes, $_temp0';
  }

  @override
  String messageCountUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0, $unread unread';
  }

  @override
  String get senderContains => 'Sender contains:';

  @override
  String get subjectContains => 'Subject contains:';

  @override
  String get tokenSender => 'Sender';

  @override
  String get tokenSubject => 'Subject';

  @override
  String twoSenders(String first, String second) {
    return '$first and $second';
  }

  @override
  String get dayBeforeYesterday => 'Day before yesterday';

  @override
  String dateNumeric(String day, String month, String year) {
    return '$month/$day/$year';
  }

  @override
  String get sidebar => 'Sidebar';

  @override
  String get junk => 'Junk';

  @override
  String get help => 'Help';

  @override
  String get addressPlaceholder => 'name@example.com';
}
