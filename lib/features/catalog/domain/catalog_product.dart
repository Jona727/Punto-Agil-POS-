import 'package:equatable/equatable.dart';

/// Un producto del catálogo compartido. No tiene precio ni stock: eso lo
/// define cada comercio.
class CatalogProduct extends Equatable {
  final String ean;
  final String name;
  final String brand;
  final String category;

  const CatalogProduct({
    required this.ean,
    required this.name,
    this.brand = '',
    this.category = '',
  });

  @override
  List<Object> get props => [ean, name, brand, category];
}
