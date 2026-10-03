import '../../billing/domain/entities/payment_method.dart';
import '../../billing/domain/entities/sale.dart';
import '../../billing/domain/entities/sale_item.dart';
import '../../product/domain/entities/product.dart';
import '../../shop/domain/entities/shop.dart';
import '../domain/sync_models.dart';

/// Conversión entre las entidades de la app y las filas de Supabase.
/// Son funciones puras para poder probarlas sin red.

/// Los precios en la nube tienen 2 decimales.
double round2(num value) => (value * 100).round() / 100;

double _num(Object? v) => v is num ? v.toDouble() : double.parse('$v');

Map<String, dynamic> shopToRow(Shop shop) => {
      'name': shop.name,
      'address1': shop.addressLine1,
      'address2': shop.addressLine2,
      'phone': shop.phoneNumber,
      'payment_alias': shop.paymentAlias,
      'payment_qr': shop.paymentQr,
      'footer_text': shop.footerText,
    };

Shop rowToShop(Map<String, dynamic> row) => Shop(
      name: row['name'] as String? ?? '',
      addressLine1: row['address1'] as String? ?? '',
      addressLine2: row['address2'] as String? ?? '',
      phoneNumber: row['phone'] as String? ?? '',
      paymentAlias: row['payment_alias'] as String? ?? '',
      paymentQr: row['payment_qr'] as String? ?? '',
      footerText: row['footer_text'] as String? ?? '',
    );

Map<String, dynamic> productToRow(Product p, String businessId) => {
      'business_id': businessId,
      'id': p.id,
      'name': p.name,
      'barcode': p.barcode,
      'price': round2(p.price),
      'stock': p.stock,
      // Si se había borrado y se vuelve a crear con el mismo id, revive.
      'deleted_at': null,
    };

RemoteProduct rowToRemoteProduct(Map<String, dynamic> row) => RemoteProduct(
      Product(
        id: row['id'] as String,
        name: row['name'] as String,
        barcode: row['barcode'] as String,
        price: _num(row['price']),
        stock: (row['stock'] as num?)?.toInt() ?? 0,
      ),
      deleted: row['deleted_at'] != null,
    );

Map<String, dynamic> saleToRow(Sale s, String businessId) => {
      'business_id': businessId,
      'id': s.id,
      'sold_at': s.date.toUtc().toIso8601String(),
      'total': round2(s.total),
      'voided': s.voided,
      'payment_method': s.paymentMethod.code,
    };

List<Map<String, dynamic>> saleItemsToRows(Sale s, String businessId) => [
      for (var i = 0; i < s.items.length; i++)
        {
          'business_id': businessId,
          'sale_id': s.id,
          'line': i,
          'product_id': s.items[i].productId,
          'name': s.items[i].name,
          'barcode': s.items[i].barcode,
          'unit_price': round2(s.items[i].unitPrice),
          'quantity': s.items[i].quantity,
        },
    ];

/// [row] puede traer los renglones anidados en `sale_items`.
Sale rowToSale(Map<String, dynamic> row) {
  final rawItems = (row['sale_items'] as List?) ?? const [];
  final items = rawItems.cast<Map<String, dynamic>>().toList()
    ..sort((a, b) => (a['line'] as num).compareTo(b['line'] as num));
  return Sale(
    id: row['id'] as String,
    date: DateTime.parse(row['sold_at'] as String).toLocal(),
    total: _num(row['total']),
    voided: row['voided'] as bool? ?? false,
    paymentMethod: PaymentMethod.fromCode(row['payment_method'] as String?),
    items: [
      for (final i in items)
        SaleItem(
          productId: i['product_id'] as String,
          name: i['name'] as String,
          barcode: i['barcode'] as String,
          unitPrice: _num(i['unit_price']),
          quantity: (i['quantity'] as num).toInt(),
        ),
    ],
  );
}
