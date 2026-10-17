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
  String get noSelection => 'No Message Selected';

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
  String get attachments => 'Attachments';

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

  @override
  String get filter => 'Filter';

  @override
  String get more => 'More';

  @override
  String get showAllMessages => 'All Messages';

  @override
  String get showUnread => 'Unread';

  @override
  String get showFlagged => 'Flagged';

  @override
  String get bestMatches => 'Best Matches';

  @override
  String get allResults => 'All Results';

  @override
  String get allMailboxes => 'All Mailboxes';

  @override
  String get searchSection => 'Search';

  @override
  String get saveDraftTitle => 'Save this message as a draft?';

  @override
  String get saveDraftMessage =>
      'The message has changes that have not been saved. You can keep it as a draft or discard it.';

  @override
  String get save => 'Save';

  @override
  String get dontSave => 'Don’t Save';

  @override
  String get addAccountHint =>
      'Enter your email address and Mail will find the settings.';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuMailbox => 'Mailbox';

  @override
  String get menuMessage => 'Message';

  @override
  String get menuFormat => 'Format';

  @override
  String get menuWindow => 'Window';

  @override
  String get menuHelp => 'Help';

  @override
  String get menuAboutMail => 'About Mail';

  @override
  String get menuSettingsDots => 'Settings…';

  @override
  String get menuAccountsDots => 'Accounts…';

  @override
  String get menuAddAccountDots => 'Add Account…';

  @override
  String get menuNewViewerWindow => 'New Viewer Window';

  @override
  String get menuOpenMessage => 'Open Message';

  @override
  String get menuOpenMessages => 'Open Messages';

  @override
  String get menuClose => 'Close';

  @override
  String get menuSave => 'Save';

  @override
  String get menuSaveAsDots => 'Save As…';

  @override
  String get menuAttachFilesDots => 'Attach Files…';

  @override
  String get menuSaveAttachmentsDots => 'Save Attachments…';

  @override
  String get menuQuickLookAttachmentsDots => 'Quick Look Attachments…';

  @override
  String get menuImportMailboxesDots => 'Import Mailboxes…';

  @override
  String get menuExportAsPDFDots => 'Export as PDF…';

  @override
  String get menuPrintDots => 'Print…';

  @override
  String get menuComplete => 'Complete';

  @override
  String get menuPasteAsQuotation => 'Paste as Quotation';

  @override
  String get menuPasteAndMatchStyle => 'Paste and Match Style';

  @override
  String get menuAppendSelectedMessages => 'Append Selected Messages';

  @override
  String get menuAddLinkDots => 'Add Link…';

  @override
  String get menuAttachments => 'Attachments';

  @override
  String get menuAlwaysSendWindowsFriendlyAttachments =>
      'Always Send Windows-Friendly Attachments';

  @override
  String get menuAlwaysInsertAttachmentsAtEndOfMessage =>
      'Always Insert Attachments at End of Message';

  @override
  String get menuIncludeAttachmentsWithReplies =>
      'Include Attachments With Replies';

  @override
  String get menuAlways => 'Always';

  @override
  String get menuNever => 'Never';

  @override
  String get menuWhenAddingRecipients => 'When Adding Recipients';

  @override
  String get menuAsk => 'Ask';

  @override
  String get menuFind => 'Find';

  @override
  String get menuMailboxSearch => 'Mailbox Search';

  @override
  String get menuFindDots => 'Find…';

  @override
  String get menuFindNext => 'Find Next';

  @override
  String get menuFindPrevious => 'Find Previous';

  @override
  String get menuUseSelectionForFind => 'Use Selection for Find';

  @override
  String get menuJumpToSelection => 'Jump to Selection';

  @override
  String get menuJumpToTop => 'Jump to Top';

  @override
  String get menuWritingTools => 'Writing Tools';

  @override
  String get menuShowWritingTools => 'Show Writing Tools';

  @override
  String get menuProofread => 'Proofread';

  @override
  String get menuRewrite => 'Rewrite';

  @override
  String get menuMakeFriendly => 'Make Friendly';

  @override
  String get menuMakeProfessional => 'Make Professional';

  @override
  String get menuMakeConcise => 'Make Concise';

  @override
  String get menuSummarize => 'Summarize';

  @override
  String get menuCreateKeyPoints => 'Create Key Points';

  @override
  String get menuMakeList => 'Make List';

  @override
  String get menuMakeTable => 'Make Table';

  @override
  String get menuComposeDots => 'Compose…';

  @override
  String get menuSpellingAndGrammar => 'Spelling and Grammar';

  @override
  String get menuShowSpellingAndGrammar => 'Show Spelling and Grammar';

  @override
  String get menuCheckDocumentNow => 'Check Document Now';

  @override
  String get menuCheckSpelling => 'Check Spelling';

  @override
  String get menuWhileTyping => 'While Typing';

  @override
  String get menuBeforeSending => 'Before Sending';

  @override
  String get menuCheckGrammarWithSpelling => 'Check Grammar with Spelling';

  @override
  String get menuCorrectSpellingAutomatically =>
      'Correct Spelling Automatically';

  @override
  String get menuSubstitutions => 'Substitutions';

  @override
  String get menuShowSubstitutions => 'Show Substitutions';

  @override
  String get menuSmartCopyPaste => 'Smart Copy/Paste';

  @override
  String get menuSmartQuotes => 'Smart Quotes';

  @override
  String get menuSmartLists => 'Smart Lists';

  @override
  String get menuSmartDashes => 'Smart Dashes';

  @override
  String get menuSmartLinks => 'Smart Links';

  @override
  String get menuTextReplacement => 'Text Replacement';

  @override
  String get menuTransformations => 'Transformations';

  @override
  String get menuMakeUpperCase => 'Make Upper Case';

  @override
  String get menuMakeLowerCase => 'Make Lower Case';

  @override
  String get menuCapitalize => 'Capitalize';

  @override
  String get menuSpeech => 'Speech';

  @override
  String get menuStartSpeaking => 'Start Speaking';

  @override
  String get menuStopSpeaking => 'Stop Speaking';

  @override
  String get menuAutoFill => 'AutoFill';

  @override
  String get menuContactDots => 'Contact…';

  @override
  String get menuPasswordsDots => 'Passwords…';

  @override
  String get menuCreditCardDots => 'Credit Card…';

  @override
  String get menuStartDictationDots => 'Start Dictation…';

  @override
  String get menuEmojiSymbols => 'Emoji & Symbols';

  @override
  String get menuShowTabBar => 'Show Tab Bar';

  @override
  String get menuShowAllTabs => 'Show All Tabs';

  @override
  String get menuFilter => 'Filter';

  @override
  String get menuEnableMessageFilter => 'Enable Message Filter';

  @override
  String get menuInclude => 'Include:';

  @override
  String get menuUnread => 'Unread';

  @override
  String get menuFlagged => 'Flagged';

  @override
  String get menuAddressed => 'Addressed:';

  @override
  String get menuToMe => 'To: Me';

  @override
  String get menuCcMe => 'Cc: Me';

  @override
  String get menuOnlyMailWithAttachments => 'Only Mail with Attachments';

  @override
  String get menuOnlyFromVIP => 'Only from VIP';

  @override
  String get menuSortBy => 'Sort By';

  @override
  String get menuDate => 'Date';

  @override
  String get menuDateSent => 'Date Sent';

  @override
  String get menuRemindMe => 'Remind Me';

  @override
  String get menuSendLater => 'Send Later';

  @override
  String get menuFlags => 'Flags';

  @override
  String get menuFrom => 'From';

  @override
  String get menuSize => 'Size';

  @override
  String get menuSubject => 'Subject';

  @override
  String get menuTo => 'To';

  @override
  String get menuSortUnread => 'Unread';

  @override
  String get menuOldestMessageOnTop => 'Oldest Message on Top';

  @override
  String get menuNewestMessageOnTop => 'Newest Message on Top';

  @override
  String get menuUseColumnLayout => 'Use Column Layout';

  @override
  String get menuShowBottomPreview => 'Show Bottom Preview';

  @override
  String get menuShowDateAndTime => 'Show Date and Time';

  @override
  String get menuShowToCcLabel => 'Show To/Cc Label';

  @override
  String get menuShowMessageSize => 'Show Message Size';

  @override
  String get menuShowContactPhoto => 'Show Contact Photo';

  @override
  String get menuShowMailCategories => 'Show Mail Categories';

  @override
  String get menuShowPriorityMessages => 'Show Priority Messages';

  @override
  String get menuAboutCategoriesDots => 'About Categories…';

  @override
  String get menuHighlightConversations => 'Highlight Conversations';

  @override
  String get menuOrganizeByConversation => 'Organize by Conversation';

  @override
  String get menuExpandAllConversations => 'Expand All Conversations';

  @override
  String get menuCollapseAllConversations => 'Collapse All Conversations';

  @override
  String get menuCcAddressField => 'Cc Address Field';

  @override
  String get menuBccAddressField => 'Bcc Address Field';

  @override
  String get menuReplyToAddressField => 'Reply-To Address Field';

  @override
  String get menuPriorityField => 'Priority Field';

  @override
  String get menuShowWithLightBackground => 'Show with Light Background';

  @override
  String get menuAllHeaders => 'All Headers';

  @override
  String get menuRawSource => 'Raw Source';

  @override
  String get menuHideRelatedMessages => 'Hide Related Messages';

  @override
  String get menuHideSidebar => 'Hide Sidebar';

  @override
  String get menuShowSidebar => 'Show Sidebar';

  @override
  String get menuHideToolbar => 'Hide Toolbar';

  @override
  String get menuCustomizeToolbarDots => 'Customize Toolbar…';

  @override
  String get menuShowFavoritesBar => 'Show Favorites Bar';

  @override
  String get menuGetNewMail => 'Get New Mail';

  @override
  String get menuMarkAllMessagesAsRead => 'Mark All Messages as Read';

  @override
  String get menuEraseDeletedItems => 'Erase Deleted Items';

  @override
  String get menuInAllAccountsDots => 'In All Accounts…';

  @override
  String get menuInAllAccounts => 'In All Accounts';

  @override
  String get menuEraseJunkMail => 'Erase Junk Mail';

  @override
  String get menuNewMailboxDots => 'New Mailbox…';

  @override
  String get menuAddFavoriteMailboxDots => 'Add Favorite Mailbox…';

  @override
  String get menuNewSmartMailboxDots => 'New Smart Mailbox…';

  @override
  String get menuEditSmartMailboxDots => 'Edit Smart Mailbox…';

  @override
  String get menuDuplicateSmartMailbox => 'Duplicate Smart Mailbox';

  @override
  String get menuNewSmartMailboxFolderDots => 'New Smart Mailbox Folder…';

  @override
  String get menuRenameMailboxDots => 'Rename Mailbox…';

  @override
  String get menuDeleteMailboxDots => 'Delete Mailbox…';

  @override
  String get menuExportMailboxDots => 'Export Mailbox…';

  @override
  String get menuGoToFavoriteMailbox => 'Go to Favorite Mailbox';

  @override
  String get menuMoveToFavoriteMailbox => 'Move to Favorite Mailbox';

  @override
  String get menuGoToPreviousMailbox => 'Go to Previous Mailbox';

  @override
  String get menuGoToNextMailbox => 'Go to Next Mailbox';

  @override
  String get menuRebuild => 'Rebuild';

  @override
  String get menuSendAgain => 'Send Again';

  @override
  String get menuSend => 'Send';

  @override
  String get menuSend2100Tonight => 'Send 21:00 Tonight';

  @override
  String get menuSend0800Tomorrow => 'Send 08:00 Tomorrow';

  @override
  String get menuSendLaterDots => 'Send Later…';

  @override
  String get menuForwardAsAttachment => 'Forward as Attachment';

  @override
  String get menuRedirect => 'Redirect';

  @override
  String get menuRemindMeIn1Hour => 'Remind Me in 1 Hour';

  @override
  String get menuRemindMeTonight => 'Remind Me Tonight';

  @override
  String get menuRemindMeTomorrow => 'Remind Me Tomorrow';

  @override
  String get menuRemindMeLaterDots => 'Remind Me Later…';

  @override
  String get menuClearReminder => 'Clear Reminder';

  @override
  String get menuIgnoreFollowUp => 'Ignore Follow Up';

  @override
  String get menuMarkAsUnread => 'Mark as Unread';

  @override
  String get menuMarkAsRead => 'Mark as Read';

  @override
  String get menuMoveToJunk => 'Move to Junk';

  @override
  String get menuMute => 'Mute';

  @override
  String get menuUnmute => 'Unmute';

  @override
  String get menuFlag => 'Flag';

  @override
  String get menuOrange => 'Orange';

  @override
  String get menuRed => 'Red';

  @override
  String get menuPurple => 'Purple';

  @override
  String get menuBlue => 'Blue';

  @override
  String get menuYellow => 'Yellow';

  @override
  String get menuGreen => 'Green';

  @override
  String get menuGray => 'Gray';

  @override
  String get menuClearFlag => 'Clear Flag';

  @override
  String get menuToggleFlag => 'Toggle Flag';

  @override
  String get menuSetPriority => 'Set Priority';

  @override
  String get menuLow => 'Low';

  @override
  String get menuNormal => 'Normal';

  @override
  String get menuHigh => 'High';

  @override
  String get menuMoveToPredictedMailbox => 'Move to Predicted Mailbox';

  @override
  String get menuMoveTo => 'Move to';

  @override
  String get menuCopyTo => 'Copy to';

  @override
  String get menuMoveAgain => 'Move Again';

  @override
  String get menuApplyRules => 'Apply Rules';

  @override
  String get menuAddSenderToContacts => 'Add Sender to Contacts';

  @override
  String get menuCategorizeSender => 'Categorize Sender';

  @override
  String get menuAutomatically => 'Automatically';

  @override
  String get menuAlwaysCategorizeAs => 'Always Categorize as';

  @override
  String get menuPrimary => 'Primary';

  @override
  String get menuTransactions => 'Transactions';

  @override
  String get menuUpdates => 'Updates';

  @override
  String get menuPromotions => 'Promotions';

  @override
  String get menuRemoveAttachments => 'Remove Attachments';

  @override
  String get menuShowFonts => 'Show Fonts';

  @override
  String get menuShowColors => 'Show Colors';

  @override
  String get menuLists => 'Lists';

  @override
  String get menuInsertBulletedList => 'Insert Bulleted List';

  @override
  String get menuInsertNumberedList => 'Insert Numbered List';

  @override
  String get menuRemoveListFormatting => 'Remove List Formatting';

  @override
  String get menuIncreaseListLevel => 'Increase List Level';

  @override
  String get menuDecreaseListLevel => 'Decrease List Level';

  @override
  String get menuConvertToNumberedList => 'Convert to Numbered List';

  @override
  String get menuStyle => 'Style';

  @override
  String get menuBold => 'Bold';

  @override
  String get menuItalic => 'Italic';

  @override
  String get menuUnderline => 'Underline';

  @override
  String get menuOutline => 'Outline';

  @override
  String get menuBigger => 'Bigger';

  @override
  String get menuSmaller => 'Smaller';

  @override
  String get menuCopyStyle => 'Copy Style';

  @override
  String get menuPasteStyle => 'Paste Style';

  @override
  String get menuRemoveStyle => 'Remove Style';

  @override
  String get menuStylesDots => 'Styles…';

  @override
  String get menuAlignment => 'Alignment';

  @override
  String get menuAlignLeft => 'Align Left';

  @override
  String get menuCenter => 'Center';

  @override
  String get menuJustify => 'Justify';

  @override
  String get menuAlignRight => 'Align Right';

  @override
  String get menuFloatLeft => 'Float Left';

  @override
  String get menuFloatRight => 'Float Right';

  @override
  String get menuRemoveFloat => 'Remove Float';

  @override
  String get menuWritingDirection => 'Writing Direction';

  @override
  String get menuParagraph => 'Paragraph';

  @override
  String get menuSelection => 'Selection';

  @override
  String get menuDefault => 'Default';

  @override
  String get menuLeftToRight => 'Left to Right';

  @override
  String get menuRightToLeft => 'Right to Left';

  @override
  String get menuIndentation => 'Indentation';

  @override
  String get menuIncrease => 'Increase';

  @override
  String get menuDecrease => 'Decrease';

  @override
  String get menuQuoteLevel => 'Quote Level';

  @override
  String get menuMakeRichText => 'Make Rich Text';

  @override
  String get menuMakePlainText => 'Make Plain Text';

  @override
  String get menuMessageViewer => 'Message Viewer';

  @override
  String get menuPhotoBrowser => 'Photo Browser';

  @override
  String get menuPreviousRecipients => 'Previous Recipients';

  @override
  String get menuActivity => 'Activity';

  @override
  String get menuConnectionDoctor => 'Connection Doctor';

  @override
  String get menuMailHelp => 'Mail Help';

  @override
  String get menuWhatsNewInMail => 'What’s New in Mail?';

  @override
  String menuSynchronize(String account) {
    return 'Synchronize “$account”';
  }

  @override
  String menuCategorizeAll(String sender) {
    return 'Categorize all messages from “$sender”';
  }
}
