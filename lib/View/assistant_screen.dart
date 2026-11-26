import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';

import 'app_route_observer.dart';
import '../Services/assistant_history_repository.dart';
import '../Services/assistant_service.dart';

class _Msg {
  _Msg(this.text, {required this.fromUser, this.isError = false});
  String text;
  final bool fromUser;
  final bool isError;
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.initialPrompt,
    this.isActive = true,
  });

  final String? initialPrompt;
  final bool isActive;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> with RouteAware {
  static const _suggestions = [
    'Summarize my portfolio',
    'What is my biggest risk right now?',
    'Explain what a short position is',
    "How's the market today?",
  ];

  final AssistantService _service = AssistantService();
  AssistantHistoryRepository? _historyRepo;
  AssistantHistoryRepository get _historyRepository =>
      _historyRepo ??= AssistantHistoryRepository.instance;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  StreamSubscription<String>? _sub;
  Completer<void>? _replyDone;
  Future<void> _historyWrites = Future<void>.value();
  String? _historyUserId;
  int _chatGeneration = 0;
  bool _historyLoading = true;
  bool _clearingHistory = false;
  bool _busy = false;
  PageRoute<dynamic>? _subscribedRoute;
  int _historyRefreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeHistory();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        appRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant AssistantScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      unawaited(_refreshHistory());
    }
  }

  @override
  void didPopNext() {
    unawaited(_refreshHistory());
  }

  Future<void> _refreshHistory() async {
    if (!mounted || _busy || _historyLoading || _clearingHistory) return;
    final refreshGeneration = ++_historyRefreshGeneration;
    final chatGeneration = _chatGeneration;
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      await _historyWrites;
      if (userId == null) {
        if (_historyUserId != null &&
            mounted &&
            chatGeneration == _chatGeneration &&
            refreshGeneration == _historyRefreshGeneration) {
          setState(() {
            _historyUserId = null;
            _messages.clear();
          });
        }
        return;
      }
      final history = await _historyRepository.loadLast30(userId);
      if (!mounted ||
          chatGeneration != _chatGeneration ||
          refreshGeneration != _historyRefreshGeneration ||
          _busy ||
          _clearingHistory) {
        return;
      }
      setState(() {
        _historyUserId = userId;
        _messages
          ..clear()
          ..addAll(history.map((message) => _Msg(
                message.text,
                fromUser: message.role == 'user',
              )));
      });
      _scrollToEnd();
    } catch (error) {
      _showHistoryError('Could not refresh saved assistant history.', error);
    }
  }

  Future<void> _initializeHistory() async {
    var history = const <AssistantHistoryMessage>[];
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      _historyUserId = userId;
      if (userId != null) {
        history = await _historyRepository.loadLast30(userId);
        if (!mounted) return;
        setState(() {
          _messages.addAll(history.map((message) => _Msg(
                message.text,
                fromUser: message.role == 'user',
              )));
        });
      }
    } catch (error) {
      _showHistoryError('Could not load saved assistant history.', error);
    } finally {
      if (mounted) setState(() => _historyLoading = false);
    }

    final prompt = widget.initialPrompt;
    if (mounted && prompt != null && prompt.trim().isNotEmpty) {
      await _send(prompt: prompt);
    }
  }

  void _showHistoryError(String message, Object error) {
    debugPrint('Assistant history operation failed: $error');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveMessage(String role, String text, int generation) async {
    final userId = _historyUserId;
    if (userId == null) return;

    final write = _historyWrites.then((_) async {
      if (generation != _chatGeneration) return;
      await _historyRepository.addMessage(
        userId: userId,
        role: role,
        text: text,
      );
    });
    _historyWrites = write.catchError((Object error) {
      _showHistoryError('Could not save assistant history.', error);
    });
    await _historyWrites;
  }

  @override
  void dispose() {
    if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
    _sub?.cancel();
    final done = _replyDone;
    if (done != null && !done.isCompleted) done.complete();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  void _stopReply() {
    final subscription = _sub;
    if (subscription == null) return;
    _sub = null;
    unawaited(subscription.cancel());
    final done = _replyDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  Future<void> _copyMessage(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  void _retryLastMessage() {
    final userIndex = _messages.lastIndexWhere((message) => message.fromUser);
    if (userIndex < 0) return;
    final message = _messages[userIndex];
    _send(prompt: message.text, existingUserMessage: message);
  }

  Future<void> _send({String? prompt, _Msg? existingUserMessage}) async {
    final text = (prompt ?? _controller.text).trim();
    if (text.isEmpty || _busy || _historyLoading || _clearingHistory) return;
    _historyRefreshGeneration++;
    final generation = _chatGeneration;
    if (prompt == null) _controller.clear();

    if (existingUserMessage != null &&
        !_messages.contains(existingUserMessage)) {
      return;
    }

    final userMessage = existingUserMessage ?? _Msg(text, fromUser: true);
    final reply = _Msg('', fromUser: false);
    setState(() {
      _busy = true;
      if (existingUserMessage == null) {
        _messages.add(userMessage);
      } else {
        final userIndex = _messages.indexOf(existingUserMessage);
        _messages.removeRange(userIndex + 1, _messages.length);
      }
      _messages.add(reply);
    });
    _scrollToEnd();

    try {
      if (existingUserMessage == null) {
        await _saveMessage('user', text, generation);
      }
      if (!mounted || generation != _chatGeneration) return;

      if (!mounted || generation != _chatGeneration) return;
      final history = buildChatHistoryFromMessages(
        _messages
            .takeWhile((message) => !identical(message, userMessage))
            .map((message) => (
                  fromUser: message.fromUser,
                  text: message.text,
                  isError: message.isError,
                ))
            .toList(growable: false),
      );
      final done = Completer<void>();
      var streamErrored = false;
      var streamCompleted = false;
      _replyDone = done;
      _sub = _service
          .send(
            text,
            history: history,
            userId: _historyUserId,
          )
          .listen(
        (chunk) {
          if (!mounted || generation != _chatGeneration) return;
          setState(() => reply.text += chunk);
          _scrollToEnd();
        },
        onError: (Object e) {
          streamErrored = true;
          if (!done.isCompleted) done.complete();
          if (!mounted || generation != _chatGeneration) return;
          final errorMessage = e is AssistantException
              ? e.message
              : 'I couldn\'t get a response just now. Please try again shortly.';
          if (e is! AssistantException) {
            debugPrint('Unexpected assistant stream error: $e');
          }
          setState(() {
            if (reply.text.isEmpty) _messages.remove(reply);
            _messages.add(_Msg(
              errorMessage,
              fromUser: false,
              isError: true,
            ));
          });
        },
        onDone: () {
          streamCompleted = true;
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );
      if (mounted) setState(() {});
      await done.future;
      final wasStopped = _sub == null;
      if (identical(_replyDone, done)) _replyDone = null;
      _sub = null;
      if (mounted &&
          generation == _chatGeneration &&
          !wasStopped &&
          reply.text.isEmpty &&
          _messages.contains(reply)) {
        setState(() {
          _messages.remove(reply);
          _messages.add(_Msg("I couldn't generate an answer. Try rephrasing.",
              fromUser: false, isError: true));
        });
      }
      if (mounted &&
          generation == _chatGeneration &&
          reply.text.isNotEmpty &&
          _messages.contains(reply) &&
          !streamErrored &&
          (streamCompleted || wasStopped)) {
        await _saveMessage('assistant', reply.text, generation);
      }
    } finally {
      if (mounted && generation == _chatGeneration) {
        setState(() => _busy = false);
      }
      _scrollToEnd();
    }
  }

  Future<void> _clear() async {
    if (_clearingHistory) return;
    _historyRefreshGeneration++;
    _chatGeneration++;
    _stopReply();
    final userId = _historyUserId;
    setState(() {
      _messages.clear();
      _busy = false;
      _clearingHistory = true;
    });

    try {
      await _historyWrites;
      if (userId != null) await _historyRepository.deleteAll(userId);
    } catch (error) {
      _showHistoryError('Could not clear assistant history.', error);
    } finally {
      if (mounted) setState(() => _clearingHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              icon: const Icon(Icons.refresh),
              onPressed: _clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 40, color: scheme.primary),
                          const SizedBox(height: 12),
                          Text('Ask about your portfolio or the market',
                              style: text.titleMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final s in _suggestions)
                                ActionChip(
                                  label: Text(s),
                                  onPressed: _historyLoading || _clearingHistory
                                      ? null
                                      : () => _send(prompt: s),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final bg = m.fromUser
                          ? scheme.primaryContainer
                          : m.isError
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest;
                      final fg = m.fromUser
                          ? scheme.onPrimaryContainer
                          : m.isError
                              ? scheme.onErrorContainer
                              : scheme.onSurface;
                      final markdownTextStyle =
                          text.bodyMedium?.copyWith(color: fg);
                      return Align(
                        alignment: m.fromUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: m.text.isEmpty
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : m.fromUser
                                  ? SelectableText(
                                      m.text,
                                      style:
                                          text.bodyMedium?.copyWith(color: fg),
                                    )
                                  : m.isError
                                      ? Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SelectableText(
                                              m.text,
                                              style: text.bodyMedium
                                                  ?.copyWith(color: fg),
                                            ),
                                            TextButton.icon(
                                              onPressed: _busy
                                                  ? null
                                                  : _retryLastMessage,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Retry'),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            MarkdownBody(
                                              data: m.text,
                                              selectable: true,
                                              styleSheet: MarkdownStyleSheet(
                                                a: markdownTextStyle?.copyWith(
                                                    decoration: TextDecoration
                                                        .underline),
                                                p: markdownTextStyle,
                                                code:
                                                    markdownTextStyle?.copyWith(
                                                        fontFamily:
                                                            'monospace'),
                                                h1: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                h2: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                h3: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                h4: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                h5: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                h6: markdownTextStyle?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                                em: markdownTextStyle?.copyWith(
                                                    fontStyle:
                                                        FontStyle.italic),
                                                strong:
                                                    markdownTextStyle?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                del:
                                                    markdownTextStyle?.copyWith(
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough),
                                                blockquote: markdownTextStyle,
                                                listBullet: markdownTextStyle,
                                                tableHead:
                                                    markdownTextStyle?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold),
                                                tableBody: markdownTextStyle,
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _copyMessage(m.text),
                                              icon: const Icon(Icons.copy),
                                              label: const Text('Copy'),
                                            ),
                                          ],
                                        ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'AI-generated, may be inaccurate. Demo app, not financial advice.',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_busy && !_historyLoading && !_clearingHistory,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 600,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask the assistant…',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: _historyLoading || _clearingHistory
                        ? 'Loading chat history'
                        : _busy
                            ? _sub == null
                                ? 'Preparing reply'
                                : 'Stop reply'
                            : 'Send',
                    onPressed: _busy
                        ? (_sub == null ? null : _stopReply)
                        : (_historyLoading || _clearingHistory ? null : _send),
                    icon: _busy || _historyLoading || _clearingHistory
                        ? _sub == null
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.stop)
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
