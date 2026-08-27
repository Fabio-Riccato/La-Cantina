import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../models/product.dart';
import '../models/load.dart';

class LoadItemFormResult {
  final int productId;
  final double casse;
  final String? clienteNome;
  final String? note;
  final PeriodoConsegna periodo;

  LoadItemFormResult({
    required this.productId,
    required this.casse,
    this.clienteNome,
    this.note,
    required this.periodo,
  });
}

/// Mostra il form per aggiungere una riga al carico, oppure per modificarne una esistente
/// (passando [esistente]).
Future<LoadItemFormResult?> mostraLoadItemDialog(
  BuildContext context,
  List<Product> prodotti, {
  LoadItem? esistente,
}) {
  return showDialog<LoadItemFormResult>(
    context: context,
    builder: (_) => _LoadItemDialog(prodotti: prodotti, esistente: esistente),
  );
}

class _LoadItemDialog extends StatefulWidget {
  final List<Product> prodotti;
  final LoadItem? esistente;
  const _LoadItemDialog({required this.prodotti, this.esistente});

  @override
  State<_LoadItemDialog> createState() => _LoadItemDialogState();
}

class _LoadItemDialogState extends State<_LoadItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _casseCtrl;
  late final TextEditingController _clienteCtrl;
  late final TextEditingController _noteCtrl;
  Product? _selezionato;
  late PeriodoConsegna _periodo;

  @override
  void initState() {
    super.initState();
    final e = widget.esistente;
    _casseCtrl = TextEditingController(text: e != null ? e.casseFormattate : '1');
    _clienteCtrl = TextEditingController(text: e?.clienteNome ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _periodo = e?.periodoConsegna ?? PeriodoConsegna.medio;
    if (e != null) {
      // In modifica il prodotto è già determinato e non si cambia
      for (final p in widget.prodotti) {
        if (p.id == e.productId) {
          _selezionato = p;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _casseCtrl.dispose();
    _clienteCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modifica = widget.esistente != null;

    return AlertDialog(
      title: Text(modifica ? 'Modifica riga del carico' : 'Aggiungi al carico'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (modifica)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: coloreDaHex(widget.esistente!.prodottoColore),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: Text(widget.esistente!.nomeCompleto,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  )
                else
                  DropdownButtonFormField<Product>(
                    value: _selezionato,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Prodotto'),
                    items: widget.prodotti
                        .map((p) => DropdownMenuItem(
                              value: p,
                              child: Row(children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: p.coloreFlutter, shape: BoxShape.circle),
                                ),
                                const Gap(10),
                                Expanded(
                                  child: Text(
                                    '${p.nomeCompleto}  ·  ${p.casseDisponibili.toStringAsFixed(0)} disp.',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selezionato = v),
                    validator: (v) => v == null ? 'Seleziona un prodotto' : null,
                  ),
                const Gap(14),
                TextFormField(
                  controller: _casseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Numero di casse'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Quantità non valida';
                    return null;
                  },
                ),
                const Gap(14),
                TextFormField(
                  controller: _clienteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cliente (opzionale)',
                    hintText: 'es: Bar Roma',
                  ),
                ),
                const Gap(14),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (opzionale)',
                    hintText: 'es: lasciare sul retro, ritirare vuoti, paga alla consegna',
                    alignLabelWithHint: true,
                  ),
                ),
                const Gap(18),
                Text('Periodo di consegna',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                const Gap(8),
                SegmentedButton<PeriodoConsegna>(
                  segments: PeriodoConsegna.values
                      .map((p) => ButtonSegment(
                            value: p,
                            label: Text(p.etichetta, style: const TextStyle(fontSize: 12)),
                            icon: Icon(p.icona, size: 16),
                          ))
                      .toList(),
                  selected: {_periodo},
                  onSelectionChanged: (s) => setState(() => _periodo = s.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith((stati) =>
                        stati.contains(WidgetState.selected) ? _periodo.colore.withOpacity(0.16) : null),
                  ),
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
              LoadItemFormResult(
                productId: widget.esistente?.productId ?? _selezionato!.id,
                casse: double.parse(_casseCtrl.text.replaceAll(',', '.')),
                clienteNome: _clienteCtrl.text.trim(),
                note: _noteCtrl.text.trim(),
                periodo: _periodo,
              ),
            );
          },
          child: Text(modifica ? 'Salva' : 'Aggiungi'),
        ),
      ],
    );
  }
}
