import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/order_item_model.dart';
import '../../data/repositories/order_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/empty_state.dart';

/// What each customer ordered, plus the current order's live delivery
/// status and the delivery boy's phone once the shopkeeper sets it.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<OrderWithItems>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final customerId = context.read<AuthController>().currentUser!.id;
    _future = context.read<OrderRepository>().getOrdersForCustomer(customerId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: FutureBuilder<List<OrderWithItems>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Orders you place from a shop will show up here.',
            );
          }
          final current = orders.where((o) => o.order.isActive).toList();
          final past = orders.where((o) => !o.order.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (current.isNotEmpty) ...[
                  const _SectionHeader('Current Orders'),
                  ...current.map((o) => _OrderCard(order: o)),
                  const SizedBox(height: 20),
                ],
                if (past.isNotEmpty) ...[
                  const _SectionHeader('Order History'),
                  ...past.map((o) => _OrderCard(order: o)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderWithItems order;
  const _OrderCard({required this.order});

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.orderStatusDelivered:
        return AppColors.success;
      case AppConstants.orderStatusRejected:
      case AppConstants.orderStatusCancelled:
        return AppColors.danger;
      case AppConstants.orderStatusPlaced:
        return AppColors.pending;
      default:
        return AppColors.accent;
    }
  }

  Future<void> _callDeliveryBoy(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final o = order.order;
    final statusColor = _statusColor(o.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(o.shopName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppConstants.orderStatusLabel(o.status),
                    style: TextStyle(
                        color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map((OrderItemModel item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${item.quantity} × ${item.productName} (${item.unit})',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                )),
            const Divider(height: 20),
            Row(
              children: [
                Text('Total: ${Formatters.rupees(o.totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            if (o.deliveryBoyPhone != null && o.deliveryBoyPhone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.delivery_dining, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Delivery: ${o.deliveryBoyPhone}',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _callDeliveryBoy(o.deliveryBoyPhone!),
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text('Call'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
