// lib/screens/shift_handover_screen.dart
// ProMould v9 - Shift Handover UI

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/handover_service.dart';
import '../services/rbac_service.dart';
import '../services/log_service.dart';
import '../models/shift_handover_model.dart';
import '../config/permissions.dart';

class ShiftHandoverScreen extends StatefulWidget {
  final String username;
  final int level;

  const ShiftHandoverScreen({
    super.key,
    required this.username,
    required this.level,
  });

  @override
  State<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends State<ShiftHandoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ShiftHandover> _handovers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHandovers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHandovers() async {
    setState(() => _isLoading = true);
    try {
      _handovers = HandoverService.getAllHandovers();
    } catch (e) {
      LogService.error('Failed to load handovers', e);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Shift Handover'),
        backgroundColor: const Color(0xFF0F1419),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4CC9F0),
          tabs: const [
            Tab(icon: Icon(Icons.upload), text: 'Outgoing'),
            Tab(icon: Icon(Icons.download), text: 'Incoming'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _OutgoingShiftTab(
                  username: widget.username,
                  onRefresh: _loadHandovers,
                ),
                _IncomingShiftTab(
                  username: widget.username,
                  handovers: _handovers
                      .where((h) => h.status == HandoverStatus.inProgress)
                      .toList(),
                  onRefresh: _loadHandovers,
                ),
                _HandoverHistoryTab(
                  handovers: _handovers,
                  onRefresh: _loadHandovers,
                ),
              ],
            ),
    );
  }
}

// ============ OUTGOING SHIFT TAB ============

class _OutgoingShiftTab extends StatefulWidget {
  final String username;
  final VoidCallback onRefresh;

  const _OutgoingShiftTab({
    required this.username,
    required this.onRefresh,
  });

  @override
  State<_OutgoingShiftTab> createState() => _OutgoingShiftTabState();
}

class _OutgoingShiftTabState extends State<_OutgoingShiftTab> {
  final _notesController = TextEditingController();
  final _safetyNotesController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  bool _isCreating = false;
  HandoverSnapshot? _previewSnapshot;

  @override
  void dispose() {
    _notesController.dispose();
    _safetyNotesController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _generateSnapshot() async {
    setState(() => _isCreating = true);
    try {
      final snapshot = await HandoverService.captureSnapshot();
      setState(() => _previewSnapshot = snapshot);
    } catch (e) {
      LogService.error('Failed to generate snapshot', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate snapshot: $e')),
        );
      }
    }
    setState(() => _isCreating = false);
  }

  Future<void> _createHandover() async {
    if (_previewSnapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate a snapshot first')),
      );
      return;
    }

