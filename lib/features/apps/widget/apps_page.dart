import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/apps/model/proxy_app.dart';
import 'package:hiddify/features/apps/overview/proxy_apps_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppsPage extends HookConsumerWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final apps = ref.watch(proxyAppsProvider);
    final searchQuery = useState('');
    final isSearching = useState(false);

    final filteredApps = useMemoized(
      () {
        if (searchQuery.value.isEmpty) return apps;
        return apps
            .where(
              (a) =>
                  a.name.toLowerCase().contains(searchQuery.value.toLowerCase()) ||
                  a.processName.toLowerCase().contains(searchQuery.value.toLowerCase()),
            )
            .toList();
      },
      [apps, searchQuery.value],
    );

    return Scaffold(
      appBar: isSearching.value
          ? AppBar(
              title: TextFormField(
                onChanged: (value) => searchQuery.value = value,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "${MaterialLocalizations.of(context).searchFieldLabel}...",
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
              leading: IconButton(
                onPressed: () {
                  searchQuery.value = '';
                  isSearching.value = false;
                },
                icon: const Icon(Icons.close),
              ),
            )
          : AppBar(
              title: Text(t.pages.apps.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () => isSearching.value = true,
                ),
              ],
            ),
      body: apps.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apps_rounded,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const Gap(16),
                    Text(
                      t.pages.apps.empty,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Gap(8),
                    Text(
                      t.pages.apps.emptyHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: filteredApps.length,
              itemBuilder: (context, index) {
                final app = filteredApps[index];
                return _ProxyAppTile(app: app);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAppDialog(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddAppDialog(BuildContext context, WidgetRef ref) {
    final t = ref.read(translationsProvider).requireValue;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddAppSheet(t: t),
    );
  }
}

class _ProxyAppTile extends ConsumerWidget {
  const _ProxyAppTile({required this.app});

  final ProxyApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: app.enabled
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.apps_rounded,
          color: app.enabled
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        app.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        app.processName,
        style: theme.textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Switch(
        value: app.enabled,
        onChanged: (_) => ref.read(proxyAppsProvider.notifier).toggleApp(app.id),
      ),
      onTap: () => _showEditAppDialog(context, ref, app),
      onLongPress: () => _showDeleteConfirmation(context, ref, app),
    );
  }

  void _showEditAppDialog(BuildContext context, WidgetRef ref, ProxyApp app) {
    final t = ref.read(translationsProvider).requireValue;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _EditAppSheet(t: t, app: app),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, ProxyApp app) async {
    final t = ref.read(translationsProvider).requireValue;
    final confirmed = await ref
        .read(dialogNotifierProvider.notifier)
        .showConfirmation(
          title: t.pages.apps.deleteTitle,
          message: t.pages.apps.deleteMessage(name: app.name),
          positiveBtnTxt: t.common.delete,
        );
    if (confirmed == true && context.mounted) {
      await ref.read(proxyAppsProvider.notifier).removeApp(app.id);
    }
  }
}

class _AddAppSheet extends ConsumerStatefulWidget {
  const _AddAppSheet({required this.t});

  final Translations t;

  @override
  ConsumerState<_AddAppSheet> createState() => _AddAppSheetState();
}

class _AddAppSheetState extends ConsumerState<_AddAppSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _processNameController = TextEditingController();
  final _processPathController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _processNameController.dispose();
    _processPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pages.apps.addTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formName,
                hintText: t.pages.apps.formNameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.pages.apps.formNameRequired;
                }
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: _processNameController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formProcessName,
                hintText: t.pages.apps.formProcessNameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.pages.apps.formProcessNameRequired;
                }
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: _processPathController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formProcessPath,
                hintText: t.pages.apps.formProcessPathHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.common.cancel),
                ),
                const Gap(8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(t.common.add),
                ),
              ],
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(proxyAppsProvider.notifier).addApp(
          name: _nameController.text.trim(),
          processName: _processNameController.text.trim(),
          processPath: _processPathController.text.trim().isEmpty
              ? null
              : _processPathController.text.trim(),
        );
    Navigator.of(context).pop();
  }
}

class _EditAppSheet extends ConsumerStatefulWidget {
  const _EditAppSheet({
    required this.t,
    required this.app,
  });

  final Translations t;
  final ProxyApp app;

  @override
  ConsumerState<_EditAppSheet> createState() => _EditAppSheetState();
}

class _EditAppSheetState extends ConsumerState<_EditAppSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _processNameController;
  late final TextEditingController _processPathController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.app.name);
    _processNameController = TextEditingController(text: widget.app.processName);
    _processPathController = TextEditingController(text: widget.app.processPath ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _processNameController.dispose();
    _processPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.pages.apps.editTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Gap(16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formName,
                hintText: t.pages.apps.formNameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.pages.apps.formNameRequired;
                }
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: _processNameController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formProcessName,
                hintText: t.pages.apps.formProcessNameHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.pages.apps.formProcessNameRequired;
                }
                return null;
              },
            ),
            const Gap(12),
            TextFormField(
              controller: _processPathController,
              decoration: InputDecoration(
                labelText: t.pages.apps.formProcessPath,
                hintText: t.pages.apps.formProcessPathHint,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.common.cancel),
                ),
                const Gap(8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(t.common.save),
                ),
              ],
            ),
            const Gap(8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(proxyAppsProvider.notifier).updateApp(
          id: widget.app.id,
          name: _nameController.text.trim(),
          processName: _processNameController.text.trim(),
          processPath: _processPathController.text.trim().isEmpty
              ? null
              : _processPathController.text.trim(),
        );
    Navigator.of(context).pop();
  }
}
