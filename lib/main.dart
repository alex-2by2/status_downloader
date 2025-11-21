import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'android_saf.dart';

void main() {
  runApp(const StatusDownloaderApp());
}

class StatusDownloaderApp extends StatelessWidget {
  const StatusDownloaderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Status Downloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const StatusHomePage(),
    );
  }
}

class FileEntry {
  final String name;
  final String uri;
  final bool isDirectory;
  final String? mime;
  final int? lastModified;
  final int? size;
  FileEntry({
    required this.name,
    required this.uri,
    required this.isDirectory,
    this.mime,
    this.lastModified,
    this.size,
  });
  factory FileEntry.fromMap(Map map) => FileEntry(
        name: map['name'] ?? 'unknown',
        uri: map['uri'] ?? '',
        isDirectory: map['isDirectory'] == true,
        mime: map['mime'],
        lastModified: map['lastModified'] is int ? map['lastModified'] as int : null,
        size: map['size'] is int ? map['size'] as int : null,
      );
}

// in-memory thumbnail cache
final Map<String, Uint8List> _thumbCache = {};

class StatusHomePage extends StatefulWidget {
  const StatusHomePage({super.key});
  @override
  State<StatusHomePage> createState() => _StatusHomePageState();
}

class _StatusHomePageState extends State<StatusHomePage> {
  List<FileEntry> entries = [];
  String? treeUri;
  bool loading = false;
  String? lastMessage;
  final Set<String> _selectedUris = {};

  @override
  void initState() {
    super.initState();
  }

