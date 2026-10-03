import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/core/widgets/cobra_logo.dart';

void main() {
  testWidgets('el logo se dibuja con el tamaño pedido', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: CobraLogo(size: 120)),
    ));

    final box = tester.getSize(find.byType(CobraLogo));
    expect(box, const Size(120, 120));
    expect(find.bySemanticsLabel('Logo de Cobrá'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('se puede dibujar a sangre y a tamaños chicos', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [
        CobraLogo(size: 16, rounded: false),
        CobraLogo(size: 512),
      ]),
    ));
    expect(tester.takeException(), isNull);
  });
}