    setState(() => _isCreating = true);
    try {
      final currentUser = RBACService.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await HandoverService.createHandover(
        shiftId: 'current', // TODO: Get actual shift ID
        outgoingUserId: currentUser.id,
        outgoingUserName: currentUser.username,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        safetyNotes: _safetyNotesController.text.isNotEmpty
            ? _safetyNotesController.text
            : null,
        specialInstructions: _specialInstructionsController.text.isNotEmpty
            ? _specialInstructionsController.text
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handover created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _notesController.clear();
        _safetyNotesController.clear();
        _specialInstructionsController.clear();
        setState(() => _previewSnapshot = null);
        widget.onRefresh();
      }
    } catch (e) {
      LogService.error('Failed to create handover', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create handover: $e')),
        );
      }
    }
    setState(() => _isCreating = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4CC9F0).withOpacity(0.2),
                  const Color(0xFF0F1419),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4CC9F0).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.upload, color: Color(0xFF4CC9F0), size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Outgoing Shift Handover',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'User: ${widget.username}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Generate Snapshot Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreating ? null : _generateSnapshot,
              icon: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt),
              label: Text(_previewSnapshot == null
                  ? 'Generate Factory Snapshot'
                  : 'Regenerate Snapshot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CC9F0),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Snapshot Preview
          if (_previewSnapshot != null) ...[
            _SnapshotPreview(snapshot: _previewSnapshot!),
            const SizedBox(height: 24),
          ],

          // Notes Section
          const Text(
            'Handover Notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'General notes for incoming shift...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Safety Notes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _safetyNotesController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Any safety concerns or warnings...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Special Instructions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _specialInstructionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Special instructions for incoming shift...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  _isCreating || _previewSnapshot == null ? null : _createHandover,
              icon: const Icon(Icons.check_circle),
              label: const Text('Create Handover & Sign Off'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============ INCOMING SHIFT TAB ============

class _IncomingShiftTab extends StatelessWidget {
  final String username;
  final List<ShiftHandover> handovers;
  final VoidCallback onRefresh;

  const _IncomingShiftTab({
    required this.username,
    required this.handovers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (handovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'No pending handovers',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            const Text(
              'Handovers from outgoing shifts will appear here',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: handovers.length,
      itemBuilder: (context, index) {
        final handover = handovers[index];
        return _IncomingHandoverCard(
          handover: handover,
          username: username,
          onAcknowledge: onRefresh,
        );
      },
    );
  }
}

class _IncomingHandoverCard extends StatelessWidget {
  final ShiftHandover handover;
  final String username;
  final VoidCallback onAcknowledge;

  const _IncomingHandoverCard({
    required this.handover,
    required this.username,
    required this.onAcknowledge,
  });

  Future<void> _acknowledgeHandover(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acknowledge Handover'),
        content: const Text(
          'By acknowledging this handover, you confirm that you have reviewed '
          'the factory state and are ready to take over the shift.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = RBACService.currentUser;
        if (currentUser == null) {
          throw Exception('No user logged in');
        }

        await HandoverService.acknowledgeHandover(
          handoverId: handover.id,
          userId: currentUser.id,
          userName: currentUser.username,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Handover acknowledged successfully'),
              backgroundColor: Colors.green,
            ),
          );
          onAcknowledge();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to acknowledge: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF4CC9F0)),
                const SizedBox(width: 8),
                Text(
                  'From: ${handover.outgoingUserName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(handover.handoverDate),
              style: const TextStyle(color: Colors.white70),
            ),
            if (handover.notes != null) ...[
              const SizedBox(height: 12),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(handover.notes!, style: const TextStyle(color: Colors.white70)),
            ],
            if (handover.safetyNotes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  const Text('Safety:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              Text(handover.safetyNotes!,
                  style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 16),

            // Snapshot Summary
            if (handover.snapshot != null) ...[
              _SnapshotSummary(snapshot: handover.snapshot!),
              const SizedBox(height: 16),
            ],

            // Acknowledge Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _acknowledgeHandover(context),
                icon: const Icon(Icons.check),
                label: const Text('Acknowledge & Accept Shift'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ HISTORY TAB ============

class _HandoverHistoryTab extends StatelessWidget {
  final List<ShiftHandover> handovers;
  final VoidCallback onRefresh;

  const _HandoverHistoryTab({
    required this.handovers,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final completedHandovers = handovers
        .where((h) =>
            h.status == HandoverStatus.complete ||
            h.status == HandoverStatus.skipped)
        .toList();

    if (completedHandovers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            const Text(
              'No handover history',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: completedHandovers.length,
        itemBuilder: (context, index) {
          final handover = completedHandovers[index];
          return _HistoryCard(handover: handover);
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ShiftHandover handover;

  const _HistoryCard({required this.handover});

  @override
  Widget build(BuildContext context) {
    final isComplete = handover.status == HandoverStatus.complete;

    return Card(
      color: const Color(0xFF1A1F2E),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          isComplete ? Icons.check_circle : Icons.cancel,
          color: isComplete ? Colors.green : Colors.orange,
        ),
        title: Text('${handover.outgoingUserName} → ${handover.incomingUserName ?? "N/A"}'),
        subtitle: Text(
          DateFormat('MMM d, yyyy HH:mm').format(handover.handoverDate),
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isComplete
                ? Colors.green.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            handover.status.displayName,
            style: TextStyle(
              color: isComplete ? Colors.green : Colors.orange,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () => _showHandoverDetails(context),
      ),
    );
  }

  void _showHandoverDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Handover Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _DetailRow('Outgoing', handover.outgoingUserName),
              _DetailRow('Incoming', handover.incomingUserName ?? 'N/A'),
              _DetailRow('Date',
                  DateFormat('MMM d, yyyy HH:mm').format(handover.handoverDate)),
              _DetailRow('Status', handover.status.displayName),
              if (handover.duration != null)
                _DetailRow('Duration', '${handover.duration!.inMinutes} minutes'),
              if (handover.notes != null) ...[
                const SizedBox(height: 16),
                const Text('Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(handover.notes!),
              ],
              if (handover.safetyNotes != null) ...[
                const SizedBox(height: 8),
                const Text('Safety Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(handover.safetyNotes!,
                    style: const TextStyle(color: Colors.orange)),
              ],
              if (handover.snapshot != null) ...[
                const SizedBox(height: 16),
                const Text('Snapshot Summary:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _SnapshotSummary(snapshot: handover.snapshot!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ============ SNAPSHOT WIDGETS ============

class _SnapshotPreview extends StatelessWidget {
  final HandoverSnapshot snapshot;

  const _SnapshotPreview({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt, color: Color(0xFF4CC9F0)),
              const SizedBox(width: 8),
              const Text(
                'Factory Snapshot',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                DateFormat('HH:mm').format(snapshot.capturedAt),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          const Divider(height: 24),
          _SnapshotSummary(snapshot: snapshot),
        ],
      ),
    );
  }
}

class _SnapshotSummary extends StatelessWidget {
  final HandoverSnapshot snapshot;

  const _SnapshotSummary({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final summary = snapshot.productionSummary;
    final runningMachines =
        snapshot.machines.where((m) => m.status == 'Running').length;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _StatChip(
          icon: Icons.precision_manufacturing,
          label: 'Machines',
          value: '$runningMachines/${snapshot.machines.length}',
          color: Colors.blue,
        ),
        _StatChip(
          icon: Icons.work,
          label: 'Jobs',
          value: '${snapshot.jobs.length}',
          color: Colors.green,
        ),
        _StatChip(
          icon: Icons.warning,
          label: 'Issues',
          value: '${snapshot.openIssues.length}',
          color: snapshot.openIssues.isNotEmpty ? Colors.red : Colors.grey,
        ),
        _StatChip(
          icon: Icons.task,
          label: 'Tasks',
          value: '${snapshot.pendingTasks.length}',
          color: Colors.orange,
        ),
        _StatChip(
          icon: Icons.inventory,
          label: 'Parts',
          value: '${summary.totalParts}',
          color: Colors.teal,
        ),
        _StatChip(
          icon: Icons.delete,
          label: 'Scrap',
          value: '${summary.scrapRate.toStringAsFixed(1)}%',
          color: summary.scrapRate > 5 ? Colors.red : Colors.grey,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color)),
              Text(value,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}
