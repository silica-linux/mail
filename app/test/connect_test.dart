import 'package:flutter_test/flutter_test.dart';
import 'package:silica_mail/main.dart';
import 'package:silica_mail/src/model.dart';
import 'package:silica_mail/src/service.dart';

void main() {
  test('sample mail only with MAIL_SAMPLE_DATA=1', () async {
    final c = await connect(const {'MAIL_SAMPLE_DATA': '1'});
    expect(c.sample, isTrue);
    expect(c.error, isNull);
    expect(c.service, isA<FakeMailService>());
  });

  test(
    'an engine that does not start gives its error, not sample mail',
    () async {
      final engine = FakeMailService(
        sample: false,
        unavailable: 'ServiceUnknown',
      );
      final c = await connect(const {}, engine: engine);
      expect(c.sample, isFalse);
      expect(c.error, 'ServiceUnknown');
      expect(c.service, same(engine));
    },
  );

  test('a running engine is used as it is', () async {
    final engine = FakeMailService(sample: false);
    final c = await connect(const {}, engine: engine);
    expect(c.error, isNull);
    expect(c.sample, isFalse);
    expect(c.service, same(engine));
  });

  group('AccountConfig', () {
    test('keeps the security of each server both ways', () {
      final config = AccountConfig.fromJson({
        'address': 'a@example.org',
        'imap': {'host': 'imap.example.org', 'port': 143, 'tls': 'starttls'},
        'smtp': {'host': 'smtp.example.org', 'port': 465, 'tls': 'tls'},
        'username': 'a',
      });
      expect(config.imapTls, MailTls.starttls);
      expect(config.smtpTls, MailTls.tls);
      final json = config.copyWith(password: 'p').toJson();
      expect(json['imap'], {
        'host': 'imap.example.org',
        'port': 143,
        'tls': 'starttls',
      });
      expect(json['smtp'], {
        'host': 'smtp.example.org',
        'port': 465,
        'tls': 'tls',
      });
    });

    test('without a security it follows the port', () {
      final config = AccountConfig.fromJson({
        'address': 'a@example.org',
        'imap': {'host': 'imap.example.org', 'port': 143},
        'smtp': {'host': 'smtp.example.org', 'port': 587},
      });
      expect(config.imapTls, MailTls.starttls);
      expect(config.smtpTls, MailTls.starttls);
      expect(MailTls.forPort(993), MailTls.tls);
    });

    test('knows the providers that sign in their own way', () {
      AccountConfig on(String host) =>
          AccountConfig(address: 'a@b.c', imapHost: host);
      expect(on('imap.gmail.com').provider, SignInProvider.google);
      expect(on('outlook.office365.com').provider, SignInProvider.microsoft);
      expect(on('imap-mail.outlook.com').provider, SignInProvider.microsoft);
      expect(on('imap.fastmail.com').provider, SignInProvider.password);
    });
  });
}
