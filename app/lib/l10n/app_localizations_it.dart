// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Mail';

  @override
  String get mailboxInbox => 'In arrivo';

  @override
  String get mailboxDrafts => 'Bozze';

  @override
  String get mailboxSent => 'Inviati';

  @override
  String get mailboxArchive => 'Archivio';

  @override
  String get mailboxJunk => 'Indesiderata';

  @override
  String get mailboxTrash => 'Cestino';

  @override
  String get newMessage => 'Nuovo messaggio';

  @override
  String get reply => 'Rispondi';

  @override
  String get replyAll => 'Rispondi a tutti';

  @override
  String get forward => 'Inoltra';

  @override
  String get delete => 'Elimina';

  @override
  String get archive => 'Archivia';

  @override
  String get flag => 'Contrassegna';

  @override
  String get markRead => 'Segna come già letto';

  @override
  String get markUnread => 'Segna come da leggere';

  @override
  String get search => 'Cerca';

  @override
  String messageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi',
      one: '1 messaggio',
      zero: 'Nessun messaggio',
    );
    return '$_temp0';
  }

  @override
  String unreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count da leggere',
      one: '1 da leggere',
    );
    return '$_temp0';
  }

  @override
  String get noMessages => 'Nessun messaggio';

  @override
  String get noResults => 'Nessun risultato';

  @override
  String get noSelection => 'Nessun messaggio scelto';

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get monthsShort => 'gen,feb,mar,apr,mag,giu,lug,ago,set,ott,nov,dic';

  @override
  String dateShort(String day, String month, String year) {
    return '$day $month $year';
  }

  @override
  String dateTime(String date, String time) {
    return '$date alle $time';
  }

  @override
  String get from => 'Da';

  @override
  String get to => 'A';

  @override
  String get cc => 'Cc';

  @override
  String get subject => 'Oggetto';

  @override
  String get send => 'Invia';

  @override
  String get cancel => 'Annulla';

  @override
  String get attachments => 'Allegati';

  @override
  String attachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count allegati',
      one: '1 allegato',
    );
    return '$_temp0';
  }

  @override
  String get remoteContentBlocked =>
      'Immagini e altri contenuti dalla rete non sono stati caricati, per proteggere la tua privacy.';

  @override
  String get loadRemoteContent => 'Carica i contenuti';

  @override
  String get replyPrefix => 'R: ';

  @override
  String get forwardPrefix => 'I: ';

  @override
  String quoteHeader(String date, String name) {
    return 'Il giorno $date, $name ha scritto:';
  }

  @override
  String get forwardHeader => 'Messaggio inoltrato';

  @override
  String sendFailed(String error) {
    return 'Non è stato possibile inviare il messaggio: $error';
  }

  @override
  String get noRecipients => 'Aggiungi almeno un destinatario.';

  @override
  String get addAccount => 'Aggiungi un account';

  @override
  String get noAccounts => 'Ancora nessun account';

  @override
  String get noAccountsHint =>
      'Aggiungi un account di posta per leggere e inviare messaggi.';

  @override
  String get emailAddress => 'Indirizzo email';

  @override
  String get yourName => 'Il tuo nome';

  @override
  String get password => 'Password';

  @override
  String get continueButton => 'Continua';

  @override
  String get signIn => 'Accedi';

  @override
  String get lookingForSettings => 'Cerco le impostazioni di questo indirizzo…';

  @override
  String get incomingServer => 'Server in entrata';

  @override
  String get outgoingServer => 'Server in uscita';

  @override
  String get passwordNote => 'La password resta nel portachiavi di sistema.';

  @override
  String setupFailed(String error) {
    return 'Non è stato possibile aggiungere l\'account: $error';
  }

  @override
  String get sampleData =>
      'Posta di esempio per lo sviluppo (MAIL_SAMPLE_DATA): nessun account reale.';

  @override
  String get engineUnavailable =>
      'Mail non riesce a raggiungere il servizio di posta';

  @override
  String get engineUnavailableHint =>
      'Il servizio che scarica e invia la posta non si è avviato. Controlla che Mail sia installato completamente, poi riprova.';

  @override
  String get tryAgain => 'Riprova';

  @override
  String get engineStarting => 'Avvio…';

  @override
  String settingsNotFound(String error) {
    return 'Le impostazioni di questo indirizzo non sono state trovate ($error). Inserisci i server qui sotto.';
  }

  @override
  String get serverSettingsInvalid =>
      'Inserisci entrambi i server e le loro porte (1–65535).';

  @override
  String get port => 'Porta';

  @override
  String get userName => 'Nome utente';

  @override
  String get editServerSettings => 'Modifica impostazioni server…';

  @override
  String get googleAppPassword =>
      'L\'accesso con la pagina dell\'account Google non è ancora supportato. Usa una password per le app, creata nelle impostazioni di sicurezza del tuo account Google (serve la verifica in due passaggi).';

  @override
  String get microsoftNotSupported =>
      'Gli account Microsoft accedono solo tramite la pagina di Microsoft, che Mail non supporta ancora.';

  @override
  String syncFailed(String account, String error) {
    return 'Non è stato possibile sincronizzare $account: $error';
  }

  @override
  String sizeBytes(int count) {
    return '$count byte';
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
  String get decimalSeparator => ',';

  @override
  String get searching => 'Ricerca';

  @override
  String searchScope(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risultati',
      one: '1 risultato',
      zero: 'nessun risultato',
    );
    return 'Tutte le caselle, $_temp0';
  }

  @override
  String messageCountUnread(int count, int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messaggi',
      one: '1 messaggio',
    );
    return '$_temp0, $unread da leggere';
  }

  @override
  String get senderContains => 'Il mittente contiene:';

  @override
  String get subjectContains => 'L\'oggetto contiene:';

  @override
  String get tokenSender => 'Mittente';

  @override
  String get tokenSubject => 'Oggetto';

  @override
  String twoSenders(String first, String second) {
    return '$first e $second';
  }

  @override
  String get dayBeforeYesterday => 'L\'altro ieri';

  @override
  String dateNumeric(String day, String month, String year) {
    return '$day/$month/$year';
  }

  @override
  String get sidebar => 'Barra laterale';

  @override
  String get junk => 'Indesiderata';

  @override
  String get help => 'Aiuto';

  @override
  String get addressPlaceholder => 'nome@example.com';

  @override
  String get filter => 'Filtra';

  @override
  String get more => 'Altro';

  @override
  String get showAllMessages => 'Tutti i messaggi';

  @override
  String get showUnread => 'Non letti';

  @override
  String get showFlagged => 'Contrassegnati';

  @override
  String get bestMatches => 'Corrispondenze migliori';

  @override
  String get allResults => 'Tutti i risultati';

  @override
  String get allMailboxes => 'Tutte le caselle';

  @override
  String get searchSection => 'Ricerca';

  @override
  String get saveDraftTitle => 'Salvare questo messaggio come bozza?';

  @override
  String get saveDraftMessage =>
      'Il messaggio ha modifiche non salvate. Puoi tenerlo come bozza o scartarlo.';

  @override
  String get save => 'Salva';

  @override
  String get dontSave => 'Non salvare';

  @override
  String get addAccountHint =>
      'Inserisci il tuo indirizzo email e Mail troverà le impostazioni.';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Modifica';

  @override
  String get menuView => 'Vista';

  @override
  String get menuMailbox => 'Casella';

  @override
  String get menuMessage => 'Messaggio';

  @override
  String get menuFormat => 'Formato';

  @override
  String get menuWindow => 'Finestra';

  @override
  String get menuHelp => 'Aiuto';

  @override
  String get menuAboutMail => 'Informazioni su Mail';

  @override
  String get menuSettingsDots => 'Impostazioni…';

  @override
  String get menuAccountsDots => 'Account…';

  @override
  String get menuAddAccountDots => 'Aggiungi account…';

  @override
  String get menuNewViewerWindow => 'Nuova finestra';

  @override
  String get menuOpenMessage => 'Apri messaggio';

  @override
  String get menuOpenMessages => 'Apri messaggi';

  @override
  String get menuClose => 'Chiudi';

  @override
  String get menuSave => 'Salva';

  @override
  String get menuSaveAsDots => 'Salva col nome…';

  @override
  String get menuAttachFilesDots => 'Allega file…';

  @override
  String get menuSaveAttachmentsDots => 'Salva allegati…';

  @override
  String get menuQuickLookAttachmentsDots =>
      'Visualizzazione rapida degli allegati…';

  @override
  String get menuImportMailboxesDots => 'Importa caselle…';

  @override
  String get menuExportAsPDFDots => 'Esporta come PDF…';

  @override
  String get menuPrintDots => 'Stampa…';

  @override
  String get menuComplete => 'Completa';

  @override
  String get menuPasteAsQuotation => 'Incolla come citazione';

  @override
  String get menuPasteAndMatchStyle => 'Incolla e adegua lo stile';

  @override
  String get menuAppendSelectedMessages => 'Aggiungi i messaggi selezionati';

  @override
  String get menuAddLinkDots => 'Aggiungi link…';

  @override
  String get menuAttachments => 'Allegati';

  @override
  String get menuAlwaysSendWindowsFriendlyAttachments =>
      'Invia sempre allegati compatibili con Windows';

  @override
  String get menuAlwaysInsertAttachmentsAtEndOfMessage =>
      'Inserisci allegati sempre alla fine del messaggio';

  @override
  String get menuIncludeAttachmentsWithReplies =>
      'Includi gli allegati nelle risposte';

  @override
  String get menuAlways => 'Sempre';

  @override
  String get menuNever => 'Mai';

  @override
  String get menuWhenAddingRecipients => 'Quando aggiungi destinatari';

  @override
  String get menuAsk => 'Chiedi';

  @override
  String get menuFind => 'Trova';

  @override
  String get menuMailboxSearch => 'Cerca casella';

  @override
  String get menuFindDots => 'Trova…';

  @override
  String get menuFindNext => 'Trova successivo';

  @override
  String get menuFindPrevious => 'Trova precedente';

  @override
  String get menuUseSelectionForFind => 'Usa selezione per trovare';

  @override
  String get menuJumpToSelection => 'Vai alla selezione';

  @override
  String get menuJumpToTop => 'Vai all’inizio';

  @override
  String get menuWritingTools => 'Strumenti di scrittura';

  @override
  String get menuShowWritingTools => 'Mostra gli strumenti di scrittura';

  @override
  String get menuProofread => 'Correggi';

  @override
  String get menuRewrite => 'Riscrivi';

  @override
  String get menuMakeFriendly => 'Stile amichevole';

  @override
  String get menuMakeProfessional => 'Stile professionale';

  @override
  String get menuMakeConcise => 'Stile conciso';

  @override
  String get menuSummarize => 'Riassumi';

  @override
  String get menuCreateKeyPoints => 'Crea punti chiave';

  @override
  String get menuMakeList => 'Trasforma in elenco';

  @override
  String get menuMakeTable => 'Trasforma in tabella';

  @override
  String get menuComposeDots => 'Scrivi…';

  @override
  String get menuSpellingAndGrammar => 'Ortografia e grammatica';

  @override
  String get menuShowSpellingAndGrammar => 'Mostra ortografia e grammatica';

  @override
  String get menuCheckDocumentNow => 'Controlla il documento adesso';

  @override
  String get menuCheckSpelling => 'Controlla ortografia';

  @override
  String get menuWhileTyping => 'Durante la digitazione';

  @override
  String get menuBeforeSending => 'Prima dell’invio';

  @override
  String get menuCheckGrammarWithSpelling =>
      'Controlla grammatica e ortografia';

  @override
  String get menuCorrectSpellingAutomatically =>
      'Correggi automaticamente ortografia';

  @override
  String get menuSubstitutions => 'Sostituzioni';

  @override
  String get menuShowSubstitutions => 'Mostra sostituzioni';

  @override
  String get menuSmartCopyPaste => 'Copia/incolla smart';

  @override
  String get menuSmartQuotes => 'Virgolette smart';

  @override
  String get menuSmartLists => 'Elenchi smart';

  @override
  String get menuSmartDashes => 'Trattini smart';

  @override
  String get menuSmartLinks => 'Link smart';

  @override
  String get menuTextReplacement => 'Sostituzione testo';

  @override
  String get menuTransformations => 'Trasformazioni';

  @override
  String get menuMakeUpperCase => 'Scrivi in lettere maiuscole';

  @override
  String get menuMakeLowerCase => 'Scrivi in lettere minuscole';

  @override
  String get menuCapitalize => 'Iniziali maiuscole';

  @override
  String get menuSpeech => 'Voce';

  @override
  String get menuStartSpeaking => 'Inizia riproduzione';

  @override
  String get menuStopSpeaking => 'Interrompi riproduzione';

  @override
  String get menuAutoFill => 'Inserimento automatico';

  @override
  String get menuContactDots => 'Contatti…';

  @override
  String get menuPasswordsDots => 'Password…';

  @override
  String get menuCreditCardDots => 'Carta di credito…';

  @override
  String get menuStartDictationDots => 'Avvia dettatura…';

  @override
  String get menuEmojiSymbols => 'Emoji e simboli';

  @override
  String get menuShowTabBar => 'Mostra la barra dei pannelli';

  @override
  String get menuShowAllTabs => 'Mostra tutti i pannelli';

  @override
  String get menuFilter => 'Filtra';

  @override
  String get menuEnableMessageFilter => 'Abilita filtro messaggi';

  @override
  String get menuInclude => 'Includi:';

  @override
  String get menuUnread => 'Non letti';

  @override
  String get menuFlagged => 'Contrassegnati';

  @override
  String get menuAddressed => 'Inviate:';

  @override
  String get menuToMe => 'A: me';

  @override
  String get menuCcMe => 'Cc: me';

  @override
  String get menuOnlyMailWithAttachments => 'Solo email con allegati';

  @override
  String get menuOnlyFromVIP => 'Solo da VIP';

  @override
  String get menuSortBy => 'Ordina per';

  @override
  String get menuDate => 'Data';

  @override
  String get menuDateSent => 'Data invio';

  @override
  String get menuRemindMe => 'Ricordamelo';

  @override
  String get menuSendLater => 'Invia più tardi';

  @override
  String get menuFlags => 'Contrassegni';

  @override
  String get menuFrom => 'Da';

  @override
  String get menuSize => 'Dimensione';

  @override
  String get menuSubject => 'Oggetto';

  @override
  String get menuTo => 'A';

  @override
  String get menuSortUnread => 'Non letto';

  @override
  String get menuOldestMessageOnTop => 'Messaggio meno recente in alto';

  @override
  String get menuNewestMessageOnTop => 'Messaggio più recente in alto';

  @override
  String get menuUseColumnLayout => 'Utilizza layout colonne';

  @override
  String get menuShowBottomPreview => 'Mostra anteprima inferiore';

  @override
  String get menuShowDateAndTime => 'Mostra data e ora';

  @override
  String get menuShowToCcLabel => 'Mostra etichetta A/Cc';

  @override
  String get menuShowMessageSize => 'Mostra dimensioni messaggio';

  @override
  String get menuShowContactPhoto => 'Mostra foto contatto';

  @override
  String get menuShowMailCategories => 'Mostra categorie di Mail';

  @override
  String get menuShowPriorityMessages => 'Mostra i messaggi con priorità';

  @override
  String get menuAboutCategoriesDots => 'Informazioni sulle categorie…';

  @override
  String get menuHighlightConversations => 'Evidenzia conversazioni';

  @override
  String get menuOrganizeByConversation => 'Organizza per conversazione';

  @override
  String get menuExpandAllConversations => 'Espandi tutte le conversazioni';

  @override
  String get menuCollapseAllConversations => 'Contrai tutte le conversazioni';

  @override
  String get menuCcAddressField => 'Campo indirizzo Cc';

  @override
  String get menuBccAddressField => 'Campo indirizzo Ccn';

  @override
  String get menuReplyToAddressField => 'Campo indirizzo Rispondi a';

  @override
  String get menuPriorityField => 'Campo priorità';

  @override
  String get menuShowWithLightBackground => 'Mostra con sfondo chiaro';

  @override
  String get menuAllHeaders => 'Tutte le intestazioni';

  @override
  String get menuRawSource => 'Formato sorgente';

  @override
  String get menuHideRelatedMessages => 'Nascondi messaggi correlati';

  @override
  String get menuHideSidebar => 'Nascondi barra laterale';

  @override
  String get menuShowSidebar => 'Mostra barra laterale';

  @override
  String get menuHideToolbar => 'Nascondi la barra strumenti';

  @override
  String get menuCustomizeToolbarDots => 'Personalizza la barra strumenti…';

  @override
  String get menuShowFavoritesBar => 'Mostra la barra dei preferiti';

  @override
  String get menuGetNewMail => 'Ricevi nuovi messaggi';

  @override
  String get menuMarkAllMessagesAsRead => 'Segna tutti i messaggi come letti';

  @override
  String get menuEraseDeletedItems => 'Cancella elementi eliminati';

  @override
  String get menuInAllAccountsDots => 'In tutti gli account…';

  @override
  String get menuInAllAccounts => 'In tutti gli account';

  @override
  String get menuEraseJunkMail => 'Cancella posta indesiderata';

  @override
  String get menuNewMailboxDots => 'Nuova casella…';

  @override
  String get menuAddFavoriteMailboxDots => 'Aggiungi casella preferita…';

  @override
  String get menuNewSmartMailboxDots => 'Nuova casella smart…';

  @override
  String get menuEditSmartMailboxDots => 'Modifica casella smart…';

  @override
  String get menuDuplicateSmartMailbox => 'Duplica casella smart';

  @override
  String get menuNewSmartMailboxFolderDots => 'Nuova cartella casella smart…';

  @override
  String get menuRenameMailboxDots => 'Rinomina casella…';

  @override
  String get menuDeleteMailboxDots => 'Elimina casella…';

  @override
  String get menuExportMailboxDots => 'Esporta casella di posta…';

  @override
  String get menuGoToFavoriteMailbox => 'Vai alla casella preferita';

  @override
  String get menuMoveToFavoriteMailbox => 'Sposta nella casella preferita';

  @override
  String get menuGoToPreviousMailbox => 'Vai alla casella precedente';

  @override
  String get menuGoToNextMailbox => 'Vai alla casella successiva';

  @override
  String get menuRebuild => 'Ricostruisci';

  @override
  String get menuSendAgain => 'Invia di nuovo';

  @override
  String get menuSend => 'Invia';

  @override
  String get menuSend2100Tonight => 'Invia stasera alle 21:00';

  @override
  String get menuSend0800Tomorrow => 'Invia domani alle 08:00';

  @override
  String get menuSendLaterDots => 'Invia più tardi…';

  @override
  String get menuForwardAsAttachment => 'Inoltra come allegato';

  @override
  String get menuRedirect => 'Reindirizza';

  @override
  String get menuRemindMeIn1Hour => 'Ricordamelo tra un’ora';

  @override
  String get menuRemindMeTonight => 'Ricordamelo stasera';

  @override
  String get menuRemindMeTomorrow => 'Ricordamelo domani';

  @override
  String get menuRemindMeLaterDots => 'Ricordamelo più tardi…';

  @override
  String get menuClearReminder => 'Cancella promemoria';

  @override
  String get menuIgnoreFollowUp => 'Ignora “Da ricontattare”';

  @override
  String get menuMarkAsUnread => 'Segna come non letto';

  @override
  String get menuMarkAsRead => 'Segna come letto';

  @override
  String get menuMoveToJunk => 'Sposta in Indesiderati';

  @override
  String get menuMute => 'Disattiva notifiche';

  @override
  String get menuUnmute => 'Attiva notifiche';

  @override
  String get menuFlag => 'Contrassegno';

  @override
  String get menuOrange => 'Arancio';

  @override
  String get menuRed => 'Rosso';

  @override
  String get menuPurple => 'Viola';

  @override
  String get menuBlue => 'Blu';

  @override
  String get menuYellow => 'Giallo';

  @override
  String get menuGreen => 'Verde';

  @override
  String get menuGray => 'Grigio';

  @override
  String get menuClearFlag => 'Elimina contrassegno';

  @override
  String get menuToggleFlag => 'Attiva/disattiva contrassegno';

  @override
  String get menuSetPriority => 'Imposta priorità';

  @override
  String get menuLow => 'Bassa';

  @override
  String get menuNormal => 'Normale';

  @override
  String get menuHigh => 'Alta';

  @override
  String get menuMoveToPredictedMailbox => 'Sposta nella casella suggerita';

  @override
  String get menuMoveTo => 'Sposta in';

  @override
  String get menuCopyTo => 'Copia in';

  @override
  String get menuMoveAgain => 'Sposta di nuovo';

  @override
  String get menuApplyRules => 'Applica regole';

  @override
  String get menuAddSenderToContacts => 'Aggiungi mittente a Contatti';

  @override
  String get menuCategorizeSender => 'Categorizza mittente';

  @override
  String get menuAutomatically => 'Automaticamente';

  @override
  String get menuAlwaysCategorizeAs => 'Categorizza sempre in';

  @override
  String get menuPrimary => 'Principale';

  @override
  String get menuTransactions => 'Transazioni';

  @override
  String get menuUpdates => 'Aggiornamenti';

  @override
  String get menuPromotions => 'Promozioni';

  @override
  String get menuRemoveAttachments => 'Rimuovi allegati';

  @override
  String get menuShowFonts => 'Mostra font';

  @override
  String get menuShowColors => 'Mostra colori';

  @override
  String get menuLists => 'Elenchi';

  @override
  String get menuInsertBulletedList => 'Inserisci elenco puntato';

  @override
  String get menuInsertNumberedList => 'Inserisci elenco numerato';

  @override
  String get menuRemoveListFormatting => 'Rimuovi formattazione elenco';

  @override
  String get menuIncreaseListLevel => 'Aumenta livello elenco';

  @override
  String get menuDecreaseListLevel => 'Diminuisci livello elenco';

  @override
  String get menuConvertToNumberedList => 'Converti a elenco numerato';

  @override
  String get menuStyle => 'Stile';

  @override
  String get menuBold => 'Grassetto';

  @override
  String get menuItalic => 'Corsivo';

  @override
  String get menuUnderline => 'Sottolineato';

  @override
  String get menuOutline => 'Bordato';

  @override
  String get menuBigger => 'Più grande';

  @override
  String get menuSmaller => 'Più piccolo';

  @override
  String get menuCopyStyle => 'Copia stile';

  @override
  String get menuPasteStyle => 'Incolla stile';

  @override
  String get menuRemoveStyle => 'Rimuovi stile';

  @override
  String get menuStylesDots => 'Stili…';

  @override
  String get menuAlignment => 'Allineamento';

  @override
  String get menuAlignLeft => 'Allinea a sinistra';

  @override
  String get menuCenter => 'Centra';

  @override
  String get menuJustify => 'Giustifica';

  @override
  String get menuAlignRight => 'Allinea a destra';

  @override
  String get menuFloatLeft => 'Fluttuazione a sinistra';

  @override
  String get menuFloatRight => 'Fluttuazione a destra';

  @override
  String get menuRemoveFloat => 'Rimuovi fluttuazione';

  @override
  String get menuWritingDirection => 'Direzione scrittura';

  @override
  String get menuParagraph => 'Paragrafo';

  @override
  String get menuSelection => 'Selezione';

  @override
  String get menuDefault => 'Predefinita';

  @override
  String get menuLeftToRight => 'Da sinistra a destra';

  @override
  String get menuRightToLeft => 'Da destra a sinistra';

  @override
  String get menuIndentation => 'Rientro';

  @override
  String get menuIncrease => 'Aumenta';

  @override
  String get menuDecrease => 'Riduci';

  @override
  String get menuQuoteLevel => 'Livello citazione';

  @override
  String get menuMakeRichText => 'Testo formattato';

  @override
  String get menuMakePlainText => 'Converti in formato solo testo';

  @override
  String get menuMessageViewer => 'Finestra messaggi';

  @override
  String get menuPhotoBrowser => 'Browser foto';

  @override
  String get menuPreviousRecipients => 'Destinatari precedenti';

  @override
  String get menuActivity => 'Attività';

  @override
  String get menuConnectionDoctor => 'Stato connessione';

  @override
  String get menuMailHelp => 'Aiuto di Mail';

  @override
  String get menuWhatsNewInMail => 'Novità di Mail';

  @override
  String menuSynchronize(String account) {
    return 'Sincronizza “$account”';
  }

  @override
  String menuCategorizeAll(String sender) {
    return 'Categorizza tutti i messaggi di “$sender”';
  }
}
