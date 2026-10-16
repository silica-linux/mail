// The Mail window: the sidebar with the accounts and their mailboxes, the message list grouped
// by conversation, the reader, and the unified toolbar (silica_ui). Every action goes through
// [MailService]; the window keeps only what it shows.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import 'compose.dart';
import 'html.dart';
import 'l10n.dart';
import 'menus.dart';
import 'model.dart';
import 'service.dart';
import 'setup.dart';
import 'style.dart';

/// What the composer starts from.
enum ComposeKind { fresh, reply, replyAll, forward }

/// What a search looks in: everything, or one field (a token before the text).
enum SearchScope { all, sender, subject }

/// Which messages the list shows (the filter button of the list's toolbar).
enum MailFilter { all, unread, flagged }

/// The rows of a search that match `text` in the field of `scope` (all: the engine's match).
List<MessageSummary> filterByScope(
  List<MessageSummary> rows,
  String text,
  SearchScope scope,
) {
  final needle = text.toLowerCase();
  return switch (scope) {
    SearchScope.all => rows,
    SearchScope.sender =>
      rows
          .where(
            (r) =>
                r.from.display.toLowerCase().contains(needle) ||
                r.from.address.toLowerCase().contains(needle),
          )
          .toList(),
    SearchScope.subject =>
      rows.where((r) => r.subject.toLowerCase().contains(needle)).toList(),
  };
}

class MailWindow extends StatefulWidget {
  const MailWindow({
    super.key,
    required this.service,
    this.now,
    this.engineError,
    this.sampleData = false,
    this.openUrl,
    this.lastMailbox,
  });

  final MailService service;

  /// The current time (tests); null: the clock.
  final DateTime Function()? now;

  /// Why the engine could not start, at launch: the window says so and offers to try again.
  final String? engineError;

  /// The service is the generated sample mail (`MAIL_SAMPLE_DATA=1`): the window says so.
  final bool sampleData;

  /// Opens a link with the system (tests replace it); null: `xdg-open`.
  final ValueChanged<String>? openUrl;

  /// The mailbox shown last, kept by the app across windows: a new window after the last
  /// one closed opens on it (APP-LC: the main window comes back on the same mailbox).
  final ValueNotifier<String?>? lastMailbox;

  @override
  State<MailWindow> createState() => MailWindowState();
}

class MailWindowState extends State<MailWindow> {
  final FocusNode _focus = FocusNode(debugLabel: 'mail window');
  final TextEditingController _query = TextEditingController();
  final FocusNode _queryFocus = FocusNode(debugLabel: 'search');

  /// The composer's handle for the menu bar (Send, Close).
  final ComposeController _composer = ComposeController();
  StreamSubscription<MailEvent>? _events;
  late final AppLifecycleListener _lifecycle;

  List<Account> _accounts = const [];
  final Map<String, List<Mailbox>> _mailboxes = {};
  Mailbox? _mailbox;
  List<MessageSummary> _rows = const [];
  String? _selected;
  List<Message> _conversation = const [];
  final Set<String> _remoteAllowed = {};
  String? _searchText;
  SearchScope _scope = SearchScope.all;
  bool _searching = false;

  /// The search suggestions under the field (while typing, before choosing).
  bool _suggesting = false;

  /// Expanded threads (by thread key).
  final Set<String> _expanded = {};
  bool _sidebarShown = true;
  MailFilter _filter = MailFilter.all;
  bool _active = true;

  bool _loading = true;
  String? _banner;
  ComposeRequest? _compose;
  bool _setup = false;

  /// Why the engine can't be reached (null: it answers).
  String? _engineError;

  /// The first list of accounts has arrived (an empty one opens the setup by itself).
  bool _accountsSeen = false;
  bool _retrying = false;

  bool get _hasBanner => widget.sampleData || _banner != null;

