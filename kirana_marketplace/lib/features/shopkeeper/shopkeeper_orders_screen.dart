import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/run_guarded.dart';
import '../../data/models/order_item_model.dart';
import '../../data/repositories/order_repository.dart';
import '../authentication/auth_controller.dart';
import '../shared/widgets/empty_state.dart';

/// Where a shopkeeper sees incoming orders (placed via the customer
/// app), accepts or rejects them, advances their status, and sets the
/// delivery boy's phone number that the customer then sees in their
/// Orders tab.
class ShopkeeperOrdersScreen extends StatefulWidget {
  final String shopId;
  const ShopkeeperOrdersScreen({super.key, required this.shopId});

  @override
  State<ShopkeeperOrdersScreen> createState() => _ShopkeeperOrdersScreenState();
}

class _ShopkeeperOrdersScreenState extends State<ShopkeeperOrdersScreen> {
  late Future<List<OrderWithItems>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<OrderRepository>().getOrdersForShop(widget.shopId);
  }

  Future<void> _updateStatus(String orderId, String status) async {
    final userId = context.read<AuthController>().currentUser!.id;
    await runGuarded(
      context,
      () => context.read<OrderRepository>().updateOrderStatus(
            orderId,
            status,
            requestingUserId: userId,
          ),
      successMessage: 'Order updated.',
    );
    setState(_load);
  }

  Future<void> _setDeliveryBoyPhone(String orderId, String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final phone = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery boy phone'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '10-digit mobile number',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty || !mounted) return;

    final userId = context.read<AuthController>().currentUser!.id;
    await runGuarded(
      context,
      () => context.read<OrderRepository>().updateOrderStatus(
            orderId,
            AppConstants.orderStatusOutForDelivery,
            deliveryBoyPhone: phone,
            requestingUserId: userId,
          ),
      successMessage: 'Delivery details shared with the customer.',
    );
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
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
              subtitle: 'Orders customers place from your shop appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_load);
              await _future;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) => _OrderCard(
                order: orders[index],
                onUpdateStatus: _updateStatus,
                onSetDeliveryPhone: _setDeliveryBoyPhone,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderWithItems order;
  final void Function(String orderId, String status) onUpdateStatus;
  final void Function(String orderId, String? current) onSetDeliveryPhone;

  const _OrderCard({
    required this.order,
    required this.onUpdateStatus,
    required this.onSetDeliveryPhone,
  });

  Future<void> _callCustomer(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final o = order.order;
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
                  child: Text(o.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                TextButton.icon(
                  onPressed: () => _callCustomer(o.customerPhone),
                  icon: const Icon(Icons.call, size: 16),
                  label: Text(o.customerPhone),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...order.items.map((OrderItemModel item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    '${item.quantity} × ${item.productName} (${item.unit}) · '
                    '${Formatters.rupees(item.lineTotal)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                )),
            const Divider(height: 20),
            Row(
              children: [
                Text('Total: ${Formatters.rupees(o.totalAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(AppConstants.orderStatusLabel(o.status),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            _actionsFor(context, o.status, o.id, o.deliveryBoyPhone),
          ],
        ),
      ),
    );
  }

  Widget _actionsFor(
      BuildContext context, String status, String orderId, String? deliveryBoyPhone) {
    switch (status) {
      case AppConstants.orderStatusPlaced:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    onUpdateStatus(orderId, AppConstants.orderStatusRejected),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    onUpdateStatus(orderId, AppConstants.orderStatusAccepted),
                child: const Text('Accept'),
              ),
            ),
          ],
        );
      case AppConstants.orderStatusAccepted:
        return FilledButton.icon(
          onPressed: () =>
              onUpdateStatus(orderId, AppConstants.orderStatusPreparing),
          icon: const Icon(Icons.soup_kitchen_outlined, size: 18),
          label: const Text('Mark as Preparing'),
        );
      case AppConstants.orderStatusPreparing:
        return FilledButton.icon(
          onPressed: () => onSetDeliveryPhone(orderId, deliveryBoyPhone),
          icon: const Icon(Icons.delivery_dining, size: 18),
          label: const Text('Send Out for Delivery'),
        );
      case AppConstants.orderStatusOutForDelivery:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => onSetDeliveryPhone(orderId, deliveryBoyPhone),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit Delivery Phone'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () =>
                    onUpdateStatus(orderId, AppConstants.orderStatusDelivered),
                child: const Text('Mark Delivered'),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
