import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/billing_bloc.dart';
import '../../../shop/presentation/bloc/shop_bloc.dart';

class ZReportPage extends StatefulWidget {
  const ZReportPage({super.key});

  @override
  State<ZReportPage> createState() => _ZReportPageState();
}

class _ZReportPageState extends State<ZReportPage> {
  @override
  void initState() {
    super.initState();
    context.read<BillingBloc>().add(LoadDailySalesEvent(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre Z · Ventas del día'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<BillingBloc, BillingState>(
        builder: (context, state) {
          if (state.isDailySalesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.dailySales.isEmpty) {
            return const Center(
              child: Text('Todavía no hay ventas hoy.'),
            );
          }

          final activeSales = state.dailySales.where((s) => !s.voided).toList();
          final totalSales = activeSales.fold<double>(0, (sum, s) => sum + s.total);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL NETO:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        '\$${totalSales.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.dailySales.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final sale = state.dailySales[index];
                    final time = DateFormat('HH:mm').format(sale.date);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Venta #${sale.id.substring(0, 5)}',
                        style: TextStyle(
                          decoration:
                              sale.voided ? TextDecoration.lineThrough : null,
                          color: sale.voided ? Colors.grey : Colors.black87,
                        ),
                      ),
                      subtitle: Text(time),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '\$${sale.total.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: sale.voided
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: sale.voided ? Colors.grey : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (!sale.voided)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _confirmVoid(context, sale.id),
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: Text('ANULADA',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: BlocBuilder<ShopBloc, ShopState>(
                    builder: (context, shopState) {
                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: state.isPrinting || activeSales.isEmpty
                            ? null
                            : () {
                                if (shopState is ShopLoaded) {
                                  context.read<BillingBloc>().add(
                                      PrintZReportEvent(
                                          shopName: shopState.shop.name));
                                }
                              },
                        icon: const Icon(Icons.print),
                        label: const Text('IMPRIMIR CIERRE Z'),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmVoid(BuildContext context, String saleId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular venta'),
        content: const Text('¿Seguro que querés anular esta venta? No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () {
              context.read<BillingBloc>().add(VoidSaleEvent(saleId));
              Navigator.pop(context);
            },
            child: const Text('ANULAR', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
