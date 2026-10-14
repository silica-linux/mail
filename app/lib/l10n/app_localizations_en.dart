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
  String searchResults(String query) {
    return 'Results for “$query”';
  }

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
  String get engineMissing =>
      'The mail engine is not running: showing sample mail.';

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
}
