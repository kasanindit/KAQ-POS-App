import 'package:flutter/material.dart';
import 'package:pos_app/data/model/pos.dart';

const posPadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

String posError(Object error) => error is PosException
    ? error.message
    : 'Perubahan gagal diproses. Coba lagi.';

class PosEmpty extends StatelessWidget {
  const PosEmpty(this.icon, this.message, {super.key});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class PosHeading extends StatelessWidget {
  const PosHeading(this.title, {this.action, super.key});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 8,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ?action,
    ],
  );
}

class PosAmountRow extends StatelessWidget {
  const PosAmountRow(
    this.label,
    this.amount, {
    this.emphasized = false,
    super.key,
  });

  final String label;
  final int amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            rupiah(amount),
            textAlign: TextAlign.end,
            style: emphasized
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
        ),
      ],
    ),
  );
}

Future<T?> showPosForm<T>(
  BuildContext context, {
  required String title,
  required Widget fields,
  required Future<T> Function() submit,
  String action = 'Simpan',
  ShapeBorder? shape,
}) {
  final formKey = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          shape: shape,
          title: Text(title),
          scrollable: true,
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IgnorePointer(ignoring: busy, child: fields),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      FocusScope.of(context).unfocus();
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        final result = await submit();
                        if (context.mounted) Navigator.pop(context, result);
                      } catch (exception) {
                        if (context.mounted) {
                          setState(() {
                            busy = false;
                            error = posError(exception);
                          });
                        }
                      }
                    },
              child: Text(busy ? 'Memproses…' : action),
            ),
          ],
        ),
      ),
    ),
  );
}

class PosNumberField extends StatelessWidget {
  const PosNumberField({
    required this.label,
    required this.onChanged,
    this.initialValue,
    super.key,
  });

  final String label;
  final String? initialValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initialValue,
    decoration: InputDecoration(labelText: label),
    keyboardType: TextInputType.number,
    onChanged: (value) => onChanged(int.tryParse(value) ?? 0),
    validator: (value) {
      final input = value ?? '';
      if (!RegExp(r'^\d+$').hasMatch(input) || int.tryParse(input) == null) {
        return 'Masukkan angka bulat tanpa pemisah.';
      }
      return null;
    },
  );
}
