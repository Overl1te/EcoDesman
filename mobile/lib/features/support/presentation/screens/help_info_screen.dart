import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:url_launcher/url_launcher.dart";

import "../../data/repositories/support_repository_impl.dart";
import "../../domain/models/support_models.dart";

final helpCenterContentProvider = FutureProvider<HelpCenterContent>((ref) {
  return ref.watch(supportRepositoryProvider).fetchHelpCenterContent();
});

final helpDocumentProvider = FutureProvider.family<HelpDocument, String>((
  ref,
  slug,
) {
  return ref.watch(supportRepositoryProvider).fetchHelpDocument(slug);
});

class HelpInfoScreen extends ConsumerWidget {
  const HelpInfoScreen({super.key});

  Future<void> _openPdf(BuildContext context, HelpDocument document) async {
    final uri = Uri.tryParse(document.pdfDownloadUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Некорректная ссылка для ${document.label}")),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Не удалось открыть ${document.label}")),
      );
    }
  }

  void _openDocument(BuildContext context, HelpDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpDocumentScreen(slug: document.slug),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(helpCenterContentProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(title: const Text("Справка")),
      body: contentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
          title: "Не удалось загрузить справку",
          message: error.toString(),
        ),
        data: (content) {
          final documentsById = {
            for (final document in content.documents) document.id: document,
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _HeaderBlock(content: content),
              const SizedBox(height: 24),
              for (final group in content.documentGroups) ...[
                _SectionTitle(title: group.title),
                const SizedBox(height: 12),
                for (final documentId in group.documentIds)
                  if (documentsById[documentId] case final document?)
                    _DocumentCard(
                      document: document,
                      onOpen: () => _openDocument(context, document),
                      onDownload: () => _openPdf(context, document),
                    ),
                const SizedBox(height: 18),
              ],
              _ContactBlock(contactBlock: content.contactBlock),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push("/profile/support"),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text("Есть вопрос по документу? Напишите нам"),
              ),
            ],
          );
        },
      ),
    );
  }
}

class HelpDocumentScreen extends ConsumerWidget {
  const HelpDocumentScreen({required this.slug, super.key});

  final String slug;

  Future<void> _openPdf(BuildContext context, HelpDocument document) async {
    final uri = Uri.tryParse(document.pdfDownloadUrl);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Не удалось открыть PDF")));
    }
  }

  Future<void> _writeEmail(BuildContext context, String email) async {
    final uri = Uri(scheme: "mailto", path: email);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось открыть почтовое приложение")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentAsync = ref.watch(helpDocumentProvider(slug));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F4),
      appBar: AppBar(title: const Text("Документ")),
      body: documentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _ErrorState(title: "Документ не найден", message: error.toString()),
        data: (document) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Text(
              "Справка → ${document.label}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF6B7167),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              document.label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              document.description,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: document.revision),
                _MetaChip(label: document.status),
                _MetaChip(label: document.operator),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed: () => _openPdf(context, document),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text("Скачать PDF"),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Печать доступна в веб-версии документа"),
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text("Распечатать"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DocumentContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (document.quickFacts.isNotEmpty) ...[
                    _QuickFactsBlock(facts: document.quickFacts),
                    const SizedBox(height: 20),
                  ],
                  if (document.tableOfContents.isNotEmpty) ...[
                    _TableOfContents(items: document.tableOfContents),
                    const SizedBox(height: 8),
                  ],
                  for (final section in document.sections)
                    _DocumentSection(section: section),
                  if (document.withdrawal case final withdrawal?) ...[
                    const SizedBox(height: 18),
                    _WithdrawalBlock(withdrawal: withdrawal),
                  ],
                  if (document.operatorDetails case final details?) ...[
                    const SizedBox(height: 22),
                    _OperatorDetailsBlock(details: details),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _QuestionBlock(
              email:
                  document.operatorDetails?.email ?? document.approval.contact,
              onEmail: () => _writeEmail(
                context,
                document.operatorDetails?.email ?? document.approval.contact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({required this.content});

  final HelpCenterContent content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.overview.title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content.overview.description,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          content.overview.lead,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF596054),
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.onOpen,
    required this.onDownload,
  });

  final HelpDocument document;
  final VoidCallback onOpen;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              document.label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              document.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: "Обновлено: ${document.updatedAt}"),
                _MetaChip(label: document.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpen,
                    child: const Text("Открыть"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_outlined),
                    label: const Text("PDF"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentContainer extends StatelessWidget {
  const _DocumentContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickFactsBlock extends StatelessWidget {
  const _QuickFactsBlock({required this.facts});

  final List<HelpDocumentQuickFact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6EA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x293C6B35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF3C6B35)),
              const SizedBox(width: 8),
              Text(
                "Кратко",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final fact in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "${fact.label}: ",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    TextSpan(text: fact.value),
                  ],
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({required this.items});

  final List<HelpDocumentTocItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      initiallyExpanded: false,
      title: Text(
        "Содержание",
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      children: [
        for (var index = 0; index < items.length; index++)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "${index + 1}. ${items[index].title.replaceFirst(RegExp(r"^\d+\.\s*"), "")}",
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ),
      ],
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({required this.section});

  final HelpDocumentSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 12),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                paragraph,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2F332D),
                  height: 1.65,
                ),
              ),
            ),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                "• $bullet",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF2F332D),
                  height: 1.55,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WithdrawalBlock extends StatelessWidget {
  const _WithdrawalBlock({required this.withdrawal});

  final HelpDocumentWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Text(
          withdrawal.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in withdrawal.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text("• $item", style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

class _OperatorDetailsBlock extends StatelessWidget {
  const _OperatorDetailsBlock({required this.details});

  final HelpOperatorDetails details;

  @override
  Widget build(BuildContext context) {
    final rows = <String, String>{
      "Оператор": details.name,
      "ИНН": details.inn,
      "ОГРН": details.ogrn,
      "Адрес": details.address,
      "Email": details.email,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Оператор",
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (final entry in rows.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "${entry.key}: ",
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: entry.value),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({required this.contactBlock});

  final HelpContactBlock contactBlock;

  @override
  Widget build(BuildContext context) {
    final rows = <String, String>{
      if (contactBlock.operator.isNotEmpty) "Оператор": contactBlock.operator,
      if (contactBlock.inn.isNotEmpty) "ИНН": contactBlock.inn,
      if (contactBlock.ogrn.isNotEmpty) "ОГРН": contactBlock.ogrn,
      if (contactBlock.address.isNotEmpty) "Адрес": contactBlock.address,
      "Email": contactBlock.email,
    };

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contactBlock.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "${entry.key}: ",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: entry.value),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuestionBlock extends StatelessWidget {
  const _QuestionBlock({required this.email, required this.onEmail});

  final String email;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Есть вопрос по документу?",
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text("Напишите нам: $email"),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEmail,
              icon: const Icon(Icons.mail_outline),
              label: const Text("Написать"),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: const Color(0xFF6B7167),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
