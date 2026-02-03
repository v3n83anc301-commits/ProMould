import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../services/sync_service.dart';
import '../services/photo_service.dart';

class ManageMouldsScreen extends StatefulWidget {
  final int level;
  const ManageMouldsScreen({super.key, required this.level});
  @override
  State<ManageMouldsScreen> createState() => _ManageMouldsScreenState();
}

class _ManageMouldsScreenState extends State<ManageMouldsScreen> {
  final uuid = const Uuid();

  Future<void> _addOrEdit({Map<String, dynamic>? item}) async {
    final numCtrl = TextEditingController(text: item?['number'] ?? '');
    final nameCtrl = TextEditingController(text: item?['name'] ?? '');
    final matCtrl = TextEditingController(text: item?['material'] ?? '');
    final cavCtrl =
        TextEditingController(text: item?['cavities']?.toString() ?? '1');
    final cycCtrl =
        TextEditingController(text: item?['cycleTime']?.toString() ?? '30');
    bool hotRunner = item?['hotRunner'] == true;
    String? photoUrl = item?['photoUrl'];

    await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: Text(item == null ? 'Add Mould' : 'Edit Mould'),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: numCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mould Number')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Name / Product')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: matCtrl,
                      decoration: const InputDecoration(labelText: 'Material')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cavCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cavities')),
                  const SizedBox(height: 8),
                  TextField(
                      controller: cycCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cycle Time (s)')),
                  const SizedBox(height: 8),
                  SwitchListTile(
                      value: hotRunner,
                      onChanged: (v) => setDialogState(() => hotRunner = v),
                      title: const Text('Hot runner')),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_camera),
                    title: Text(photoUrl != null
                        ? 'Photo attached'
                        : 'Add photo (optional)'),
                    trailing: photoUrl != null
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setDialogState(() => photoUrl = null),
                          )
                        : null,
                    onTap: () async {
                      // Show dialog to choose camera or gallery
                      final source = await showDialog<String>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Add Photo'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Take Photo'),
                                onTap: () => Navigator.pop(ctx, 'camera'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Choose from Gallery'),
                                onTap: () => Navigator.pop(ctx, 'gallery'),
                              ),
                            ],
                          ),
                        ),
                      );

                      if (source == null) return;

                      try {
                        final tempId = item?['id'] ?? uuid.v4();
                        final url = source == 'camera'
                            ? await PhotoService.captureMouldPhoto(tempId)
                            : await PhotoService.uploadMouldPhoto(tempId);

                        if (url != null) {
                          setDialogState(() => photoUrl = url);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Photo uploaded successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error uploading photo: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () async {
                        final box = Hive.box('mouldsBox');
                        final id = item?['id'] ?? uuid.v4();
                        final data = {
                          'id': id,
                          'number': numCtrl.text.trim(),
                          'name': nameCtrl.text.trim(),
                          'material': matCtrl.text.trim(),
                          'cavities': int.tryParse(cavCtrl.text.trim()) ?? 1,
                          'cycleTime':
                              double.tryParse(cycCtrl.text.trim()) ?? 30.0,
                          'hotRunner': hotRunner,
                          'status': item?['status'] ?? 'Available',
                          if (photoUrl != null) 'photoUrl': photoUrl,
                        };
                        await box.put(id, data);
                        await SyncService.pushChange('mouldsBox', id, data);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext, true); // Return true to indicate save
                        }
                      },
                      child: const Text('Save')),
                ],
              ),
            ));
    // Refresh list after dialog closes (if saved)
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('mouldsBox');
    final items = box.values.cast<Map>().toList();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F1419),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Moulds'),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4CC9F0).withOpacity(0.3),
                      const Color(0xFF0F1419),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final m = items[i];
                  final photoUrl = m['photoUrl'] as String?;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: const Color(0xFF0F1419),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: photoUrl != null
                          ? GestureDetector(
                              onTap: () => _showPhoto(photoUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  photoUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CC9F0)
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.broken_image,
                                        color: Color(0xFF4CC9F0)),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CC9F0).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.precision_manufacturing,
                                  color: Color(0xFF4CC9F0)),
                            ),
                      title: Text('${m['number']} • ${m['name']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Material: ${m['material']}',
                              style: const TextStyle(color: Colors.white70)),
                          Text(
                              'Cavities: ${m['cavities']} • Cycle: ${m['cycleTime']}s',
                              style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (m['hotRunner'] == true
                                      ? const Color(0xFFEF476F)
                                      : const Color(0xFF4CC9F0))
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              m['hotRunner'] == true
                                  ? 'Hot Runner'
                                  : 'Cold Runner',
                              style: TextStyle(
                                color: m['hotRunner'] == true
                                    ? const Color(0xFFEF476F)
                                    : const Color(0xFF4CC9F0),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () =>
                          _addOrEdit(item: Map<String, dynamic>.from(m)),
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final mouldId = m['id'] as String;
                          await box.delete(mouldId);
                          await SyncService.deleteRemote('mouldsBox', mouldId);
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        backgroundColor: const Color(0xFF4CC9F0),
        icon: const Icon(Icons.add),
        label: const Text('Add Mould'),
      ),
    );
  }

  void _showPhoto(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url, fit: BoxFit.contain),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
