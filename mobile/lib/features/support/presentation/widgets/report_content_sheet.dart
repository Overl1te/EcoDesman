import "package:flutter/material.dart";

class SupportReportResult {
  const SupportReportResult({required this.reason, required this.details});

  final String reason;
  final String details;
}

Future<SupportReportResult?> showSupportReportSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
}) {
  return showModalBottomSheet<SupportReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _SupportReportSheet(title: title, subtitle: subtitle),
  );
}

class _SupportReportSheet extends StatefulWidget {
  const _SupportReportSheet({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_SupportReportSheet> createState() => _SupportReportSheetState();
}

class _SupportReportSheetState extends State<_SupportReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  String _reason = "spam";

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      SupportReportResult(
        reason: _reason,
        details: _detailsController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: "Причина жалобы"),
              items: const [
                DropdownMenuItem(value: "spam", child: Text("Спам")),
                DropdownMenuItem(value: "abuse", child: Text("Оскорбления")),
                DropdownMenuItem(
                  value: "misinformation",
                  child: Text("Недостоверная информация"),
                ),
                DropdownMenuItem(
                  value: "dangerous",
                  child: Text("Опасный контент"),
                ),
                DropdownMenuItem(
                  value: "copyright",
                  child: Text("Нарушение авторских прав"),
                ),
                DropdownMenuItem(value: "other", child: Text("Другое")),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _reason = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _detailsController,
              minLines: 4,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "Подробности",
                hintText:
                    "Опишите, что именно нарушает правила или вводит в заблуждение.",
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? "";
                if (text.length < 6) {
                  return "Добавьте немного деталей для техподдержки";
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.flag_outlined),
                label: const Text("Отправить жалобу"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
