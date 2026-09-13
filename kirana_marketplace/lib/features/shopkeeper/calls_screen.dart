import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/call_log_model.dart';
import '../../data/repositories/call_log_repository.dart';
import '../shared/widgets/empty_state.dart';

class CallsScreen extends StatefulWidget {
  final String shopId;
  const CallsScreen({super.key, required this.shopId});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  List<CallLogModel> _calls = [];
  bool _loading = true;
  static final _dateFmt = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final calls =
        await context.read<CallLogRepository>().getCallsForShop(widget.shopId);
    if (!mounted) return;
    setState(() {
      _calls = calls;
      _loading = false;
    });
  }

  String _groupLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _calls.isEmpty
              ? const EmptyState(
                  icon: Icons.call_outlined,
                  title: 'No calls yet',
                  subtitle:
                      "When a customer taps 'Call Shop' on your listing, it shows up here.",
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _calls.length,
                  itemBuilder: (context, index) {
                    final call = _calls[index];
                    final showHeader = index == 0 ||
                        _groupLabel(call.calledAtDateTime) !=
                            _groupLabel(_calls[index - 1].calledAtDateTime);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: EdgeInsets.only(
                                top: index == 0 ? 0 : 16, bottom: 8),
                            child: Text(
                              _groupLabel(call.calledAtDateTime),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ),
                        Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.background,
                              foregroundColor: AppColors.primary,
                              child: Icon(Icons.call_received),
                            ),
                            title: Text(call.callerLabel ?? 'Customer call'),
                            subtitle:
                                Text(_dateFmt.format(call.calledAtDateTime)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
    );
  }
}
