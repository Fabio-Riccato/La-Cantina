import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import '../services/api_client.dart';
import '../services/app_data_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart' show AccountMenuButton;

class _Messaggio {
  final String testo;
  final bool daUtente;
  final bool errore;
  _Messaggio(this.testo, {required this.daUtente, this.errore = false});
}

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Messaggio> _messaggi = [
    _Messaggio(
      'Ciao! Puoi chiedermi cose come:\n'
      '"Aggiungi 6 casse di Norda naturale al carico di oggi"\n'
      '"Quante casse di Lonera frizzante ho a disposizione?"\n'
      '"Ho completato il carico"',
      daUtente: false,
    ),
  ];
  bool _invioInCorso = false;

  Future<void> _invia() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _invioInCorso) return;

    setState(() {
      _messaggi.add(_Messaggio(testo, daUtente: true));
      _invioInCorso = true;
    });
    _controller.clear();
    _scrollInFondo();

    try {
      final risposta = await AppDataService.chiediAssistente(testo);
      final risposteTesto = (risposta['risposta'] as String?)?.trim();
      setState(() {
        _messaggi.add(_Messaggio(
          risposteTesto?.isNotEmpty == true ? risposteTesto! : 'Fatto.',
          daUtente: false,
        ));
      });
    } on ApiException catch (e) {
      setState(() => _messaggi.add(_Messaggio(e.message, daUtente: false, errore: true)));
    } catch (_) {
      setState(() => _messaggi.add(_Messaggio('Errore di connessione al server', daUtente: false, errore: true)));
    } finally {
      setState(() => _invioInCorso = false);
      _scrollInFondo();
    }
  }

  void _scrollInFondo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistente'), actions: const [AccountMenuButton()]),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messaggi.length + (_invioInCorso ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messaggi.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  );
                }
                final m = _messaggi[i];
                return Align(
                  alignment: m.daUtente ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: m.daUtente
                          ? AppTheme.primario
                          : (m.errore ? AppTheme.errore.withOpacity(0.1) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      border: m.daUtente ? null : Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Text(
                      m.testo,
                      style: TextStyle(color: m.daUtente ? Colors.white : (m.errore ? AppTheme.errore : Colors.black87)),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Scrivi un comando...'),
                      onSubmitted: (_) => _invia(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const Gap(8),
                  IconButton.filled(
                    onPressed: _invioInCorso ? null : _invia,
                    icon: const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppTheme.primario, padding: const EdgeInsets.all(14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