  MailService get _service => widget.service;
  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) {
        final active = s == AppLifecycleState.resumed;
        if (active != _active) setState(() => _active = active);
      },
    );
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    _events = _service.events.listen(_onEvent);
    _composer.addListener(_menusChanged);
    _engineError = widget.engineError;
    if (_engineError == null) {
      _loadAccounts();
    } else {
      _loading = false;
    }
  }

  /// Starts the engine again (D-Bus activation) and, if it answers, loads the accounts.
  Future<void> retryEngine() async {
    setState(() => _retrying = true);
    try {
      await _service.start();
      await _service.listAccounts();
      if (!mounted) return;
      setState(() {
        _engineError = null;
        _retrying = false;
        _loading = true;
      });
      await _loadAccounts();
    } on MailError catch (e) {
      if (mounted) {
        setState(() {
          _engineError = e.message;
          _retrying = false;
        });
      }
    }
  }

  /// Marks the selection read after the measured delay (ML-01b).
  Timer? _markRead;

  @override
  void dispose() {
    _composer.dispose();
    _markRead?.cancel();
    _events?.cancel();
    _lifecycle.dispose();
    _focus.dispose();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on MailError catch (e) {
      if (mounted) setState(() => _banner = e.message);
    }
  }

  Future<void> _loadAccounts() => _guard(() async {
    final accounts = await _service.listAccounts();
    final boxes = <String, List<Mailbox>>{};
    for (final a in accounts) {
      boxes[a.id] = await _service.listMailboxes(a.id);
    }
    if (!mounted) return;
    setState(() {
      // First run: no account yet, so the setup opens by itself (as the reference does).
      if (!_accountsSeen && accounts.isEmpty && !widget.sampleData) {
        _setup = true;
      }
      _accountsSeen = true;
      _accounts = accounts;
      _mailboxes
        ..clear()
        ..addAll(boxes);
      _loading = false;
      final current = _mailbox;
      final remembered = widget.lastMailbox?.value;
      final still = current == null
          ? (remembered == null
                ? null
                : boxes.values
                      .expand((l) => l)
                      .where((m) => m.id == remembered)
                      .firstOrNull)
          : boxes[current.account]
                ?.where((m) => m.id == current.id)
                .firstOrNull;
      _mailbox =
          still ??
          boxes.values
              .expand((l) => l)
              .where((m) => m.role == MailboxRole.inbox)
              .firstOrNull ??
          boxes.values.expand((l) => l).firstOrNull;
    });
    await _loadRows();
  });

  Future<void> _refreshMailboxes(String account) => _guard(() async {
    final list = await _service.listMailboxes(account);
    if (!mounted) return;
    setState(() {
      _mailboxes[account] = list;
      final current = _mailbox;
      if (current != null && current.account == account) {
        _mailbox = list.where((m) => m.id == current.id).firstOrNull ?? current;
      }
    });
  });

  Future<void> _loadRows() => _guard(() async {
    final mailbox = _mailbox;
    final search = _searchText;
    List<MessageSummary> rows;
    if (search != null) {
      final ids = await _service.search(search);
      rows = ids.isEmpty
          ? const []
          : await _service.listMessages(ListQuery(mailbox?.id ?? '', ids: ids));
      rows = filterByScope(rows, search, _scope);
    } else if (mailbox == null) {
      rows = const [];
    } else {
      rows = await _service.listMessages(ListQuery(mailbox.id));
    }
    if (!mounted) return;
    setState(() {
      _rows = rows;
      if (_selected != null && !rows.any((r) => r.id == _selected)) {
        _selected = null;
        _conversation = const [];
      }
    });
  });

  void _onEvent(MailEvent e) {
    switch (e) {
      case AccountsChanged():
        _loadAccounts();
      case MailboxesChanged(:final account):
        _refreshMailboxes(account);
      case MessagesChanged(:final mailbox):
        if (_searchText != null || mailbox == _mailbox?.id) _loadRows();
        final account = _mailboxes.entries
            .where((en) => en.value.any((m) => m.id == mailbox))
            .firstOrNull
            ?.key;
        if (account != null) _refreshMailboxes(account);
      case SyncStateChanged(:final state):
        if (state.phase == SyncPhase.error) {
          final name =
              _accounts
                  .where((a) => a.id == state.account)
                  .firstOrNull
                  ?.address ??
              state.account;
          setState(() => _banner = l10n.syncFailed(name, state.error));
        }
    }
  }

  static String _threadKey(MessageSummary r) =>
      r.thread.isEmpty ? r.id : r.thread;

  bool _passesFilter(MessageSummary r) => switch (_filter) {
    MailFilter.all => true,
    MailFilter.unread => r.unread || r.id == _selected,
    MailFilter.flagged => r.flagged,
  };

  /// The rows grouped by conversation, newest first: the newest message of each thread and
  /// all its messages (newest first).
  List<(MessageSummary, List<MessageSummary>)> get _threads {
    final byThread = <String, List<MessageSummary>>{};
    for (final r in _rows.where(_passesFilter)) {
      byThread.putIfAbsent(_threadKey(r), () => []).add(r);
    }
    final out = [
      for (final list in byThread.values)
        ((list..sort((a, b) => b.date.compareTo(a.date))).first, list),
    ]..sort((a, b) => b.$1.date.compareTo(a.$1.date));
    return out;
  }

  /// Selects a row. The head of a thread opens the whole conversation; a child row of an
  /// expanded thread (`single`) opens that message only. The reader can follow after
  /// `readerDelay` (after a delete, ML-01b); the messages are marked read
  /// [MailMetrics.markReadDelay] after the selection.
  Future<void> select(
    String id, {
    bool single = false,
    Duration readerDelay = Duration.zero,
  }) => _guard(() async {
    final row = _rows.where((r) => r.id == id).firstOrNull;
    if (row == null) return;
    _markRead?.cancel();
    setState(() => _selected = id);
    if (readerDelay > Duration.zero) {
      await Future<void>.delayed(readerDelay);
      if (!mounted || _selected != id) return;
    }
    final thread = _threadKey(row);
    final members = single
        ? [row]
        : (_rows.where((r) => _threadKey(r) == thread).toList()
            ..sort((a, b) => b.date.compareTo(a.date)));
    final messages = <Message>[];
    for (final m in members) {
      messages.add(await _service.getMessage(m.id));
    }
    if (!mounted || _selected != id) return;
    setState(() => _conversation = messages);
    final unread = [
      for (final m in members)
        if (m.unread) m.id,
    ];
    if (unread.isNotEmpty) {
      _markRead = Timer(MailMetrics.markReadDelay, () {
        if (!mounted || _selected != id) return;
        _guard(() => _service.setFlags(unread, add: {MessageFlag.seen}));
      });
    }
  });

  MessageSummary? get _selectedRow =>
      _rows.where((r) => r.id == _selected).firstOrNull;

  /// Expands or collapses the thread of `row` (Right and Left arrows, or the count).
  void _setExpanded(MessageSummary row, bool expanded) {
    final key = _threadKey(row);
    if (_rows.where((r) => _threadKey(r) == key).length < 2) return;
    setState(() => expanded ? _expanded.add(key) : _expanded.remove(key));
  }

  Future<void> _selectMailbox(Mailbox m) async {
    widget.lastMailbox?.value = m.id;
    setState(() {
      _mailbox = m;
      _searchText = null;
      _scope = SearchScope.all;
      _searching = false;
      _suggesting = false;
      _query.clear();
      _selected = null;
      _conversation = const [];
    });
    await _loadRows();
  }

  Future<void> _delete() async {
    final row = _selectedRow;
    if (row == null) return;
    final order = _threads.map((t) => t.$1.id).toList();
    final next = order.indexOf(row.id);
    await _guard(() => _service.delete([row.id]));
    await _loadRows();
    // No animation: the rows below move up in one frame, the next message is selected at
    // once and the reader follows ~120 ms later (ML-01b).
    final threads = _threads;
    if (threads.isNotEmpty && next >= 0) {
      await select(
        threads[next.clamp(0, threads.length - 1)].$1.id,
        readerDelay: MailMetrics.readerAfterDelete,
      );
    } else {
      setState(() {
        _selected = null;
        _conversation = const [];
      });
    }
  }

  Future<void> _archive() async {
    final row = _selectedRow;
    final archive = _mailboxes[_mailbox?.account]
        ?.where((m) => m.role == MailboxRole.archive)
        .firstOrNull;
    if (row == null || archive == null) return;
    await _guard(() => _service.move([row.id], archive.id));
  }

  Future<void> _toggleFlag() async {
    final row = _selectedRow;
    if (row == null) return;
    await _guard(
      () => row.flagged
          ? _service.setFlags([row.id], remove: {MessageFlag.flagged})
          : _service.setFlags([row.id], add: {MessageFlag.flagged}),
    );
  }

  void compose(ComposeKind kind) {
    final account =
        _accounts.where((a) => a.id == _mailbox?.account).firstOrNull ??
        _accounts.firstOrNull;
    if (account == null) {
      setState(() => _setup = true);
      return;
    }
    final message = _conversation.firstOrNull;
    if (kind != ComposeKind.fresh && message == null) return;
    setState(
      () => _compose = ComposeRequest.from(
        kind: kind,
        account: account,
        message: message,
        now: _now,
      ),
    );
  }

  void _startSearch() {
    setState(() => _searching = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _queryFocus.requestFocus(),
    );
  }

  Future<void> _runSearch([SearchScope scope = SearchScope.all]) async {
    final text = _query.text.trim();
    setState(() {
      _searchText = text.isEmpty ? null : text;
      _scope = scope;
      _suggesting = false;
      _selected = null;
      _conversation = const [];
    });
    // After Enter the arrows walk the results and Escape ends the search.
    _focus.requestFocus();
    await _loadRows();
  }

  Future<void> _endSearch() async {
    _query.clear();
    setState(() {
      _searching = false;
      _suggesting = false;
      _searchText = null;
      _scope = SearchScope.all;
    });
    _focus.requestFocus();
    await _loadRows();
  }

  /// The rows in list order: each thread head, then its children when expanded.
  List<(MessageSummary, bool)> get _visibleRows => [
    for (final (head, members) in _threads) ...[
      (head, false),
      if (_expanded.contains(_threadKey(head)))
        for (final m in members.skip(1)) (m, true),
    ],
  ];

  void _moveSelection(int delta) {
    final rows = _visibleRows;
    if (rows.isEmpty) return;
    final at = rows.indexWhere((t) => t.$1.id == _selected);
    final next = (at < 0 ? (delta > 0 ? 0 : rows.length - 1) : at + delta)
        .clamp(0, rows.length - 1);
    select(rows[next].$1.id, single: rows[next].$2);
  }

  void _openLink(String url) {
    if (!safeLink(url)) return;
    final open = widget.openUrl;
    if (open != null) {
      open(url);
      return;
    }
    // Under `flutter test` nothing starts on the machine running the tests.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    Process.run('xdg-open', [url]).ignore();
  }

  void _menusChanged() {
    if (mounted) setState(() {});
  }

  /// The mailboxes in sidebar order (every account's).
  List<Mailbox> get _allMailboxes => [
    for (final a in _accounts) ...?_mailboxes[a.id],
  ];

  Future<void> _moveSelected(String mailbox) async {
    final row = _selectedRow;
    if (row == null) return;
    await _guard(() => _service.move([row.id], mailbox));
  }

  /// Mark as Read / Mark as Unread for the open conversation.
  Future<void> _toggleRead() async {
    final ids = [for (final m in _conversation) m.id];
    if (ids.isEmpty) return;
    _markRead?.cancel();
    final unread = _rows.any((r) => ids.contains(r.id) && r.unread);
    await _guard(
      () => unread
          ? _service.setFlags(ids, add: {MessageFlag.seen})
          : _service.setFlags(ids, remove: {MessageFlag.seen}),
    );
  }

  Future<void> _markAllRead() async {
    final ids = [
      for (final r in _rows)
        if (r.unread) r.id,
    ];
    if (ids.isEmpty) return;
    await _guard(() => _service.setFlags(ids, add: {MessageFlag.seen}));
  }

  Future<void> _syncAll() async {
    for (final a in _accounts) {
      await _guard(() => _service.sync(a.id));
    }
  }

  Future<void> _syncCurrent() async {
    final id = _mailbox?.account;
    if (id == null) return;
    await _guard(() => _service.sync(id));
  }

  void _expandAll() => setState(() {
    for (final (head, members) in _threads) {
      if (members.length > 1) _expanded.add(_threadKey(head));
    }
  });

  /// Goes to the previous or next mailbox in the sidebar's order.
  void _stepMailbox(int delta) {
    final all = _allMailboxes;
    if (all.isEmpty) return;
    final at = all.indexWhere((m) => m.id == _mailbox?.id);
    final next = at < 0
        ? (delta > 0 ? 0 : all.length - 1)
        : (at + delta).clamp(0, all.length - 1);
    if (next != at) _selectMailbox(all[next]);
  }

  /// What the menu bar shows and does now (menus.dart).
  MailMenuModel _menuModel() {
    final composing = _compose != null;
    final row = _selectedRow;
    final hasMessage = row != null && _conversation.isNotEmpty;
    final ids = {for (final m in _conversation) m.id};
    final account = _accounts
        .where((a) => a.id == _mailbox?.account)
        .firstOrNull;
    final inbox = _roleBox(MailboxRole.inbox);
    final sent = _roleBox(MailboxRole.sent);
    final archive = _roleBox(MailboxRole.archive);
    final junk = _roleBox(MailboxRole.junk);
    VoidCallback? go(Mailbox? box) =>
        box == null ? null : () => _selectMailbox(box);
    VoidCallback? move(Mailbox? box) => box == null || box.id == _mailbox?.id
        ? null
        : () => _moveSelected(box.id);
    return MailMenuModel(
      composing: composing,
      editing: composing || _searching,
      canSend: _composer.canSend,
      hasMessage: hasMessage,
      messageUnread: _rows.any((r) => ids.contains(r.id) && r.unread),
      flagged: row?.flagged ?? false,
      sidebarShown: _sidebarShown,
      sender: _conversation.firstOrNull?.from.display,
      accountName: account == null
          ? null
          : (account.name.isNotEmpty ? account.name : account.address),
      accountNames: [
        for (final a in _accounts) a.name.isNotEmpty ? a.name : a.address,
      ],
      moveTargets: [
        for (final a in _accounts)
          (
            account: a.name.isNotEmpty ? a.name : a.address,
            mailboxes: [
              for (final m in _mailboxes[a.id] ?? const <Mailbox>[])
                (name: mailboxName(m), run: move(m)),
            ],
          ),
      ],
      newMessage: () => compose(ComposeKind.fresh),
      openAccounts: () => setState(() => _setup = true),
      closeComposer: () => unawaited(_composer.close()),
      search: _startSearch,
      deleteMessage: row == null ? null : () => unawaited(_delete()),
      getNewMail: _accounts.isEmpty ? null : () => unawaited(_syncAll()),
      syncAccount: account == null ? null : () => unawaited(_syncCurrent()),
      markAllRead: _rows.any((r) => r.unread)
          ? () => unawaited(_markAllRead())
          : null,
      expandAll: _rows.isEmpty ? null : _expandAll,
      collapseAll: _rows.isEmpty ? null : () => setState(_expanded.clear),
      toggleSidebar: () => setState(() => _sidebarShown = !_sidebarShown),
      goInbox: go(inbox),
      goSent: go(sent),
      moveInbox: hasMessage ? move(inbox) : null,
      moveSent: hasMessage ? move(sent) : null,
      previousMailbox: () => _stepMailbox(-1),
      nextMailbox: () => _stepMailbox(1),
      send: () => unawaited(_composer.send()),
      reply: () => compose(ComposeKind.reply),
      replyAll: () => compose(ComposeKind.replyAll),
      forward: () => compose(ComposeKind.forward),
      toggleRead: () => unawaited(_toggleRead()),
      junk: junk == null ? null : () => unawaited(_junk()),
      flag: () => unawaited(_toggleFlag()),
      clearFlag: () => unawaited(_toggleFlag()),
      toggleFlag: () => unawaited(_toggleFlag()),
      archive: archive == null ? null : () => unawaited(_archive()),
    );
  }

  @override
  Widget build(BuildContext context) => AmalfiTheme(
    app: 'Mail',
    child: SilicaMenuBar(
      menus: mailMenus(l10n, _menuModel()),
      child: Builder(builder: _window),
    ),
  );

  Widget _window(BuildContext context) {
    final colors = MailColors.of(context);
    return WindowActiveScope(
      active: _active,
      child: CallbackShortcuts(
        bindings: {
          // ⌘N, ⌘R, ⇧⌘R, ⇧⌘F and ⌘F are the menu bar's (SilicaMenuBar binds them).
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_searching || _searchText != null) _endSearch();
          },
          const SingleActivator(LogicalKeyboardKey.delete): _delete,
          const SingleActivator(LogicalKeyboardKey.backspace): _delete,
          const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
              _moveSelection(1),
          const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
              _moveSelection(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () {
            if (_selectedRow case final row?) _setExpanded(row, true);
          },
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
            if (_selectedRow case final row?) _setExpanded(row, false);
          },
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
          child: ColoredBox(
            color: colors.content,
            child: AmalfiAttachedSheet(
              open: _setup,
              titleBarHeight: MailMetrics.toolbar,
              sheet: AccountSetup(
                key: const ValueKey('account setup'),
                service: _service,
                onClose: () {
                  setState(() => _setup = false);
                  _focus.requestFocus();
                },
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: _layout(colors)),
                  if (_hasBanner)
                    Positioned(
                      left: _sidebarShown ? MailMetrics.sidebarWidth : 0,
                      right: 0,
                      top: MailMetrics.toolbar,
                      height: MailMetrics.bannerHeight,
                      child: _bannerBar(colors),
                    ),
                  if (_suggesting && _query.text.trim().isNotEmpty)
                    Positioned(
                      top: MailMetrics.toolbar - 6,
                      right: 20,
                      child: _suggestions(),
                    ),
                  if (_compose case final request?)
                    Positioned.fill(
                      child: ComposeSheet(
                        key: const ValueKey('composer'),
                        controller: _composer,
                        request: request,
                        service: _service,
                        onClose: () {
                          setState(() => _compose = null);
                          _focus.requestFocus();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The three columns, each with its own toolbar section (kit `Apps/Mail/Inbox`): the
  /// sidebar (240) running up behind its section, the list (320) and the reader.
  Widget _layout(MailColors colors) => AmalfiSplitWindowLayout(
    columns: [
      if (_sidebarShown)
        AmalfiWindowColumn(
          width: MailMetrics.sidebarWidth,
          toolbar: _sidebarToolbar(),
          toolbarOverChild: true,
          ownEdge: true,
          child: _sidebar(colors),
        ),
      AmalfiWindowColumn(
        width: MailMetrics.listWidth,
        toolbar: _listToolbar(colors),
        child: Padding(
          padding: EdgeInsets.only(top: _bannerInset),
          child: _list(colors),
        ),
      ),
      AmalfiWindowColumn(
        toolbar: _readerToolbar(colors),
        child: ColoredBox(
          color: colors.reader,
          child: Padding(
            padding: EdgeInsets.only(top: _bannerInset),
            child: _reader(colors),
          ),
        ),
      ),
    ],
  );

  /// The space the message bar takes under the toolbar.
  double get _bannerInset => _hasBanner ? MailMetrics.bannerHeight : 0;

  Widget _bannerBar(MailColors colors) => Container(
    key: const ValueKey('banner'),
    color: colors.banner,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    alignment: Alignment.centerLeft,
    child: Row(
      children: [
        Expanded(
          child: Text(
            _banner ?? l10n.sampleData,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AmalfiType.callout(color: colors.secondary),
          ),
        ),
        if (_banner != null)
          GestureDetector(
            key: const ValueKey('banner close'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _banner = null),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: AmalfiGlyph(
                AmalfiGlyphs.xmark,
                size: 12,
                color: colors.secondary,
              ),
            ),
          ),
      ],
    ),
  );

  // MARK: toolbars

  /// The window buttons are drawn by the compositor over this slot (kit
  /// `Titlebars/Piece/Controls`, 96 wide).
  Widget get _controlsSlot =>
      const SizedBox(width: AmalfiToolbarPieceMetrics.controlsWidth);

  /// The sidebar button (kit `Titlebars/Piece/Sidebar Toggle`): in the sidebar's section, or
  /// in the list's when the sidebar is hidden.
  Widget _sidebarToggle() => AmalfiToolbarPiece(
    child: AmalfiToolbarButton(
      key: const ValueKey('sidebar toggle'),
      semanticLabel: l10n.sidebar,
      icon: const AmalfiGlyph(AmalfiGlyphs.sidebar),
      onPressed: () => setState(() => _sidebarShown = !_sidebarShown),
    ),
  );

  Widget _sidebarToolbar() => WindowDragArea(
    child: AmalfiToolbar.sidebarSection(
      key: const ValueKey('sidebar bar'),
      children: [_controlsSlot, const AmalfiSpacerPiece(), _sidebarToggle()],
    ),
  );

  Mailbox? _roleBox(MailboxRole role) =>
      _mailboxes[_mailbox?.account]?.where((m) => m.role == role).firstOrNull;

  Future<void> _junk() async {
    final row = _selectedRow;
    final junk = _roleBox(MailboxRole.junk);
    if (row == null || junk == null) return;
    await _guard(() => _service.move([row.id], junk.id));
  }

  /// The title block (kit `Titlebars/Piece/Title + Subtitle`) and the filter group (kit
  /// `Apps/Mail/Toolbar List`).
  Widget _listToolbar(MailColors colors) {
    final mailbox = _mailbox;
    final searching = _searchText != null;
    final title = searching
        ? l10n.searching
        : mailbox == null
        ? l10n.appTitle
        : mailboxName(mailbox);
    final unread = _rows.where((r) => r.unread).length;
    final subtitle = searching
        ? l10n.searchScope(_rows.length)
        : unread == 0
        ? l10n.messageCount(_rows.length)
        : l10n.messageCountUnread(_rows.length, unread);
    return WindowDragArea(
      child: AmalfiToolbar.section(
        key: const ValueKey('list bar'),
        padding: _sidebarShown
            ? AmalfiToolbarMetrics.sectionPadding
            : AmalfiToolbarMetrics.sidebarSectionPadding,
        children: [
          if (!_sidebarShown) ...[_controlsSlot, _sidebarToggle()],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AmalfiTitlePiece(title: title, subtitle: subtitle),
            ),
          ),
          if (_mailbox != null || searching)
            AmalfiToolbarPiece(
              child: KeyedSubtree(
                key: _filterKey,
                child: AmalfiActionSegments(
                  key: const ValueKey('list filter'),
                  segments: [
                    AmalfiSegment.icon(
                      const AmalfiSymbol('filter'),
                      semanticLabel: l10n.filter,
                      tooltip: l10n.filter,
                      // Chosen, the filter shows in the accent while it hides messages.
                    ),
                    AmalfiSegment.icon(
                      const AmalfiSymbol('ellipsis'),
                      semanticLabel: l10n.more,
                      tooltip: l10n.more,
                    ),
                  ],
                  selected: {if (_filter != MailFilter.all) 0},
                  onPressed: (i) => i == 0 ? _filterMenu() : _moreMenu(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  final GlobalKey _filterKey = GlobalKey(debugLabel: 'list filter group');

  /// Opens a menu under segment `index` of the filter group.
  Future<void> _menuUnderFilter(
    int index,
    List<AmalfiMenuEntry> entries,
  ) async {
    final box = _filterKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final origin = box.localToGlobal(Offset(index * 32.0, box.size.height + 4));
    await showAmalfiMenu(
      context: context,
      position: origin,
      entries: entries,
      minWidth: 200,
    );
  }

  Future<void> _filterMenu() => _menuUnderFilter(0, [
    for (final (f, label) in [
      (MailFilter.all, l10n.showAllMessages),
      (MailFilter.unread, l10n.showUnread),
      (MailFilter.flagged, l10n.showFlagged),
    ])
      AmalfiMenuAction(
        label,
        checked: _filter == f,
        onSelected: () => setState(() => _filter = f),
      ),
  ]);

  Future<void> _moreMenu() => _menuUnderFilter(1, [
    AmalfiMenuAction(
      l10n.menuGetNewMail,
      enabled: _accounts.isNotEmpty,
      onSelected: () => unawaited(_syncAll()),
    ),
    AmalfiMenuAction(
      l10n.menuMarkAllMessagesAsRead,
      enabled: _rows.any((r) => r.unread),
      onSelected: () => unawaited(_markAllRead()),
    ),
  ]);

  /// The reader's section (kit `Apps/Mail/Toolbar Reader`): compose, the reply group, the
  /// triage group and the search field, 16 from the window's edge.
  Widget _readerToolbar(MailColors colors) {
    final hasMessage = _conversation.isNotEmpty;
    return WindowDragArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= MailMetrics.searchFieldMinReader;
          // Kit `Apps/Mail/Toolbar Reader Search`: while searching the toolbar keeps only
          // compose and the search field (the groups are in the Message menu).
          final searchOnly = _searching || _searchText != null;
          final field = _searchField(colors);
          return AmalfiToolbar.section(
            key: const ValueKey('reader bar'),
            padding: const EdgeInsets.only(left: 12, right: 16),
            children: [
              const AmalfiSpacerPiece(),
              AmalfiToolbarPiece(
                key: const ValueKey('compose piece'),
                child: AmalfiToolbarButton(
                  key: const ValueKey('compose'),
                  semanticLabel: l10n.newMessage,
                  icon: const AmalfiGlyph(AmalfiGlyphs.compose),
                  onPressed: () => compose(ComposeKind.fresh),
                ),
              ),
              if (!searchOnly) ...[
                AmalfiToolbarPiece(
                  key: const ValueKey('reply piece'),
                  child: AmalfiActionSegments(
                    key: const ValueKey('reply group'),
                    segments: [
                      AmalfiSegment.icon(
                        const AmalfiSymbol('reply'),
                        semanticLabel: l10n.reply,
                        tooltip: l10n.reply,
                        enabled: hasMessage,
                      ),
                      AmalfiSegment.icon(
                        const AmalfiSymbol('reply-all'),
                        semanticLabel: l10n.replyAll,
                        tooltip: l10n.replyAll,
                        enabled: hasMessage,
                      ),
                      AmalfiSegment.icon(
                        const AmalfiSymbol('forward'),
                        semanticLabel: l10n.forward,
                        tooltip: l10n.forward,
                        enabled: hasMessage,
                      ),
                    ],
                    onPressed: (i) => compose(switch (i) {
                      0 => ComposeKind.reply,
                      1 => ComposeKind.replyAll,
                      _ => ComposeKind.forward,
                    }),
                  ),
                ),
                AmalfiToolbarPiece(
                  key: const ValueKey('triage piece'),
                  child: AmalfiActionSegments(
                    key: const ValueKey('triage group'),
                    segments: [
                      AmalfiSegment.icon(
                        const AmalfiSymbol('archive'),
                        semanticLabel: l10n.archive,
                        tooltip: l10n.archive,
                        // Disabled, not silent, without an Archive mailbox.
                        enabled:
                            hasMessage && _roleBox(MailboxRole.archive) != null,
                      ),
                      AmalfiSegment.icon(
                        const AmalfiGlyph(AmalfiGlyphs.trash),
                        semanticLabel: l10n.delete,
                        tooltip: l10n.delete,
                        enabled: hasMessage,
                      ),
                      AmalfiSegment.icon(
                        const AmalfiSymbol('flag'),
                        semanticLabel: l10n.flag,
                        tooltip: l10n.flag,
                        enabled: hasMessage,
                      ),
                    ],
                    selected: {if (_selectedRow?.flagged ?? false) 2},
                    onPressed: (i) => switch (i) {
                      0 => _archive(),
                      1 => _delete(),
                      _ => _toggleFlag(),
                    },
                  ),
                ),
              ],
              if (wide || searchOnly)
                AmalfiToolbarPiece(
                  key: const ValueKey('search piece'),
                  child: field,
                )
              else
                AmalfiToolbarPiece(
                  key: const ValueKey('search piece'),
                  child: AmalfiToolbarButton(
                    key: const ValueKey('search'),
                    semanticLabel: l10n.search,
                    icon: const AmalfiGlyph(AmalfiGlyphs.search),
                    onPressed: _startSearch,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// The search field (kit `Titlebars/Piece/Search` and `Search Token`): 200 wide, 240 with a
  /// scope token before the text after choosing a suggestion.
  Widget _searchField(MailColors colors) {
    final token = _searchText != null && _scope != SearchScope.all;
    final tokenLabel = _scope == SearchScope.sender
        ? l10n.tokenSender
        : l10n.tokenSubject;
    final width = token ? 240.0 : 200.0;
    return AmalfiSearchField(
      key: const ValueKey('search field'),
      controller: _query,
      focusNode: _queryFocus,
      size: AmalfiFieldSize.large,
      width: width,
      placeholder: l10n.search,
      semanticLabel: l10n.search,
      tokens: [if (token) tokenLabel],
      onTokensChanged: (tokens) {
        // Removing the scope token searches everywhere again.
        if (tokens.isEmpty && token) unawaited(_runSearch());
      },
      onChanged: (text) => setState(() {
        _searching = true;
        _suggesting = text.trim().isNotEmpty;
      }),
      onSubmitted: (_) => _runSearch(),
      onCleared: _endSearch,
    );
  }

  /// The suggestions under the search field while typing: the text itself, then the text in
  /// one field.
  Widget _suggestions() {
    final text = _query.text.trim();
    return SizedBox(
      key: const ValueKey('search suggestions'),
      width: 240,
      child: AmalfiMenu(
        width: 240,
        entries: [
          AmalfiMenuAction(
            text,
            onSelected: () => unawaited(_runSearch(SearchScope.all)),
          ),
          AmalfiMenuAction(
            '${l10n.senderContains} $text',
            onSelected: () => unawaited(_runSearch(SearchScope.sender)),
          ),
          AmalfiMenuAction(
            '${l10n.subjectContains} $text',
            onSelected: () => unawaited(_runSearch(SearchScope.subject)),
          ),
        ],
      ),
    );
  }

  // MARK: sidebar

  Widget _sidebar(MailColors colors) {
    final children = <Widget>[];
    if (_searchText != null) {
      children
        ..add(AmalfiSidebarHeader(title: l10n.searchSection))
        ..add(
          AmalfiSidebarRow(
            key: const ValueKey('all mailboxes'),
            label: l10n.allMailboxes,
            icon: AmalfiGlyphs.search,
            badge: '${_rows.length}',
            selected: true,
          ),
        );
    }
    for (final account in _accounts) {
      children.add(
        AmalfiSidebarHeader(
          title: account.name.isNotEmpty ? account.name : account.address,
        ),
      );
      for (final m in _mailboxes[account.id] ?? const <Mailbox>[]) {
        children.add(
          AmalfiSidebarRow(
            key: ValueKey('mailbox ${m.id}'),
            label: mailboxName(m),
            icon: _mailboxGlyph(m.role),
            badge: m.unread > 0 ? '${m.unread}' : null,
            selected: m.id == _mailbox?.id && _searchText == null,
            onTap: () => _selectMailbox(m),
          ),
        );
      }
    }
    if (_accounts.isEmpty && !_loading) {
      children.add(
        AmalfiSidebarRow(
          key: const ValueKey('add account'),
          label: l10n.addAccount,
          icon: AmalfiGlyphs.plus,
          onTap: () => setState(() => _setup = true),
        ),
      );
    }
    // The panel runs up behind the sidebar's section: its first header sits 8 below it.
    return AmalfiSidebarPanel(
      key: const ValueKey('sidebar'),
      padding: const EdgeInsets.fromLTRB(12, MailMetrics.toolbar + 8, 12, 0),
      children: children,
    );
  }

  static AmalfiGlyphData? _mailboxGlyph(MailboxRole role) => switch (role) {
    MailboxRole.inbox => AmalfiSymbols.load('tray'),
    MailboxRole.drafts => AmalfiGlyphs.doc,
    MailboxRole.sent => AmalfiSymbols.load('paperplane'),
    MailboxRole.archive => AmalfiSymbols.load('archive'),
    MailboxRole.junk => AmalfiGlyphs.warning,
    MailboxRole.trash => AmalfiGlyphs.trash,
    MailboxRole.other => AmalfiGlyphs.folder,
  };

  // MARK: list

  /// `text` with the search matches on the search highlight.
  Widget _marked(
    String text,
    TextStyle style,
    MailColors colors, {
    int maxLines = 1,
  }) {
    final query = _searchText?.toLowerCase();
    if (query == null || query.isEmpty) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    var at = 0;
    while (true) {
      final hit = lower.indexOf(query, at);
      if (hit < 0) break;
      if (hit > at) spans.add(TextSpan(text: text.substring(at, hit)));
      spans.add(
        TextSpan(
          text: text.substring(hit, hit + query.length),
          style: TextStyle(
            backgroundColor: colors.highlight,
            color: colors.text,
          ),
        ),
      );
      at = hit + query.length;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(style: style, children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Whether the search text is in the sender or the subject: a best match.
  bool _bestMatch(MessageSummary r) {
    final q = _searchText?.toLowerCase();
    if (q == null || q.isEmpty) return false;
    return r.subject.toLowerCase().contains(q) ||
        r.from.display.toLowerCase().contains(q) ||
        r.from.address.toLowerCase().contains(q);
  }

  Widget _listHeader(MailColors colors, String title) => SizedBox(
    height: MailMetrics.listHeader,
    child: Padding(
      padding: const EdgeInsets.only(
        left: MailMetrics.textX,
        top: MailMetrics.listHeaderTop,
      ),
      child: Text(
        title,
        key: ValueKey('list header $title'),
        style: AmalfiType.label(color: colors.tertiary),
      ),
    ),
  );

  Widget _list(MailColors colors) {
    final threads = _threads;
    if (threads.isEmpty) {
      // An empty mailbox is an empty list (kit `Apps/Mail/Empty Mailbox`); a search or a
      // filter that hides everything says so.
      final why = _searchText != null
          ? l10n.noResults
          : _filter != MailFilter.all && _rows.isNotEmpty
          ? l10n.noMessages
          : null;
      return SizedBox.expand(
        key: const ValueKey('empty list'),
        child: why == null
            ? null
            : Center(
                child: Text(
                  why,
                  style: AmalfiType.title3(color: colors.tertiary),
                ),
              ),
      );
    }
    // A search groups the conversations: sender and subject matches first.
    final searching = _searchText != null;
    final best = searching
        ? [
            for (final t in threads)
              if (t.$2.any(_bestMatch)) t,
          ]
        : const <(MessageSummary, List<MessageSummary>)>[];
    final rest = searching
        ? [
            for (final t in threads)
              if (!t.$2.any(_bestMatch)) t,
          ]
        : threads;
    final items = <Object>[
      if (best.isNotEmpty) ...[l10n.bestMatches, ...best],
      if (searching && rest.isNotEmpty && best.isNotEmpty) l10n.allResults,
      ...rest,
    ];
    final ordered = [
      for (final i in items)
        if (i is (MessageSummary, List<MessageSummary>)) i,
    ];
    return ListView.builder(
      key: const ValueKey('message list'),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is String) return _listHeader(colors, item);
        final (head, members) = item as (MessageSummary, List<MessageSummary>);
        final expanded =
            members.length > 1 && _expanded.contains(_threadKey(head));
        final at = ordered.indexWhere((t) => t.$1.id == head.id);
        final nextChosen =
            at + 1 < ordered.length && ordered[at + 1].$1.id == _selected;
        final headRow = _row(
          colors,
          head,
          count: members.length,
          expanded: expanded,
          separator: !expanded && head.id != _selected && !nextChosen,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!expanded) headRow,
            AnimatedSize(
              duration: expanded
                  ? MailMetrics.threadExpand
                  : MailMetrics.threadCollapse,
              // Assumption: not measured (only the duration was): the plain ease-out.
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      key: ValueKey('thread block ${head.id}'),
                      margin: const EdgeInsets.symmetric(
                        horizontal: MailMetrics.selectionInsetX,
                      ),
                      decoration: BoxDecoration(
                        color: colors.threadTint,
                        borderRadius: BorderRadius.circular(
                          MailMetrics.selectionRadius,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _row(
                            colors,
                            head,
                            count: members.length,
                            expanded: true,
                            separator: false,
                            inBlock: true,
                          ),
                          for (final m in members.skip(1)) _childRow(colors, m),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }

  /// A row of the list (kit `Apps/Mail/List Row/*`: 320 × 84).
  Widget _row(
    MailColors colors,
    MessageSummary row, {
    required int count,
    required bool expanded,
    required bool separator,
    bool inBlock = false,
  }) {
    final chosen = row.id == _selected;
    final fill = chosen
        ? (_active ? colors.selection : colors.inactiveSelection)
        : null;
    final onFill = chosen && _active;
    final primary = onFill ? colors.selectionText : colors.text;
    final secondary = onFill ? colors.selectionText : colors.secondary;
    final blue = onFill ? colors.selectionText : colors.accent;
    // Inside an expanded block the block is already inset.
    final shift = inBlock ? MailMetrics.selectionInsetX : 0.0;
    final inset = inBlock ? 0.0 : MailMetrics.selectionInsetX;
    final textX = MailMetrics.textX - shift;
    final mailbox = _searchText == null
        ? null
        : _mailboxes.values
              .expand((l) => l)
              .where((m) => m.id == row.mailbox)
              .firstOrNull;
    return GestureDetector(
      key: ValueKey('row ${row.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focus.requestFocus();
        select(row.id);
      },
      child: SizedBox(
        height: MailMetrics.listRow,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (fill != null)
              Positioned(
                left: inset,
                right: inset,
                top: MailMetrics.selectionInsetY,
                bottom: MailMetrics.selectionInsetY,
                child: DecoratedBox(
                  key: ValueKey('selection ${row.id}'),
                  decoration: ShapeDecoration(
                    color: fill,
                    shape: const AmalfiSmoothBorder(
                      radius: MailMetrics.selectionRadius,
                    ),
                  ),
                ),
              ),
            if (row.unread)
              Positioned(
                left: MailMetrics.unreadDotX - shift,
                top: MailMetrics.unreadDotY,
                child: Container(
                  key: ValueKey('unread dot ${row.id}'),
                  width: MailMetrics.unreadDot,
                  height: MailMetrics.unreadDot,
                  decoration: BoxDecoration(
                    color: onFill ? colors.selectionText : colors.unread,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            Positioned(
              left: textX,
              right: MailMetrics.textEnd,
              top: MailMetrics.senderY,
              height: MailMetrics.senderLine,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _marked(
                      count > 1 ? _threadSenders(row) : row.from.display,
                      AmalfiType.headline(color: primary),
                      colors,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(
                      mailbox == null
                          ? listDate(row.date, _now)
                          : '${mailboxName(mailbox)} · ${listDate(row.date, _now)}',
                      key: ValueKey('date ${row.id}'),
                      style: AmalfiType.callout(color: secondary),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: textX,
              right: MailMetrics.textEnd,
              top: MailMetrics.subjectY,
              height: MailMetrics.subjectLine,
              child: Row(
                children: [
                  Expanded(
                    child: _marked(
                      row.subject,
                      AmalfiType.body(color: primary),
                      colors,
                    ),
                  ),
                  if (row.flagged)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AmalfiSymbol(
                        'flag-fill',
                        color: onFill ? colors.selectionText : colors.flagged,
                        size: 12,
                      ),
                    ),
                  if (count > 1)
                    GestureDetector(
                      key: ValueKey('thread count ${row.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _setExpanded(row, !expanded),
                      child: Semantics(
                        button: true,
                        expanded: expanded,
                        label: l10n.messageCount(count),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: AmalfiType.callout(color: blue),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 14,
                              height: 14,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: blue),
                              ),
                              child: Transform.rotate(
                                angle: expanded ? 1.5708 : 0,
                                child: AmalfiGlyph(
                                  AmalfiGlyphs.chevronRight,
                                  size: 8,
                                  color: blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: textX,
              right: MailMetrics.textEnd,
              top: MailMetrics.summaryY,
              height: MailMetrics.summaryLine * 2,
              child: _marked(
                row.preview,
                AmalfiType.callout(color: secondary),
                colors,
                maxLines: 2,
              ),
            ),
            if (separator)
              Positioned(
                left: textX,
                right: 0,
                bottom: 0,
                height: 1,
                child: ColoredBox(color: colors.separator),
              ),
          ],
        ),
      ),
    );
  }

  /// The senders of a thread: "Anna and Marco" (two), or the newest sender.
  String _threadSenders(MessageSummary head) {
    final key = _threadKey(head);
    final names = <String>[];
    for (final r in _rows.where((r) => _threadKey(r) == key)) {
      final first = r.from.display.split(' ').first;
      if (!names.contains(first)) names.add(first);
    }
    return names.length == 2
        ? l10n.twoSenders(names[0], names[1])
        : head.from.display;
  }

  /// A child of an expanded thread: sender and one summary line (two-line row, 44).
  Widget _childRow(MailColors colors, MessageSummary row) {
    final chosen = row.id == _selected;
    final fill = chosen
        ? (_active ? colors.selection : colors.inactiveSelection)
        : null;
    final onFill = chosen && _active;
    final primary = onFill ? colors.selectionText : colors.text;
    final secondary = onFill ? colors.selectionText : colors.secondary;
    return GestureDetector(
      key: ValueKey('row ${row.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focus.requestFocus();
        select(row.id, single: true);
      },
      child: Container(
        height: MailMetrics.threadChildRow,
        decoration: ShapeDecoration(
          color: fill,
          shape: const AmalfiSmoothBorder(radius: MailMetrics.selectionRadius),
        ),
        padding: const EdgeInsets.fromLTRB(
          MailMetrics.textX - MailMetrics.selectionInsetX,
          4,
          MailMetrics.textEnd - MailMetrics.selectionInsetX,
          4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.from.display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AmalfiType.headline(color: primary),
                    ),
                  ),
                  Text(
                    listDate(row.date, _now),
                    style: AmalfiType.callout(color: secondary),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 16,
              child: Text(
                row.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmalfiType.callout(color: secondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: reader

  Widget _readerMessage(
    MailColors colors, {
    required String title,
    String? hint,
    String? detail,
    Widget? action,
    Key? key,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            key: key,
            textAlign: TextAlign.center,
            style: AmalfiType.title2(color: colors.tertiary),
          ),
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: AmalfiType.body(color: colors.secondary),
            ),
          ],
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              key: const ValueKey('engine error'),
              textAlign: TextAlign.center,
              style: AmalfiType.callout(color: colors.tertiary),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    ),
  );

  Widget _reader(MailColors colors) {
    if (_engineError case final error?) {
      return _readerMessage(
        colors,
        key: const ValueKey('engine unavailable'),
        title: l10n.engineUnavailable,
        hint: l10n.engineUnavailableHint,
        detail: error,
        action: AmalfiPushButton(
          key: const ValueKey('engine retry'),
          label: _retrying ? l10n.engineStarting : l10n.tryAgain,
          onPressed: _retrying ? null : retryEngine,
        ),
      );
    }
    if (_accounts.isEmpty && !_loading) {
      return _readerMessage(
        colors,
        key: const ValueKey('no accounts'),
        title: l10n.noAccounts,
        hint: l10n.noAccountsHint,
        action: AmalfiPushButton(
          label: l10n.addAccount,
          variant: AmalfiPushButtonVariant.primary,
          onPressed: () => setState(() => _setup = true),
        ),
      );
    }
    if (_conversation.isEmpty) {
      // Kit `Apps/Mail/Reader Empty`: the title's line starts at y 316 of 668, 5 above the
      // centre.
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            l10n.noSelection,
            key: const ValueKey('no selection'),
            style: AmalfiType.title2(color: colors.tertiary),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('reader'),
      padding: const EdgeInsets.fromLTRB(
        MailMetrics.readerPadding,
        MailMetrics.readerCountY,
        MailMetrics.readerPadding,
        MailMetrics.readerPadding,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MailMetrics.readerCountX - MailMetrics.readerPadding,
            bottom:
                MailMetrics.readerCardsTop -
                MailMetrics.readerCountY -
                MailMetrics.readerCountLine,
          ),
          child: SizedBox(
            height: MailMetrics.readerCountLine,
            child: Text(
              l10n.messageCount(_conversation.length),
              key: const ValueKey('reader count'),
              style: AmalfiType.callout(color: colors.secondary),
            ),
          ),
        ),
        for (var i = 0; i < _conversation.length; i++) ...[
          if (i > 0) const SizedBox(height: MailMetrics.cardGap),
          _message(colors, _conversation[i]),
        ],
      ],
    );
  }

  /// The initials of a sender, for the avatar.
  static String initials(Address a) {
    final words = (a.name.isEmpty ? a.address.split('@').first : a.name)
        .split(RegExp(r'[\s._-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  bool get _darkAppearance =>
      AmalfiTheme.of(context).brightness == Brightness.dark;

  /// HTML mail keeps its white page in the dark appearance (ML-01b), as the sender designed
  /// it; plain text follows the appearance. The page's padding and corners are an
  /// assumption (not measured).
  Widget _htmlPage(Widget body) => _darkAppearance
      ? Container(
          key: const ValueKey('html page'),
          padding: const EdgeInsets.all(12),
          decoration: ShapeDecoration(
            color: const Color(0xFFFFFFFF),
            shape: const AmalfiSmoothBorder(radius: 8),
          ),
          child: body,
        )
      : body;

  /// A message card (kit `Apps/Mail/Reader`): a 12 pt raised card with a border, the header
  /// 80 tall (avatar, sender, subject, recipients, date), a separator, the body.
  Widget _message(MailColors colors, Message m) {
    final allowed = _remoteAllowed.contains(m.id);
    final html = m.html.trim();
    final remote =
        html.isNotEmpty && (m.remoteContent || hasRemoteContent(html));
    String names(List<Address> list) => list.map((a) => a.display).join(', ');
    final body = AmalfiType.body(color: colors.text);
    return DecoratedBox(
      key: ValueKey('card ${m.id}'),
      decoration: ShapeDecoration(
        color: colors.card,
        shape: AmalfiSmoothBorder(
          radius: MailMetrics.cardRadius,
          side: BorderSide(
            color: colors.border,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MailMetrics.cardHeader,
            ),
            child: Padding(
              padding: const EdgeInsets.only(
                left: MailMetrics.cardPadding,
                right: MailMetrics.cardPadding,
                top: MailMetrics.cardTextY,
                bottom: 12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: MailMetrics.avatarTop - MailMetrics.cardTextY,
                    ),
                    child: Container(
                      width: MailMetrics.avatar,
                      height: MailMetrics.avatar,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accentSoft,
                      ),
                      child: Text(
                        initials(m.from),
                        style: AmalfiType.label(color: colors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width:
                        MailMetrics.cardTextX -
                        MailMetrics.cardPadding -
                        MailMetrics.avatar,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.from.display,
                          style: AmalfiType.headline(color: colors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m.subject,
                          key: ValueKey('subject ${m.id}'),
                          style: AmalfiType.body(color: colors.text),
                        ),
                        if (m.to.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.to}: ${names(m.to)}',
                            style: AmalfiType.callout(color: colors.secondary),
                          ),
                        ],
                        if (m.cc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.cc}: ${names(m.cc)}',
                            style: AmalfiType.callout(color: colors.secondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        readerDate(m.date, _now),
                        style: AmalfiType.callout(color: colors.secondary),
                      ),
                      if (m.attachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: AmalfiSymbol(
                            'paperclip',
                            color: colors.secondary,
                            size: 14,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 1, child: ColoredBox(color: colors.separator)),
          Padding(
            padding: const EdgeInsets.all(MailMetrics.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (remote && !allowed)
                  Container(
                    key: ValueKey('remote banner ${m.id}'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: ShapeDecoration(
                      color: colors.banner,
                      shape: const AmalfiSmoothBorder(radius: 9),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.remoteContentBlocked,
                            style: AmalfiType.callout(color: colors.secondary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        AmalfiPushButton(
                          key: ValueKey('load remote ${m.id}'),
                          label: l10n.loadRemoteContent,
                          size: AmalfiControlSize.small,
                          onPressed: () =>
                              setState(() => _remoteAllowed.add(m.id)),
                        ),
                      ],
                    ),
                  ),
                if (html.isNotEmpty)
                  _htmlPage(
                    HtmlBody(
                      key: ValueKey('html ${m.id}'),
                      html: html,
                      style: _darkAppearance
                          ? AmalfiType.body(color: MailColors.light.text)
                          : body,
                      linkColor: _darkAppearance
                          ? MailColors.light.link
                          : colors.link,
                      quoteColor: _darkAppearance
                          ? MailColors.light.secondary
                          : colors.secondary,
                      allowRemote: allowed,
                      onLink: _openLink,
                    ),
                  )
                else
                  Text(m.text, key: ValueKey('text ${m.id}'), style: body),
                if (m.attachments.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in m.attachments)
                        GestureDetector(
                          key: ValueKey('attachment ${a.id}'),
                          onTap: () => _saveAttachment(m, a),
                          child: Container(
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: ShapeDecoration(
                              color: colors.banner,
                              shape: const AmalfiSmoothBorder(radius: 9),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AmalfiSymbol(
                                  'paperclip',
                                  color: colors.secondary,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  a.name,
                                  style: AmalfiType.callout(color: colors.text),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  fileSize(a.size),
                                  style: AmalfiType.caption(
                                    color: colors.secondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Saves an attachment in the Downloads folder (the engine writes the file).
  Future<void> _saveAttachment(Message m, Attachment a) => _guard(() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    var dir = '$home/Downloads';
    for (final name in ['Downloads', 'Download', 'Scaricati']) {
      if (Directory('$home/$name').existsSync()) {
        dir = '$home/$name';
        break;
      }
    }
    final safe = a.name.replaceAll('/', '_');
    await _service.saveAttachment(
      m.id,
      a.id,
      '$dir/${safe.isEmpty ? a.id : safe}',
    );
  });
}
