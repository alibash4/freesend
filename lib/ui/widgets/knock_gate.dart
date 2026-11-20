import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:free_send/services/transfer/doorbell.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/ui/widgets/knock_prompt.dart';

/// Answers sender knocks app-wide: the receive screen may not even be on
/// screen when one arrives, so the consent prompt lives above the shell and
/// queues overlapping knocks instead of stacking dialogs.
class KnockGate extends StatefulWidget {
  const KnockGate({super.key, required this.child});

  final Widget child;

  @override
  State<KnockGate> createState() => _KnockGateState();
}

class _KnockGateState extends State<KnockGate> {
  final _queue = Queue<Knock>();
  StreamSubscription<Knock>? _subscription;
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    _subscription = context.read<ReceiveController>().knocks.listen(_enqueue);
  }

  void _enqueue(Knock knock) {
    _queue.add(knock);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && mounted) {
        final knock = _queue.removeFirst();
        await presentKnockConsent(
            context, context.read<ReceiveController>(), knock);
      }
    } finally {
      _draining = false;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
