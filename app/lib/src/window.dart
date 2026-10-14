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

class MailWindow extends StatefulWidget {
  const MailWindow({
    super.key,
    required this.service,
    this.iconsDir,
    this.now,
    this.engineMissing = false,
    this.openUrl,
  });

  final MailService service;
  final String? iconsDir;

  /// The current time (tests); null: the clock.
  final DateTime Function()? now;

  /// The engine is not on the bus: the window shows sample mail and says so.
  final bool engineMissing;

  /// Opens a link with the system (tests replace it); null: `xdg-open`.
  final ValueChanged<String>? openUrl;

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
  bool _searching = false;
  bool _active = true;
  bool _loading = true;
  String? _banner;
  ComposeRequest? _compose;
  bool _setup = false;

  bool get _hasBanner => widget.engineMissing || _banner != null;

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
    _loadAccounts();
  }

  @override
  void dispose() {
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
      _accounts = accounts;
      _mailboxes
        ..clear()
        ..addAll(boxes);
      _loading = false;
      final current = _mailbox;
      final still = current == null
          ? null
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

  /// The rows grouped by conversation, newest first: one row per thread.
  List<(MessageSummary, int)> get _threads {
    final byThread = <String, List<MessageSummary>>{};
    for (final r in _rows) {
      byThread.putIfAbsent(r.thread.isEmpty ? r.id : r.thread, () => []).add(r);
    }
    final out = [
      for (final list in byThread.values)
        ((list..sort((a, b) => b.date.compareTo(a.date))).first, list.length),
    ]..sort((a, b) => b.$1.date.compareTo(a.$1.date));
    return out;
  }

  Future<void> select(String id) => _guard(() async {
    final row = _rows.where((r) => r.id == id).firstOrNull;
    if (row == null) return;
    setState(() => _selected = id);
    final thread = row.thread.isEmpty ? row.id : row.thread;
    final members =
        _rows
            .where((r) => (r.thread.isEmpty ? r.id : r.thread) == thread)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
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
      await _service.setFlags(unread, add: {MessageFlag.seen});
    }
  });

  MessageSummary? get _selectedRow =>
      _rows.where((r) => r.id == _selected).firstOrNull;

  Future<void> _selectMailbox(Mailbox m) async {
    setState(() {
      _mailbox = m;
      _searchText = null;
      _searching = false;
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
    final threads = _threads;
    if (threads.isNotEmpty && next >= 0) {
      await select(threads[next.clamp(0, threads.length - 1)].$1.id);
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

  Future<void> _runSearch() async {
    final text = _query.text.trim();
    setState(() {
      _searchText = text.isEmpty ? null : text;
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
      _searchText = null;
    });
    _focus.requestFocus();
    await _loadRows();
  }

  void _moveSelection(int delta) {
    final threads = _threads;
    if (threads.isEmpty) return;
    final at = threads.indexWhere((t) => t.$1.id == _selected);
    final next = (at < 0 ? (delta > 0 ? 0 : threads.length - 1) : at + delta)
        .clamp(0, threads.length - 1);
    select(threads[next].$1.id);
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
                  SizedBox(
                    width: MailMetrics.sidebarWidth,
                    child: _sidebar(colors),
                  ),
                  Expanded(
                    // The toolbar floats above the content, which starts under it (top
                    // inset) so it can later scroll under a glass toolbar.
                    // TODO(silica-linux/silica-ui#2): use the shared glass toolbar with the
                    // measured veil (mustache-spec R1.9) and let the lists scroll under it.
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: MailMetrics.listWidth,
                                child: _list(colors),
                              ),
                              Container(width: 1, color: colors.separator),
                              Expanded(child: _reader(colors)),
                            ],
                          ),
                        ),
                        if (_hasBanner)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: toolbarHeight,
                            height: MailMetrics.bannerHeight,
                            child: _bannerBar(colors),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: toolbarHeight,
                          child: ColoredBox(
                            color: colors.content,
                            child: _toolbar(colors),
                          ),
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

  Widget _bannerBar(MailColors colors) => Container(
    key: const ValueKey('banner'),
    color: colors.banner,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _banner ?? l10n.engineMissing,
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

  Widget _sidebar(MailColors colors) {
    final children = <Widget>[
      // The top of the sidebar, under the window buttons, moves the window.
      const SizedBox(
        height: toolbarHeight,
        child: WindowDragArea(child: SizedBox.expand()),
      ),
    ];
    for (final account in _accounts) {
      children.add(
        SizedBox(
          height: MailMetrics.sidebarHeading,
          child: Padding(
            padding: const EdgeInsets.only(left: 18, top: 10),
            child: Text(
              account.name.isNotEmpty ? account.name : account.address,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mailText(11, colors.tertiary, weight: FontWeight.w600),
            ),
          ),
        ),
      );
      for (final m in _mailboxes[account.id] ?? const <Mailbox>[]) {
        final chosen = m.id == _mailbox?.id && _searchText == null;
        children.add(
          GestureDetector(
            key: ValueKey('mailbox ${m.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectMailbox(m),
            child: Container(
              height: MailMetrics.sidebarRow,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: chosen ? colors.sidebarSelection : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Symbol(
                    _mailboxSymbol(m.role),
                    color: colors.unread,
                    size: 16,
                    iconsDir: widget.iconsDir,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mailboxName(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mailText(13, colors.text),
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

  Widget _toolbar(MailColors colors) {
    final mailbox = _mailbox;
    final title = _searchText != null
        ? l10n.searchResults(_searchText!)
        : mailbox == null
        ? l10n.appTitle
        : mailboxName(mailbox);
    final count = _threads.length;
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
        child: SizedBox(
          key: const ValueKey('toolbar'),
          height: toolbarHeight,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
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
                      l10n.messageCount(count),
                      style: mailText(11, colors.secondary),
                    ),
                  ],
                ),
              ),
              ToolbarCapsule(
                key: const ValueKey('compose'),
                children: [
                  ToolbarSegment(
                    width: toolbarCapsuleHeight - 2,
                    onTap: () => compose(ComposeKind.fresh),
                    icon: icon('compose', '✎'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
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
                    width: 38,
                    enabled: hasMessage,
                    onTap: () => compose(ComposeKind.replyAll),
                    icon: icon('reply-all', '⇇'),
                  ),
                  ToolbarSegment(
                    key: const ValueKey('forward'),
                    width: 38,
                    enabled: hasMessage,
                    onTap: () => compose(ComposeKind.forward),
                    icon: icon('forward', '↪'),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              ToolbarCapsule(
                separators: true,
                children: [
                  ToolbarSegment(
                    key: const ValueKey('archive'),
                    width: 38,
                    enabled: hasMessage,
                    onTap: _archive,
                    icon: icon('archive', '▤'),
                  ),
                  ToolbarSegment(
                    key: const ValueKey('delete'),
                    width: 38,
                    enabled: hasMessage,
                    onTap: _delete,
                    icon: icon('trash', '✕'),
                  ),
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
              if (_searching)
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
        ),
      ),
    );
  }

  Widget _searchField(MailColors colors) => Container(
    key: const ValueKey('search field'),
    width: 220,
    height: toolbarCapsuleHeight,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    alignment: Alignment.centerLeft,
    decoration: BoxDecoration(
      color: colors.field,
      borderRadius: BorderRadius.circular(toolbarCapsuleHeight / 2),
      border: Border.all(color: colors.unread, width: 2),
    ),
    child: Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _endSearch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (_query.text.isEmpty)
            IgnorePointer(
              child: Text(l10n.search, style: mailText(13, colors.tertiary)),
            ),
          EditableText(
            controller: _query,
            focusNode: _queryFocus,
            style: mailText(13, colors.text),
            cursorColor: colors.text,
            backgroundCursorColor: colors.text,
            maxLines: 1,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _runSearch(),
          ),
        ],
      ),
    ),
  );

  // MARK: list

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
      itemExtent: MailMetrics.listRow,
      itemBuilder: (context, i) {
        final (row, count) = threads[i];
        final chosen = row.id == _selected;
        final fill = chosen
            ? (_active ? colors.selection : colors.inactiveSelection)
            : null;
        final onFill = chosen && _active;
        final primary = onFill ? colors.selectionText : colors.text;
        final secondary = onFill ? colors.selectionSecondary : colors.secondary;
        return GestureDetector(
          key: ValueKey('row ${row.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focus.requestFocus();
            select(row.id);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            padding: const EdgeInsets.fromLTRB(22, 9, MailMetrics.listInset, 8),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              border: chosen || i == threads.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: colors.separator)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (row.unread)
                  Positioned(
                    left: -15,
                    top: 4,
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.from.display,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mailText(
                              13,
                              primary,
                              weight: row.unread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (count > 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              '$count',
                              style: mailText(11, secondary),
                            ),
                          ),
                        if (row.flagged)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Symbol(
                              'flag-fill',
                              color: onFill
                                  ? colors.selectionText
                                  : colors.flagged,
                              size: 11,
                              iconsDir: widget.iconsDir,
                              fallback: '⚑',
                            ),
                          ),
                        if (row.attachments > 0)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Symbol(
                              'paperclip',
                              color: secondary,
                              size: 11,
                              iconsDir: widget.iconsDir,
                              fallback: '⌇',
                            ),
                          ),
                        Text(
                          listDate(row.date, _now),
                          style: mailText(11, secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      row.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mailText(12.5, primary),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Text(
                        row.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mailText(12, secondary, height: 1.25),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // MARK: reader

  Widget _reader(MailColors colors) {
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
            style: mailText(14, colors.tertiary),
          ),
        ),
      );
    }
    return ListView(
      key: const ValueKey('reader'),
      padding: EdgeInsets.fromLTRB(
        MailMetrics.readerPadding,
        _topInset + MailMetrics.readerPadding,
        MailMetrics.readerPadding,
        MailMetrics.readerPadding,
      ),
      children: [
        for (var i = 0; i < _conversation.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Container(height: 1, color: colors.separator),
            ),
          _message(colors, _conversation[i]),
        ],
      ],
    );
  }

  Widget _message(MailColors colors, Message m) {
    final allowed = _remoteAllowed.contains(m.id);
    final html = m.html.trim();
    final remote =
        html.isNotEmpty && (m.remoteContent || hasRemoteContent(html));
    String names(List<Address> list) => list.map((a) => a.display).join(', ');
    final body = mailText(13.5, colors.text, height: 1.45);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                m.from.display,
                style: mailText(15, colors.text, weight: FontWeight.w600),
              ),
            ),
            Text(
              readerDate(m.date, _now),
              style: mailText(11.5, colors.secondary),
            ),
          ],
        ),
        const SizedBox(height: MailMetrics.headerGap),
        Text(
          m.subject,
          key: ValueKey('subject ${m.id}'),
          style: mailText(13, colors.text, weight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
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
        const SizedBox(height: 14),
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
          HtmlBody(
            key: ValueKey('html ${m.id}'),
            html: html,
            style: body,
            linkColor: colors.link,
            quoteColor: colors.secondary,
            allowRemote: allowed,
            onLink: _openLink,
          )
        else
          Text(m.text, key: ValueKey('text ${m.id}'), style: body),
        if (m.attachments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.attachmentCount(m.attachments.length),
            style: mailText(11, colors.tertiary, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
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
