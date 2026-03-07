import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../../presentation/bloc/billing_bloc.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';

class ManualCatalogSheet extends StatefulWidget {
  const ManualCatalogSheet({super.key});

  @override
  State<ManualCatalogSheet> createState() => _ManualCatalogSheetState();
}

class _ManualCatalogSheetState extends State<ManualCatalogSheet> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    // Refresh products on open to ensure we have the latest list
    context.read<ProductBloc>().add(LoadProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 16,
        right: 16,
        // Add bottom padding to prevent keyboard from obscuring content
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Text('Manual Item Entry',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
          const SizedBox(height: 16),
          
          // Search Bar
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (value) {
              setState(() {}); // Trigger rebuild to filter
            },
            decoration: InputDecoration(
              hintText: 'Search product by name...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // List
          Expanded(
            child: BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state.status == ProductStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state.status == ProductStatus.error) {
                  return Center(child: Text(state.message ?? 'Error'));
                } else if (state.status == ProductStatus.loaded || state.status == ProductStatus.success || state.products.isNotEmpty) {
                  final query = _searchController.text.toLowerCase();
                  final filteredProducts = state.products.where((p) {
                    return p.name.toLowerCase().contains(query) || p.barcode.contains(query);
                  }).toList();

                  if (filteredProducts.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No products found',
                            style: TextStyle(color: Colors.grey[600])),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: filteredProducts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return ListTile(
                        onTap: () async {
                          // Play feedback
                          final canVibrate = await Vibrate.canVibrate;
                          if (canVibrate) {
                            Vibrate.feedback(FeedbackType.light);
                          }
                          // Add to cart
                          if (context.mounted) {
                            context
                                .read<BillingBloc>()
                                .add(AddProductToCartEvent(product));
                            // Show small feedback (not obtrusive)
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Added ${product.name} to cart'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add_shopping_cart,
                              color: AppTheme.primaryColor, size: 20),
                        ),
                        title: Text(product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Stock: ${product.stock}',
                            style: TextStyle(
                                color: product.stock > 0
                                    ? Colors.grey[600]
                                    : Colors.red[400],
                                fontSize: 12)),
                        trailing: Text('\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                fontSize: 16)),
                      );
                    },
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }
}
