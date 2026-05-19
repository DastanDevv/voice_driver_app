import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/semantic/semantic_command_runner.dart';
import '../../../../core/voice/voice_command_coordinator.dart';
import '../../../../core/voice/voice_feedback.dart';
import '../../domain/chat_message.dart';
import '../cubit/chat_cubit.dart';
import '../cubit/chat_state.dart';

/// Экран чат-диалога: пользователь видит свои фразы и ответы ассистента
/// в виде пузырей сообщений, как в мессенджере.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.commandRunner,
    required this.voiceCoordinator,
  });

  final SemanticCommandRunner commandRunner;
  final VoiceCommandCoordinator voiceCoordinator;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    widget.voiceCoordinator.listening.addListener(_onListeningChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(jump: true));
  }

  void _onListeningChanged() {
    final listening = widget.voiceCoordinator.listening.value;
    if (listening) {
      if (!_pulseController.isAnimating) {
        unawaited(_pulseController.repeat(reverse: true));
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.voiceCoordinator.listening.removeListener(_onListeningChanged);
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(pos);
    } else {
      _scrollController.animateTo(
        pos,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _sendTyped() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    _inputController.clear();
    await _processUserText(text);
  }

  Future<void> _processUserText(String text) async {
    final cubit = context.read<ChatCubit>();
    cubit.appendUserMessage(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final outcomes = await widget.commandRunner.run(text);
    if (!mounted) return;
    if (outcomes.isEmpty) {
      cubit.appendAssistantMessage(VoiceFeedback.phraseFor('unknown'));
    } else {
      for (final o in outcomes) {
        final phrase = VoiceFeedback.phraseForResult(o.execution);
        cubit.appendAssistantMessage(phrase, command: o.command);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final listening = widget.voiceCoordinator.listening.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Диалог'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Очистить диалог',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить диалог?'),
                  content: const Text('История переписки будет удалена.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () {
                        context.read<ChatCubit>().clear();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Очистить'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: BlocConsumer<ChatCubit, ChatState>(
                listener: (context, state) {
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());
                },
                builder: (context, state) {
                  if (state.messages.isEmpty) {
                    return _EmptyChat(
                      onTryPhrase: (p) => _processUserText(p),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    itemCount: state.messages.length +
                        (state.assistantTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (state.assistantTyping &&
                          index == state.messages.length) {
                        return const _TypingBubble();
                      }
                      final msg = state.messages[index];
                      final prev = index > 0 ? state.messages[index - 1] : null;
                      final showHeader = prev == null || prev.role != msg.role;
                      return _MessageBubble(
                        message: msg,
                        showHeader: showHeader,
                      );
                    },
                  );
                },
              ),
            ),
            _ChatInputBar(
              controller: _inputController,
              onSend: _sendTyped,
              onMicDown: () =>
                  unawaited(widget.voiceCoordinator.handlePointerDown()),
              onMicUp: () =>
                  unawaited(widget.voiceCoordinator.handlePointerUp()),
              listening: listening,
              pulse: _pulseController,
              partial: widget.voiceCoordinator.partialTranscript,
              scheme: scheme,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onTryPhrase});

  final void Function(String phrase) onTryPhrase;

  static const _suggestions = [
    'Создай задачу подготовить презентацию на завтра',
    'Покажи важные задачи',
    'Сколько задач?',
    'Открой аналитику',
    'Включи тёмную тему',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Поговорим?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Опишите задачу или попросите помощь голосом — '
          'ассистент разберёт фразу через семантическое дерево '
          'и выполнит команду.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'ПОПРОБУЙТЕ',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTryPhrase(s),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: scheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          s,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.send_rounded,
                        color: scheme.outline,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.showHeader});

  final ChatMessage message;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.role == ChatRole.user;
    final isAssistant = message.role == ChatRole.assistant;

    final bubbleColor = isUser
        ? scheme.primary
        : isAssistant
            ? scheme.surfaceContainerHigh
            : scheme.tertiaryContainer;
    final textColor = isUser
        ? scheme.onPrimary
        : isAssistant
            ? scheme.onSurface
            : scheme.onTertiaryContainer;

    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
          );

    final children = <Widget>[];
    if (showHeader) {
      children.add(
        Padding(
          padding: EdgeInsets.only(
            top: 4,
            bottom: 6,
            left: isUser ? 0 : 44,
            right: isUser ? 8 : 0,
          ),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _AssistantAvatar(scheme: scheme),
                const SizedBox(width: 8),
              ],
              Text(
                isUser ? 'Вы' : 'Ассистент',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(message.at),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    children.add(
      Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser && !showHeader) const SizedBox(width: 44),
          Flexible(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        height: 1.35,
                      ),
                    ),
                    if (isAssistant && message.intentCode != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _IntentChip(
                            label: message.intentCode!,
                            confidence: message.confidence,
                          ),
                          if ((message.confidence ?? 0) > 0)
                            _ConfidenceBadge(
                              confidence: message.confidence!,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 16,
      ),
    );
  }
}

class _IntentChip extends StatelessWidget {
  const _IntentChip({required this.label, this.confidence});
  final String label;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = confidence >= 0.9
        ? const Color(0xFF16A34A)
        : confidence >= 0.6
            ? const Color(0xFFEA580C)
            : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${(confidence * 100).round()}%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();
  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _AssistantAvatar(scheme: scheme),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_c.value + i * 0.2) % 1.0;
                    final s = 0.4 + 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: s,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.onSend,
    required this.onMicDown,
    required this.onMicUp,
    required this.listening,
    required this.pulse,
    required this.partial,
    required this.scheme,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onMicDown;
  final VoidCallback onMicUp;
  final bool listening;
  final AnimationController pulse;
  final ValueNotifier<String> partial;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (listening)
            ValueListenableBuilder<String>(
              valueListenable: partial,
              builder: (context, text, _) {
                if (text.isEmpty) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                );
              },
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: 'Напишите команду…',
                    filled: true,
                    fillColor:
                        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: scheme.primary, width: 1.5),
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) => onMicDown(),
                onPointerUp: (_) => onMicUp(),
                onPointerCancel: (_) => onMicUp(),
                child: AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    final s = 1 + 0.08 * (listening ? pulse.value : 0);
                    return Transform.scale(scale: s, child: child);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: listening
                            ? [scheme.error, scheme.tertiary]
                            : [scheme.primary, scheme.tertiary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (listening ? scheme.error : scheme.primary)
                              .withValues(alpha: 0.4),
                          blurRadius: listening ? 18 : 10,
                          spreadRadius: listening ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Отправить',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