  Widget _buildFab() {
    final selectedCount = _selectedUris.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'save_all',
          onPressed: entries.isEmpty ? null : _saveAll,
          label: const Text('Save All'),
          icon: const Icon(Icons.download),
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'save_sel',
          onPressed: selectedCount == 0 ? null : _saveSelected,
          label: Text('Save Selected ($selectedCount)'),
          icon: const Icon(Icons.download_done),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Downloader (SAF)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: treeUri == null ? null : _listFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _pickFolder,
                    child: const Text('Pick folder (SAF)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: treeUri == null ? null : _takePerms,
                  child: const Text('Take Persistable Perm'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectedUris.isEmpty ? null : _deleteSelected,
                  child: const Text('Delete Selected'),
                ),
              ],
            ),
          ),
          if (lastMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(lastMessage!, style: const TextStyle(color: Colors.black54)),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                    ? const Center(child: Text('No files loaded'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(6),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                        itemCount: entries.length,
                        itemBuilder: (context, idx) {
                          final e = entries[idx];
                          final isVideo = (e.mime ?? '').startsWith('video') || e.name.toLowerCase().endsWith('.mp4');
                          return GestureDetector(
                            onTap: () => _openPreview(e),
                            onLongPress: () => _toggleSelection(e),
                            child: GridTile(
                              header: Align(
                                alignment: Alignment.topRight,
                                child: Checkbox(
                                  value: e.isDirectory ? false : _selectedUris.contains(e.uri),
                                  onChanged: e.isDirectory ? null : (_) => _toggleSelection(e),
                                ),
                              ),
                              child: Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: isVideo ? _buildVideoTile(e) : _buildThumbnailWidget(e),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildVideoTile(FileEntry e) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam, size: 48, color: Colors.grey),
        const SizedBox(height: 6),
        Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildThumbnailWidget(FileEntry e) {
    final cached = _thumbCache[e.uri];
    if (cached != null) {
      return Image.memory(cached, fit: BoxFit.cover);
    }
    return FutureBuilder<Uint8List?>(
      future: AndroidSaf.readFileBytes(e.uri, maxBytes: 200000),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes != null && bytes.isNotEmpty) {
          _thumbCache[e.uri] = bytes;
          return Image.memory(bytes, fit: BoxFit.cover);
        } else if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.image, size: 48, color: Colors.grey),
              const SizedBox(height: 6),
              Text(e.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          );
        }
      },
    );
  }

  void _toggleSelection(FileEntry e) {
    setState(() {
      if (_selectedUris.contains(e.uri)) _selectedUris.remove(e.uri);
      else _selectedUris.add(e.uri);
    });
  }

  Future<void> _pickFolder() async {
    try {
      setState(() { loading = true; lastMessage = null; });
      if (!kIsWeb && Platform.isAndroid) {
        final res = await AndroidSaf.openDocumentTree();
        if (res == null) {
          setState(() { lastMessage = 'No folder selected'; loading = false; });
          return;
        }
        treeUri = res;
        await _listFiles();
      } else {
        final path = await FilePicker.platform.getDirectoryPath();
        if (path == null) {
          setState(() { lastMessage = 'No folder selected'; loading = false; });
          return;
        }
        treeUri = path;
        _listFilesFromPath(path);
      }
    } catch (e) {
      setState(() { lastMessage = 'Pick error: $e'; loading = false; });
    }
  }

  Future<void> _takePerms() async {
    if (treeUri == null) return;
    try {
      final ok = await AndroidSaf.takePersistablePermission(treeUri!, 3);
      setState(() { lastMessage = ok ? 'Persistable permission granted' : 'Permission failed'; });
    } catch (e) {
      setState(() { lastMessage = 'Take perm error: $e'; });
    }
  }

  Future<void> _listFiles() async {
    if (treeUri == null) return;
    try {
      setState(() { loading = true; lastMessage = null; entries.clear(); _selectedUris.clear(); _clearThumbCache(); });
      final res = await AndroidSaf.listFiles(treeUri!);
      final list = <FileEntry>[];
      for (final item in res) {
        if (item is Map) list.add(FileEntry.fromMap(item));
        else if (item is Map<String, dynamic>) list.add(FileEntry.fromMap(item));
      }
      setState(() { entries = list; lastMessage = 'Loaded ${list.length} items'; });
    } catch (e) {
      setState(() { lastMessage = 'List error: $e'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  void _listFilesFromPath(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      setState(() { lastMessage = 'Folder does not exist'; });
      return;
    }
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final list = files.map((f) => FileEntry(
          name: f.uri.pathSegments.last,
          uri: f.path,
          isDirectory: false,
          mime: null,
          lastModified: f.lastModifiedSync().millisecondsSinceEpoch,
          size: f.lengthSync(),
        )).toList();
    setState(() { entries = list; lastMessage = 'Loaded ${list.length} items (local)'; });
  }

  Future<void> _deleteSelected() async {
    if (_selectedUris.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete selected?'),
        content: Text('Delete ${_selectedUris.length} items? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    int deleted = 0;
    for (final uri in _selectedUris.toList()) {
      try {
        final ok = await AndroidSaf.deleteDocument(uri);
        if (ok) deleted++;
      } catch (e) {}
    }
    await _listFiles();
    setState(() { lastMessage = 'Deleted $deleted items'; _selectedUris.clear(); });
  }

  Future<void> _saveAll() async {
    final uris = entries.where((e) => !e.isDirectory).map((e) => e.uri).toList();
    if (uris.isEmpty) return;
    setState(() { loading = true; lastMessage = 'Saving ${uris.length} items...'; });
    try {
      final saved = await AndroidSaf.copyDocumentsToPictures(uris);
      setState(() { lastMessage = 'Saved ${saved.length} items'; });
    } catch (e) {
      setState(() { lastMessage = 'Save error: $e'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _saveSelected() async {
    final uris = _selectedUris.toList();
    if (uris.isEmpty) return;
    setState(() { loading = true; lastMessage = 'Saving ${uris.length} items...'; });
    try {
      final saved = await AndroidSaf.copyDocumentsToPictures(uris);
      setState(() { lastMessage = 'Saved ${saved.length} items'; _selectedUris.clear(); });
      await _listFiles();
    } catch (e) {
      setState(() { lastMessage = 'Save error: $e'; });
    } finally {
      setState(() { loading = false; });
    }
  }

  Future<void> _openPreview(FileEntry e) async {
    try {
      final ok = await AndroidSaf.openDocumentInApp(e.uri);
      if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open document')));
    } catch (ex) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preview error: $ex')));
    }
  }

  void _clearThumbCache() {
    _thumbCache.clear();
  }
}
