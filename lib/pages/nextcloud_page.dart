import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:blossom/tools/nextcloud_sync.dart';
import 'package:blossom/audio/nplayer.dart';

class NextcloudPage extends StatefulWidget {
  const NextcloudPage({Key? key}) : super(key: key);

  @override
  State<NextcloudPage> createState() => _NextcloudPageState();
}

class _NextcloudPageState extends State<NextcloudPage> {
  final _formKey   = GlobalKey<FormState>();
  final _urlCtrl   = TextEditingController();
  final _userCtrl  = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _pathCtrl  = TextEditingController();

  bool _obscurePass   = true;
  bool _testingConn   = false;
  bool _connOk        = false;
  bool _uploadEnabled = true;
  bool _dirty         = false;

  @override
  void initState() {
    super.initState();
    final nc = NextcloudSync();
    _urlCtrl.text   = nc.serverUrl;
    _userCtrl.text  = nc.username;
    _pathCtrl.text  = nc.remotePath;
    _uploadEnabled  = nc.uploadEnabled;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _pathCtrl.dispose();
    super.dispose();
  }

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final nc = NextcloudSync();
    await nc.saveConfig(
      serverUrl:     _urlCtrl.text.trim(),
      username:      _userCtrl.text.trim(),
      password:      _passCtrl.text.isNotEmpty
          ? _passCtrl.text
          : nc.serverUrl == _urlCtrl.text.trim()
              ? await _loadSavedPassword()
              : _passCtrl.text,
      remotePath:    _pathCtrl.text.trim(),
      uploadEnabled: _uploadEnabled,
    );
    setState(() { _dirty = false; _connOk = false; });
    _snack('Configuration saved');
  }

  Future<String> _loadSavedPassword() async {
    // Password is managed internally by NextcloudSync.saveConfig;
    // returning empty string here causes saveConfig to preserve the stored value.
    return '';
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _testingConn = true; _connOk = false; });

    final nc = NextcloudSync();
    await nc.saveConfig(
      serverUrl:     _urlCtrl.text.trim(),
      username:      _userCtrl.text.trim(),
      password:      _passCtrl.text,
      remotePath:    _pathCtrl.text.trim(),
      uploadEnabled: _uploadEnabled,
    );

    final ok = await nc.testConnection();
    setState(() { _testingConn = false; _connOk = ok; _dirty = false; });
    _snack(ok
        ? '✓ Connected to Nextcloud!'
        : '✗ Connection failed — check URL / credentials');
  }

  // ── FIX: Accept a BuildContext so Provider.of<NPlayer> uses a context
  //         that is definitely inside the MultiProvider scope, not the
  //         StatefulWidget's own context which may sit above it in the tree.
  Future<void> _manualSync(BuildContext ctx) async {
    final nc     = NextcloudSync();
    final player = Provider.of<NPlayer>(ctx, listen: false);
    await nc.manualSync(
      onReloadNeeded: () => player.reloadSongs(),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Nextcloud Sync'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saveConfig,
              child: Text('Save', style: TextStyle(color: colors.secondary)),
            ),
        ],
      ),
      // ── FIX: No ChangeNotifierProvider.value wrapper here.
      //         NextcloudSync is already registered at the root MultiProvider,
      //         so Consumer<NextcloudSync> resolves it directly.
      body: Consumer<NextcloudSync>(
        builder: (context, nc, _) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _StatusCard(nc: nc),
            const SizedBox(height: 16),

            _SectionHeader('Sync'),
            SwitchListTile(
              title:       const Text('Enable Nextcloud Sync'),
              subtitle:    Text(
                nc.enabled
                    ? 'Blossom will check for changes on startup'
                    : 'Sync is disabled',
              ),
              value:       nc.enabled,
              activeColor: colors.secondary,
              onChanged:   nc.isConfigured
                  ? (v) => nc.setEnabled(v)
                  : null,
            ),
            SwitchListTile(
              title:       const Text('Upload local songs'),
              subtitle:    const Text(
                  'Send songs that are on this device but not on Nextcloud'),
              value:       _uploadEnabled,
              activeColor: colors.secondary,
              onChanged: (v) {
                setState(() { _uploadEnabled = v; _dirty = true; });
              },
            ),
            const Divider(height: 32),

            _SectionHeader('Server'),
            Form(
              key:       _formKey,
              onChanged: _markDirty,
              child: Column(
                children: [
                  _Field(
                    controller: _urlCtrl,
                    label:      'Server URL',
                    hint:       'http://100.98.86.86:8080',
                    icon:       Icons.dns_outlined,
                    validator:  (v) => (v == null || v.isEmpty)
                        ? 'Enter the server URL'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _userCtrl,
                    label:      'Username',
                    hint:       'your_nextcloud_user',
                    icon:       Icons.person_outlined,
                    validator:  (v) => (v == null || v.isEmpty)
                        ? 'Enter your username'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller:  _passCtrl,
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText:  'Password',
                      hintText:   nc.isConfigured ? '(unchanged)' : 'your_password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    validator: (v) {
                      if (!nc.isConfigured && (v == null || v.isEmpty)) {
                        return 'Enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    controller: _pathCtrl,
                    label:      'Remote Music Folder',
                    hint:       '/Music',
                    icon:       Icons.folder_outlined,
                    validator:  (v) => (v == null || v.isEmpty)
                        ? 'Enter the remote folder path'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Path inside Nextcloud where your music lives.\n'
                    'Files sync to/from your primary Blossom music directory.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: _testingConn
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_connOk
                            ? Icons.check_circle_outline
                            : Icons.wifi_tethering),
                    label: Text(_testingConn ? 'Testing…' : 'Test Connection'),
                    onPressed: _testingConn ? null : _testConnection,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon:  const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.secondary,
                      foregroundColor: colors.onSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveConfig,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── FIX: Pass the Consumer's `context` into _manualSync so that
            //         Provider.of<NPlayer> resolves against a context that is
            //         a descendant of the root MultiProvider.
            if (nc.isConfigured)
              _ManualSyncButton(
                nc:     nc,
                onSync: () => _manualSync(context),
              ),

            const SizedBox(height: 32),

            _SectionHeader('How it works'),
            _InfoCard(
              icon:  Icons.info_outline,
              color: colors.secondary,
              text:
                  'When the app starts, Blossom quickly compares your local music '
                  'folder with your Nextcloud folder. If there are new or changed '
                  'songs, you\'ll get a prompt to sync — you can always skip it.\n\n'
                  'Downloaded songs go straight into your music directory, so they '
                  'appear in your library immediately after sync.',
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sub-widgets (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final NextcloudSync nc;
  const _StatusCard({required this.nc});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (nc.status) {
      SyncStatus.syncing  => (Icons.sync,           colors.primary),
      SyncStatus.checking => (Icons.search,          colors.primary),
      SyncStatus.success  => (Icons.check_circle,    Colors.green),
      SyncStatus.error    => (Icons.error_outline,   colors.error),
      SyncStatus.idle     => (Icons.cloud_outlined,  colors.onSurface.withOpacity(0.4)),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                nc.status == SyncStatus.syncing || nc.status == SyncStatus.checking
                    ? SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: color),
                      )
                    : Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    nc.statusMessage,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
// Replace the progress section inside _StatusCard.build()

if (nc.progress != null) ...[
  const SizedBox(height: 10),
  // Byte-level progress bar (more accurate than file count)
  LinearProgressIndicator(
    value:           nc.progress!.bytesFraction,
    backgroundColor: colors.outline.withOpacity(0.15),
    valueColor:      AlwaysStoppedAnimation(colors.secondary),
    borderRadius:    BorderRadius.circular(4),
  ),
  const SizedBox(height: 6),
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Current file + file count
      Expanded(
        child: Text(
          '${nc.progress!.currentFile}',
          style:    Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      // File count
      Text(
        '${nc.progress!.completed}/${nc.progress!.total}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurface.withOpacity(0.5),
        ),
      ),
    ],
  ),
  const SizedBox(height: 4),
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Speed
      Row(
        children: [
          Icon(Icons.speed, size: 12,
              color: colors.onSurface.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text(
            nc.progress!.speedLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.5),
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      // ETA
      Row(
        children: [
          Icon(Icons.timer_outlined, size: 12,
              color: colors.onSurface.withOpacity(0.4)),
          const SizedBox(width: 4),
          Text(
            nc.progress!.etaLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    ],
  ),
],
            if (nc.lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last synced: ${_formatTime(nc.lastSyncTime!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours   < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays    < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ManualSyncButton extends StatelessWidget {
  final NextcloudSync nc;
  final VoidCallback  onSync;
  const _ManualSyncButton({required this.nc, required this.onSync});

  @override
  Widget build(BuildContext context) {
    final busy = nc.status == SyncStatus.syncing ||
        nc.status == SyncStatus.checking;
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon:  busy
            ? const SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
        label: Text(busy ? 'Syncing…' : 'Sync Now'),
        onPressed: busy ? null : onSync,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.secondary,
          side:  BorderSide(color: colors.secondary.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize:   16,
        fontWeight: FontWeight.bold,
        color:      Theme.of(context).colorScheme.secondary,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator:  validator,
    decoration: InputDecoration(
      labelText:  label,
      hintText:   hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _InfoCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}