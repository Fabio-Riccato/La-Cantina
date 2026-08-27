import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/warehouse_item.dart';

enum TipoMovimento { arrivo, rettifica }

Future<double?> mostraWarehouseMovementDialog(
  BuildContext context, {
  required WarehouseItem item,
  required TipoMovimento tipo,
}) {
  final controller = TextEditingController(
    text: tipo == TipoMovimento.rettifica ? item.casseDisponibili.toStringAsFixed(0) : '',
  );
  final formKey = GlobalKey<FormState>();

  return showDialog<double>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(tipo == TipoMovimento.arrivo ? 'Arrivo fornitore' : 'Rettifica giacenza'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.nomeCompleto, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Gap(4),
            Text('Attualmente disponibili: ${item.casseDisponibili.toStringAsFixed(0)} casse', style: const TextStyle(color: Colors.black54)),
            const Gap(16),
            TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: tipo == TipoMovimento.arrivo ? 'Casse arrivate' : 'Nuova giacenza totale (casse)',
              ),
              validator: (v) {
                final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                if (n == null || n < 0) return 'Valore non valido';
                if (tipo == TipoMovimento.arrivo && n <= 0) return 'Deve essere maggiore di zero';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            if (!formKey.currentState!.validate()) return;
            Navigator.pop(context, double.parse(controller.text.replaceAll(',', '.')));
          },
          child: const Text('Conferma'),
        ),
      ],
    ),
  );
}
