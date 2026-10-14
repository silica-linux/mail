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
import 'model.dart';
import 'service.dart';
import 'setup.dart';
import 'style.dart';

/// What the composer starts from.
enum ComposeKind { fresh, reply, replyAll, forward }

/// What a search looks in: everything, or one field (a token before the text).
enum SearchScope { all, sender, subject }

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
    this.iconsDir,
    this.now,
    this.engineError,
    this.sampleData = false,
    this.openUrl,
    this.lastMailbox,
  });

  final MailService service;
  final String? iconsDir;

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
  bool _active = true;

  /// The list and the reader have content scrolled under the band.
  bool _listScrolled = false;
  bool _readerScrolled = false;
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

  /// Where the content starts: under the toolbar (and the banner, if there is one).
  double get _topInset =>
      toolbarHeight + (_hasBanner ? MailMetrics.bannerHeight : 0);

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

  /// The rows grouped by conversation, newest first: the newest message of each thread and
  /// all its messages (newest first).
  List<(MessageSummary, List<MessageSummary>)> get _threads {
    final byThread = <String, List<MessageSummary>>{};
    for (final r in _rows) {
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
    Process.run('xdg-open', [url]).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MailColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): () =>
            compose(ComposeKind.fresh),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () =>
            compose(ComposeKind.reply),
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          meta: true,
          shift: true,
        ): () =>
            compose(ComposeKind.replyAll),
        const SingleActivator(
          LogicalKeyboardKey.keyF,
          meta: true,
          shift: true,
        ): () =>
            compose(ComposeKind.forward),
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _startSearch,
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
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_sidebarShown)
                    SizedBox(
                      width: MailMetrics.sidebarWidth,
                      child: _sidebar(colors),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _content(colors)),
                        if (_suggesting && _query.text.trim().isNotEmpty)
                          Positioned(
                            top: toolbarHeight - 4,
                            right: 7,
                            width: MailMetrics.searchFieldWidth,
                            child: _suggestions(colors),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_compose case final request?)
                Positioned.fill(
                  child: ComposeSheet(
                    key: const ValueKey('composer'),
                    request: request,
                    service: _service,
                    onClose: () {
                      setState(() => _compose = null);
                      _focus.requestFocus();
                    },
                  ),
                ),
              if (_setup)
                Positioned.fill(
                  child: AccountSetup(
                    key: const ValueKey('account setup'),
                    service: _service,
                    onClose: () {
                      setState(() => _setup = false);
                      _focus.requestFocus();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The list and the reader, scrolling under the glass toolbar (mustache-spec R1.9: the
  /// measured veil over the band, the banner inside it). The list and the reader are two
  /// scrollables side by side, so each column draws its own 1 pt line under the band once it
  /// has scrolled (always in an inactive window, as for the toolbar line).
  // PROVISIONAL: the per-column line is not measured in ML-01 (the reference has one split
  // view scroll edge per pane, which this follows).
  Widget _content(MailColors colors) {
    final veil = ToolbarVeil.of(context);
    Widget line(bool scrolled, String key) => scrolled || !_active
        ? ColoredBox(key: ValueKey(key), color: veil.line)
        : const SizedBox.shrink();
    return Stack(
      children: [
        Positioned.fill(
          child: ScrollUnderToolbar(
            active: _active,
            veil: veil,
            showLine: false,
            toolbar: _toolbar(colors),
            header: _hasBanner ? _bannerBar(colors) : null,
            headerHeight: _hasBanner ? MailMetrics.bannerHeight : 0,
            body: (context, padding) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: MailMetrics.listWidth,
                  child: _scrollEdge(
                    (v) => _listScrolled = v,
                    () => _listScrolled,
                    _list(colors),
                  ),
                ),
                Container(width: 1, color: colors.separator),
                Expanded(
                  child: ColoredBox(
                    color: colors.reader,
                    child: _scrollEdge(
                      (v) => _readerScrolled = v,
                      () => _readerScrolled,
                      _reader(colors),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          top: _topInset,
          width: MailMetrics.listWidth,
          height: 1,
          child: line(_listScrolled, 'list line'),
        ),
        Positioned(
          left: MailMetrics.listWidth + 1,
          right: 0,
          top: _topInset,
          height: 1,
          child: line(_readerScrolled, 'reader line'),
        ),
      ],
    );
  }

  /// Follows whether the column's vertical scrollable has content above its top.
  Widget _scrollEdge(
    void Function(bool) set,
    bool Function() get,
    Widget child,
  ) {
    bool update(ScrollMetrics m, int depth) {
      if (depth != 0 || m.axis != Axis.vertical) return false;
      final scrolled = m.extentBefore > 0;
      if (scrolled != get()) setState(() => set(scrolled));
      return false;
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => update(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => update(n.metrics, n.depth),
        child: child,
      ),
    );
  }

  Widget _bannerBar(MailColors colors) => Container(
    key: const ValueKey('banner'),
    color: colors.banner,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _banner ?? l10n.sampleData,
            style: mailText(12, colors.secondary),
          ),
        ),
        if (_banner != null)
          GestureDetector(
            onTap: () => setState(() => _banner = null),
            child: Symbol(
              'xmark',
              color: colors.secondary,
              size: 12,
              iconsDir: widget.iconsDir,
              fallback: '×',
            ),
          ),
      ],
    ),
  );

  // MARK: sidebar

  /// The sidebar button (ML-01: 40 × 52 at x 164 of the sidebar; in the toolbar when hidden).
  Widget _sidebarToggle() => ToolbarScope(
    active: _active,
    child: ToolbarCapsule(
      key: const ValueKey('sidebar toggle'),
      children: [
        ToolbarSegment(
          width: MailMetrics.sidebarToggleWidth - 2,
          onTap: () => setState(() => _sidebarShown = !_sidebarShown),
          icon: (color) => Symbol(
            'sidebar',
            color: color,
            iconsDir: widget.iconsDir,
            fallback: '▯',
          ),
        ),
      ],
    ),
  );

  Widget _sidebar(MailColors colors) {
    final children = <Widget>[
      // The top of the sidebar, under the window buttons, moves the window.
      SizedBox(
        height: toolbarHeight,
        child: Stack(
          children: [
            const Positioned.fill(
              child: WindowDragArea(child: SizedBox.expand()),
            ),
            Positioned(
              left: MailMetrics.sidebarToggleX,
              top: (toolbarHeight - toolbarCapsuleHeight) / 2,
              child: _sidebarToggle(),
            ),
          ],
        ),
      ),
    ];
    var first = true;
    for (final account in _accounts) {
      children.add(
        Container(
          height: MailMetrics.sidebarHeading,
          // PROVISIONAL: the gap above a section after the first (not measured).
          margin: EdgeInsets.only(top: first ? 0 : 10),
          padding: const EdgeInsets.only(left: MailMetrics.sidebarHeadingX),
          alignment: Alignment.centerLeft,
          child: Text(
            account.name.isNotEmpty ? account.name : account.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mailText(11, colors.sidebarHeading, weight: FontWeight.w600),
          ),
        ),
      );
      first = false;
      for (final m in _mailboxes[account.id] ?? const <Mailbox>[]) {
        final chosen = m.id == _mailbox?.id && _searchText == null;
        children.add(
          GestureDetector(
            key: ValueKey('mailbox ${m.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectMailbox(m),
            child: SizedBox(
              height: MailMetrics.sidebarRow,
              child: Stack(
                children: [
                  if (chosen)
                    Positioned.fill(
                      left: MailMetrics.sidebarSelectionInset,
                      right: MailMetrics.sidebarSelectionInset,
                      child: DecoratedBox(
                        key: ValueKey('mailbox selection ${m.id}'),
                        decoration: BoxDecoration(
                          color: colors.sidebarSelection,
                          borderRadius: BorderRadius.circular(
                            MailMetrics.sidebarSelectionRadius,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: MailMetrics.sidebarIconX,
                    top: (MailMetrics.sidebarRow - 18) / 2,
                    child: Symbol(
                      _mailboxSymbol(m.role),
                      color: colors.thread,
                      iconsDir: widget.iconsDir,
                    ),
                  ),
                  Positioned(
                    left: MailMetrics.sidebarTitleX,
                    right: MailMetrics.sidebarCountEnd,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            mailboxName(m),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mailText(
                              13,
                              colors.text,
                              weight: chosen ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        if (m.unread > 0)
                          Semantics(
                            label: l10n.unreadCount(m.unread),
                            child: Text(
                              '${m.unread}',
                              key: ValueKey('unread ${m.id}'),
                              style: mailText(12, colors.secondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
    if (_accounts.isEmpty && !_loading) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(18),
          child: GestureDetector(
            key: const ValueKey('add account'),
            onTap: () => setState(() => _setup = true),
            child: Text(l10n.addAccount, style: mailText(13, colors.link)),
          ),
        ),
      );
    }
    return ColoredBox(
      key: const ValueKey('sidebar'),
      color: colors.sidebar,
      child: ListView(padding: EdgeInsets.zero, children: children),
    );
  }

  static String _mailboxSymbol(MailboxRole role) => switch (role) {
    MailboxRole.inbox => 'tray',
    MailboxRole.drafts => 'doc',
    MailboxRole.sent => 'paperplane',
    MailboxRole.archive => 'archive',
    MailboxRole.junk => 'xmark',
    MailboxRole.trash => 'trash',
    MailboxRole.other => 'folder',
  };

  // MARK: toolbar

  /// Below this width the search field becomes a button (PROVISIONAL threshold; the reference
  /// collapses the toolbar into an overflow button at the minimum window).
  static const double _searchFieldMinToolbar = 900;

  Mailbox? _roleBox(MailboxRole role) =>
      _mailboxes[_mailbox?.account]?.where((m) => m.role == role).firstOrNull;

  Future<void> _junk() async {
    final row = _selectedRow;
    final junk = _roleBox(MailboxRole.junk);
    if (row == null || junk == null) return;
    await _guard(() => _service.move([row.id], junk.id));
  }

  Widget _toolbar(MailColors colors) {
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
    final hasMessage = _conversation.isNotEmpty;
    Widget Function(Color) icon(String name, String fallback) =>
        (color) => Symbol(
          name,
          color: color,
          iconsDir: widget.iconsDir,
          fallback: fallback,
        );
    return ToolbarScope(
      active: _active,
      child: WindowDragArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _searchFieldMinToolbar;
            return SizedBox(
              key: const ValueKey('toolbar'),
              height: toolbarHeight,
              child: Row(
                children: [
                  if (!_sidebarShown) ...[
                    const SizedBox(width: MailMetrics.windowButtonsEnd),
                    _sidebarToggle(),
                  ],
                  const SizedBox(width: 12),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MailMetrics.titleBlockWidth,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            key: const ValueKey('title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mailText(
                              15,
                              _active
                                  ? ToolbarColors.of(context).title
                                  : ToolbarColors.of(context).titleInactive,
                              weight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            subtitle,
                            key: const ValueKey('subtitle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mailText(11, colors.secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  ToolbarCapsule(
                    key: const ValueKey('compose'),
                    children: [
                      ToolbarSegment(
                        width: 38,
                        onTap: () => compose(ComposeKind.fresh),
                        icon: icon('compose', '✎'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // ML-01: one capsule of 119 (38 / 40 / 39).
                  ToolbarCapsule(
                    key: const ValueKey('reply group'),
                    separators: true,
                    children: [
                      ToolbarSegment(
                        key: const ValueKey('reply'),
                        width: 38,
                        enabled: hasMessage,
                        onTap: () => compose(ComposeKind.reply),
                        icon: icon('reply', '↩'),
                      ),
                      ToolbarSegment(
                        key: const ValueKey('reply all'),
                        width: 40,
                        enabled: hasMessage,
                        onTap: () => compose(ComposeKind.replyAll),
                        icon: icon('reply-all', '⇇'),
                      ),
                      ToolbarSegment(
                        key: const ValueKey('forward'),
                        width: 39,
                        enabled: hasMessage,
                        onTap: () => compose(ComposeKind.forward),
                        icon: icon('forward', '↪'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // ML-01: one capsule of 121 (38 / 35 / 42).
                  ToolbarCapsule(
                    separators: true,
                    children: [
                      ToolbarSegment(
                        key: const ValueKey('archive'),
                        width: 38,
                        // Disabled, not silent, without an Archive mailbox.
                        enabled:
                            hasMessage && _roleBox(MailboxRole.archive) != null,
                        onTap: _archive,
                        icon: icon('archive', '▤'),
                      ),
                      ToolbarSegment(
                        key: const ValueKey('delete'),
                        width: 35,
                        enabled: hasMessage,
                        onTap: _delete,
                        icon: icon('trash', '✕'),
                      ),
                      ToolbarSegment(
                        key: const ValueKey('junk'),
                        width: 42,
                        enabled:
                            hasMessage && _roleBox(MailboxRole.junk) != null,
                        onTap: _junk,
                        icon: icon('xmark', '⊘'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  ToolbarCapsule(
                    children: [
                      ToolbarSegment(
                        key: const ValueKey('flag'),
                        width: 38,
                        enabled: hasMessage,
                        chosen: _selectedRow?.flagged ?? false,
                        onTap: _toggleFlag,
                        icon: icon('flag', '⚑'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  if (wide || _searching)
                    _searchField(colors)
                  else
                    ToolbarCapsule(
                      key: const ValueKey('search'),
                      children: [
                        ToolbarSegment(
                          width: toolbarCapsuleHeight - 2,
                          onTap: _startSearch,
                          icon: icon('search', '⌕'),
                        ),
                      ],
                    ),
                  const SizedBox(width: 7),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The search field (ML-01: 299 × 38, magnifier and placeholder; a scope token before the
  /// text after choosing a suggestion).
  Widget _searchField(MailColors colors) {
    final focused = _queryFocus.hasFocus;
    final token = _searchText != null && _scope != SearchScope.all;
    return GestureDetector(
      onTap: _startSearch,
      child: Container(
        key: const ValueKey('search field'),
        width: MailMetrics.searchFieldWidth,
        height: toolbarCapsuleHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: colors.field,
          borderRadius: BorderRadius.circular(toolbarCapsuleHeight / 2),
          border: Border.all(
            color: focused ? colors.unread : colors.separator,
            width: focused ? 2 : 1,
          ),
        ),
        child: Focus(
          onFocusChange: (_) => setState(() {}),
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              _endSearch();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            children: [
              Symbol(
                'search',
                color: colors.secondary,
                size: 15,
                iconsDir: widget.iconsDir,
                fallback: '⌕',
              ),
              const SizedBox(width: 6),
              if (token) ...[_scopeToken(colors), const SizedBox(width: 4)],
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_query.text.isEmpty)
                      IgnorePointer(
                        child: Text(
                          l10n.search,
                          style: mailText(13, colors.tertiary),
                        ),
                      ),
                    EditableText(
                      controller: _query,
                      focusNode: _queryFocus,
                      style: mailText(13, colors.text),
                      cursorColor: colors.text,
                      backgroundCursorColor: colors.text,
                      maxLines: 1,
                      onChanged: (text) => setState(() {
                        _searching = true;
                        _suggesting = text.trim().isNotEmpty;
                      }),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ],
                ),
              ),
              if (_query.text.isNotEmpty)
                GestureDetector(
                  key: const ValueKey('search clear'),
                  onTap: _endSearch,
                  child: Symbol(
                    'xmark',
                    color: colors.tertiary,
                    size: 12,
                    iconsDir: widget.iconsDir,
                    fallback: '×',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The scope token in the search field: a small grey capsule with the field's name in
  /// capitals and a chevron (size and colours PROVISIONAL: the token measured in Mustache).
  Widget _scopeToken(MailColors colors) => Container(
    key: const ValueKey('search token'),
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: colors.inactiveSelection,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      '${(_scope == SearchScope.sender ? l10n.tokenSender : l10n.tokenSubject).toUpperCase()} ⌄',
      style: mailText(10, colors.text, weight: FontWeight.w600),
    ),
  );

  /// The suggestions under the search field while typing: the text itself, then the text in
  /// one field.
  Widget _suggestions(MailColors colors) {
    final text = _query.text.trim();
    Widget item(String key, String label, SearchScope scope) => GestureDetector(
      key: ValueKey(key),
      behavior: HitTestBehavior.opaque,
      onTap: () => _runSearch(scope),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: mailText(13, colors.text),
        ),
      ),
    );
    // PROVISIONAL panel: the in-window menu look (ML-01 shows a menu under the field).
    return Container(
      key: const ValueKey('search suggestions'),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.separator),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          item('suggest all', text, SearchScope.all),
          item(
            'suggest sender',
            '${l10n.senderContains} $text',
            SearchScope.sender,
          ),
          item(
            'suggest subject',
            '${l10n.subjectContains} $text',
            SearchScope.subject,
          ),
        ],
      ),
    );
  }

  // MARK: list

  /// `text` with the search matches on a yellow background.
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

  Widget _list(MailColors colors) {
    final threads = _threads;
    if (threads.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: _topInset),
        child: Center(
          child: Text(
            _searchText != null ? l10n.noResults : l10n.noMessages,
            key: const ValueKey('empty list'),
            style: mailText(14, colors.tertiary),
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('message list'),
      padding: EdgeInsets.only(top: _topInset),
      itemCount: threads.length,
      itemBuilder: (context, i) {
        final (head, members) = threads[i];
        final expanded =
            members.length > 1 && _expanded.contains(_threadKey(head));
        final nextChosen =
            i + 1 < threads.length && threads[i + 1].$1.id == _selected;
        final headRow = _row(
          colors,
          head,
          count: members.length,
          expanded: expanded,
          separator:
              !expanded &&
              head.id != _selected &&
              !nextChosen &&
              i != threads.length - 1,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!expanded) headRow,
            AnimatedSize(
              duration: expanded
                  ? MailMetrics.threadExpand
                  : MailMetrics.threadCollapse,
              // PROVISIONAL curve: only the duration was measured.
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Container(
                      key: ValueKey('thread block ${head.id}'),
                      margin: const EdgeInsets.symmetric(
                        horizontal: MailMetrics.selectionInset,
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

  /// A row of the list (ML-01: 80 pt; the cell is 276 wide at x 16).
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
    final secondary = onFill ? colors.selectionSecondary : colors.secondary;
    final blue = onFill ? colors.selectionText : colors.thread;
    // Inside an expanded block the block is already inset.
    final inset = inBlock ? 0.0 : MailMetrics.selectionInset;
    final cellX =
        MailMetrics.cellX - (inBlock ? MailMetrics.selectionInset : 0);
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
              Positioned.fill(
                left: inset,
                right: inset,
                child: DecoratedBox(
                  key: ValueKey('selection ${row.id}'),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(
                      MailMetrics.selectionRadius,
                    ),
                  ),
                ),
              ),
            if (row.unread)
              Positioned(
                left:
                    cellX +
                    MailMetrics.senderX -
                    MailMetrics.unreadDotBeforeSender -
                    MailMetrics.unreadDot / 2,
                // Centred on the sender's 18 pt line.
                top: MailMetrics.senderY + (18 - MailMetrics.unreadDot) / 2,
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
              left: cellX + MailMetrics.senderX,
              width: MailMetrics.cellWidth - MailMetrics.senderX,
              top: MailMetrics.senderY,
              height: 18,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _marked(
                      count > 1 ? _threadSenders(row) : row.from.display,
                      mailText(13, primary, weight: FontWeight.w600),
                      colors,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: MailMetrics.dateY - MailMetrics.senderY,
                      left: 6,
                    ),
                    child: Text(
                      mailbox == null
                          ? listDate(row.date, _now)
                          : '${mailboxName(mailbox)}  ${listDate(row.date, _now)}',
                      key: ValueKey('date ${row.id}'),
                      style: mailText(12, secondary),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: cellX + MailMetrics.senderX,
              width: MailMetrics.cellWidth - MailMetrics.senderX,
              top: MailMetrics.subjectY,
              height: 16,
              child: Row(
                children: [
                  Expanded(
                    child: _marked(row.subject, mailText(13, primary), colors),
                  ),
                  if (row.flagged)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Symbol(
                        'flag-fill',
                        color: onFill ? colors.selectionText : colors.flagged,
                        size: 11,
                        iconsDir: widget.iconsDir,
                        fallback: '⚑',
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
                        child: SizedBox(
                          // ML-01: the disclosure is 24 × 16.
                          height: 16,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 4),
                              Text('$count', style: mailText(12, blue)),
                              const SizedBox(width: 3),
                              Container(
                                width: 13,
                                height: 13,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: blue),
                                ),
                                child: Transform.rotate(
                                  angle: expanded ? 1.5708 : 0,
                                  child: Symbol(
                                    'chevron-right',
                                    color: blue,
                                    size: 8,
                                    iconsDir: widget.iconsDir,
                                    fallback: '›',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: cellX + MailMetrics.senderX,
              width: MailMetrics.cellWidth - MailMetrics.senderX,
              top: MailMetrics.summaryY,
              height: MailMetrics.summaryLine * 2,
              child: _marked(
                row.preview,
                mailText(12, secondary, height: MailMetrics.summaryLine / 12),
                colors,
                maxLines: 2,
              ),
            ),
            if (separator)
              Positioned(
                left: cellX + MailMetrics.senderX,
                width: MailMetrics.cellWidth - MailMetrics.senderX,
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

  /// A child of an expanded thread: sender and one summary line (~45 pt).
  Widget _childRow(MailColors colors, MessageSummary row) {
    final chosen = row.id == _selected;
    final fill = chosen
        ? (_active ? colors.selection : colors.inactiveSelection)
        : null;
    final onFill = chosen && _active;
    final primary = onFill ? colors.selectionText : colors.text;
    final secondary = onFill ? colors.selectionSecondary : colors.secondary;
    final x =
        MailMetrics.cellX - MailMetrics.selectionInset + MailMetrics.senderX;
    return GestureDetector(
      key: ValueKey('row ${row.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _focus.requestFocus();
        select(row.id, single: true);
      },
      child: Container(
        height: MailMetrics.threadChildRow,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(MailMetrics.selectionRadius),
        ),
        // PROVISIONAL: positions inside the child row (only its height was measured).
        padding: EdgeInsets.fromLTRB(x, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.from.display,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mailText(13, primary, weight: FontWeight.w600),
                  ),
                ),
                Text(listDate(row.date, _now), style: mailText(12, secondary)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              row.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mailText(12, secondary),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: reader

  Widget _reader(MailColors colors) {
    if (_engineError case final error?) {
      return Padding(
        padding: EdgeInsets.only(top: _topInset),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.engineUnavailable,
                  key: const ValueKey('engine unavailable'),
                  textAlign: TextAlign.center,
                  style: mailText(17, colors.text, weight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.engineUnavailableHint,
                  textAlign: TextAlign.center,
                  style: mailText(13, colors.secondary),
                ),
                const SizedBox(height: 6),
                Text(
                  error,
                  key: const ValueKey('engine error'),
                  textAlign: TextAlign.center,
                  style: mailText(11, colors.tertiary),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  key: const ValueKey('engine retry'),
                  onTap: _retrying ? null : retryEngine,
                  child: Text(
                    _retrying ? l10n.engineStarting : l10n.tryAgain,
                    style: mailText(
                      13,
                      _retrying ? colors.tertiary : colors.link,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_accounts.isEmpty && !_loading) {
      return Padding(
        padding: EdgeInsets.only(top: _topInset),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.noAccounts,
                key: const ValueKey('no accounts'),
                style: mailText(17, colors.text, weight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(l10n.noAccountsHint, style: mailText(13, colors.secondary)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () => setState(() => _setup = true),
                child: Text(l10n.addAccount, style: mailText(13, colors.link)),
              ),
            ],
          ),
        ),
      );
    }
    if (_conversation.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: _topInset),
        child: Center(
          child: Text(
            l10n.noSelection,
            key: const ValueKey('no selection'),
            // ML-01: large light grey text.
            style: mailText(22, colors.tertiary),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('reader'),
      // PROVISIONAL: the margin around the cards (the 8 pt gap between cards is measured).
      padding: EdgeInsets.fromLTRB(
        MailMetrics.cardGap,
        _topInset,
        MailMetrics.cardGap,
        MailMetrics.cardGap,
      ),
      children: [
        SizedBox(
          height: MailMetrics.readerHeader,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.messageCount(_conversation.length),
                key: const ValueKey('reader count'),
                style: mailText(11, colors.secondary),
              ),
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
      MediaQuery.maybePlatformBrightnessOf(context) == Brightness.dark;

  /// HTML mail keeps its white page in the dark appearance (ML-01b), as the sender designed
  /// it; plain text follows the appearance. The page's padding and corners are PROVISIONAL.
  Widget _htmlPage(Widget body) => _darkAppearance
      ? Container(
          key: const ValueKey('html page'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: body,
        )
      : body;

  Widget _message(MailColors colors, Message m) {
    final allowed = _remoteAllowed.contains(m.id);
    final html = m.html.trim();
    final remote =
        html.isNotEmpty && (m.remoteContent || hasRemoteContent(html));
    String names(List<Address> list) => list.map((a) => a.display).join(', ');
    final body = mailText(13.5, colors.text, height: 1.45);
    return Container(
      key: ValueKey('card ${m.id}'),
      padding: const EdgeInsets.all(MailMetrics.cardPadding),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(MailMetrics.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: MailMetrics.avatar,
                height: MailMetrics.avatar,
                alignment: Alignment.center,
                // PROVISIONAL gradient: "gray-blue" in ML-01.
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFA3ADBC), Color(0xFF7D8798)],
                  ),
                ),
                child: Text(
                  initials(m.from),
                  style: mailText(
                    13,
                    const Color(0xFFFFFFFF),
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.from.display,
                      style: mailText(13, colors.text, weight: FontWeight.w600),
                    ),
                    Text(
                      m.subject,
                      key: ValueKey('subject ${m.id}'),
                      style: mailText(13, colors.text),
                    ),
                    if (m.to.isNotEmpty)
                      Text(
                        '${l10n.to}: ${names(m.to)}',
                        style: mailText(12, colors.secondary),
                      ),
                    if (m.cc.isNotEmpty)
                      Text(
                        '${l10n.cc}: ${names(m.cc)}',
                        style: mailText(12, colors.secondary),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    readerDate(m.date, _now),
                    style: mailText(12, colors.secondary),
                  ),
                  if (m.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Symbol(
                        'paperclip',
                        color: colors.secondary,
                        size: 13,
                        iconsDir: widget.iconsDir,
                        fallback: '⌇',
                      ),
                    ),
                ],
              ),
            ],
          ),
          Padding(
            // PROVISIONAL: the space around the header separator.
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: colors.separator),
          ),
          if (remote && !allowed)
            Container(
              key: ValueKey('remote banner ${m.id}'),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: colors.banner,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.remoteContentBlocked,
                      style: mailText(12, colors.secondary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    key: ValueKey('load remote ${m.id}'),
                    onTap: () => setState(() => _remoteAllowed.add(m.id)),
                    child: Text(
                      l10n.loadRemoteContent,
                      style: mailText(12, colors.link, weight: FontWeight.w600),
                    ),
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
                    ? mailText(13.5, MailColors.light.text, height: 1.45)
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.banner,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Symbol(
                            'paperclip',
                            color: colors.secondary,
                            size: 13,
                            iconsDir: widget.iconsDir,
                            fallback: '⌇',
                          ),
                          const SizedBox(width: 6),
                          Text(a.name, style: mailText(12, colors.text)),
                          const SizedBox(width: 6),
                          Text(
                            fileSize(a.size),
                            style: mailText(11, colors.secondary),
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
