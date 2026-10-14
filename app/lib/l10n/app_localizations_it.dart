// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Posta';

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
}
