import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/product.dart';
import 'color_picker.dart';

class ProductFormResult {
  final String marca;
  final String tipo;
  final String taglia;
  final double prezzo;
  final int bottigliePerCassa;
  final String colore;

  ProductFormResult({
    required this.marca,
    required this.tipo,
    required this.taglia,
    required this.prezzo,
    required this.bottigliePerCassa,
    required this.colore,
  });
}

Future<ProductFormResult?> mostraProductFormDialog(BuildContext context, {Product? esistente}) {
  return showDialog<ProductFormResult>(
    context: context,
    builder: (_) => _ProductFormDialog(esistente: esistente),
  );
}

class _ProductFormDialog extends StatefulWidget {
  final Product? esistente;
  const _ProductFormDialog({this.esistente});

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _marca;
  late final TextEditingController _tipo;
  late final TextEditingController _taglia;
  late final TextEditingController _prezzo;
  late final TextEditingController _bottiglie;
  late String _colore;

  @override
  void initState() {
    super.initState();
    final p = widget.esistente;
    _marca = TextEditingController(text: p?.marca ?? '');
    _tipo = TextEditingController(text: p?.tipo ?? '');
    _taglia = TextEditingController(text: p?.taglia ?? '');
    _prezzo = TextEditingController(text: p != null ? p.prezzo.toStringAsFixed(2) : '');
    _bottiglie = TextEditingController(text: p != null ? p.bottigliePerCassa.toString() : '');
    _colore = p?.colore ?? '#38BDF8';
  }

  @override
  void dispose() {
    _marca.dispose();
    _tipo.dispose();
    _taglia.dispose();
    _prezzo.dispose();
    _bottiglie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modifica = widget.esistente != null;
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: coloreDaHex(_colore), shape: BoxShape.circle),
          ),
          const Gap(10),
          Text(modifica ? 'Modifica prodotto' : 'Nuovo prodotto'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _marca,
                  decoration: const InputDecoration(labelText: 'Marca (es: Norda)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo (es: Acqua naturale, Birra)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: _taglia,
                  decoration: const InputDecoration(labelText: 'Taglia (es: 1L, 0.5L)'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Obbligatorio' : null,
                ),
                const Gap(12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prezzo,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Prezzo/cassa (€)'),
                        validator: (v) =>
                            (double.tryParse((v ?? '').replaceAll(',', '.')) == null) ? 'Non valido' : null,
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: TextFormField(
                        controller: _bottiglie,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Bottiglie/cassa'),
                        validator: (v) => (int.tryParse(v ?? '') == null) ? 'Non valido' : null,
                      ),
                    ),
                  ],
                ),
                const Gap(18),
                SelettoreColore(
                  coloreSelezionato: _colore,
                  onCambiato: (hex) => setState(() => _colore = hex),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              ProductFormResult(
                marca: _marca.text.trim(),
                tipo: _tipo.text.trim(),
                taglia: _taglia.text.trim(),
                prezzo: double.parse(_prezzo.text.replaceAll(',', '.')),
                bottigliePerCassa: int.parse(_bottiglie.text),
                colore: _colore,
              ),
            );
          },
          child: Text(modifica ? 'Salva' : 'Aggiungi'),
        ),
      ],
    );
  }
}
