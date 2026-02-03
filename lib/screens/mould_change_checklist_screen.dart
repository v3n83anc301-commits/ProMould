import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/sync_service.dart';
import '../services/log_service.dart';

class MouldChangeChecklistScreen extends StatefulWidget {
  final int level;
  const MouldChangeChecklistScreen({super.key, required this.level});

  @override
  State<MouldChangeChecklistScreen> createState() =>
      _MouldChangeChecklistScreenState();
}

class _MouldChangeChecklistScreenState
    extends State<MouldChangeChecklistScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  bool _isInitialized = false;

  // General Details Controllers
  final _machineIdCtrl = TextEditingController();
  final _mouldRemovedCtrl = TextEditingController();
  final _mouldInstalledCtrl = TextEditingController();
  final _setterNameCtrl = TextEditingController();
  final _assistantNamesCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();

  // Checklist items
  final Map<String, bool> _removalChecks = {};
  final Map<String, String> _removalComments = {};
  final Map<String, bool> _installationChecks = {};
  final Map<String, String> _installationComments = {};
  final Map<String, bool> _testingChecks = {};
  final Map<String, String> _testingComments = {};
  final Map<String, bool> _signoffChecks = {};
  final Map<String, String> _signoffComments = {};

  final List<Map<String, String>> _removalItems = [
    {
      'id': 'removal_1',
      'text': 'Machine powered down and locked out (LOTO procedure followed)'
    },
    {
      'id': 'removal_2',
      'text': 'Mould surface and cavities cleaned (internally and externally)'
    },
    {
      'id': 'removal_3',
      'text': 'All plastic residue, runners, and parts removed'
    },
    {'id': 'removal_4', 'text': 'Water channels blown out with compressed air'},
    {
      'id': 'removal_5',
      'text': 'Air and hydraulic lines disconnected safely and labeled'
    },
    {
      'id': 'removal_6',
      'text':
          'Wear pads, guide pillars, and moving components cleaned and greased'
    },
    {'id': 'removal_7', 'text': 'Mould condition checked for visible damage'},
    {
      'id': 'removal_8',
      'text': 'Nozzles, nipples, and couplings checked for wear/damage'
    },
    {'id': 'removal_9', 'text': 'Area cleared of tools and foreign objects'},
    {'id': 'removal_10', 'text': 'Removal documented in system'},
  ];

  final List<Map<String, String>> _installationItems = [
    {
      'id': 'install_1',
      'text': 'Correct mould verified against production job card'
    },
    {
      'id': 'install_2',
      'text': 'Mould cleaned and inspected prior to installation'
    },
    {
      'id': 'install_3',
      'text': 'Mould properly aligned and seated on machine platens'
    },
    {'id': 'install_4', 'text': 'Clamps tightened to specified torque'},
    {'id': 'install_5', 'text': 'Water lines connected and leak-tested'},
    {'id': 'install_6', 'text': 'Air and hydraulic lines connected correctly'},
    {'id': 'install_7', 'text': 'Ejector system tested for smooth operation'},
    {'id': 'install_8', 'text': 'Safety guards and interlocks verified'},
    {'id': 'install_9', 'text': 'First shot inspection completed'},
    {'id': 'install_10', 'text': 'Installation documented in system'},
  ];

  final List<Map<String, String>> _testingItems = [
    {
      'id': 'test_1',
      'text': 'Machine dry-cycled successfully (no mould damage)'
    },
    {
      'id': 'test_2',
      'text': 'Mould temperature controllers set to specification'
    },
    {'id': 'test_3', 'text': 'Cooling water flow rates verified'},
    {'id': 'test_4', 'text': 'Injection pressure and speed parameters set'},
    {'id': 'test_5', 'text': 'Cycle time tested and optimized'},
    {'id': 'test_6', 'text': 'Part ejection tested (no sticking or damage)'},
    {'id': 'test_7', 'text': 'First article inspection passed (dimensions OK)'},
    {'id': 'test_8', 'text': 'Color and finish verified against standard'},
    {'id': 'test_9', 'text': 'No flash, short shots, or defects observed'},
    {'id': 'test_10', 'text': 'Production parameters recorded in system'},
  ];

  final List<Map<String, String>> _signoffItems = [
    {'id': 'signoff_1', 'text': 'All checklist items completed and verified'},
    {'id': 'signoff_2', 'text': 'Mould change time recorded (start to finish)'},
    {'id': 'signoff_3', 'text': 'Any issues or observations documented'},
    {'id': 'signoff_4', 'text': 'Spare parts used recorded in inventory'},
    {'id': 'signoff_5', 'text': 'Machine ready for production handover'},
    {'id': 'signoff_6', 'text': 'Setter signature and date confirmed'},
    {'id': 'signoff_7', 'text': 'Supervisor notified of completion'},
    {'id': 'signoff_8', 'text': 'Production team briefed on new mould/job'},
    {'id': 'signoff_9', 'text': 'All tools and equipment returned to storage'},
    {'id': 'signoff_10', 'text': 'Work area cleaned and organized'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeBoxAndChecks();
  }

  Future<void> _initializeBoxAndChecks() async {
    // Ensure box is open
    if (!Hive.isBoxOpen('mouldChangesBox')) {
      await Hive.openBox('mouldChangesBox');
    }
    
    // Initialize all checks to false
    for (var item in _removalItems) {
      _removalChecks[item['id']!] = false;
      _removalComments[item['id']!] = '';
    }
    for (var item in _installationItems) {
      _installationChecks[item['id']!] = false;
      _installationComments[item['id']!] = '';
    }
    for (var item in _testingItems) {
      _testingChecks[item['id']!] = false;
      _testingComments[item['id']!] = '';
    }
    for (var item in _signoffItems) {
      _signoffChecks[item['id']!] = false;
      _signoffComments[item['id']!] = '';
    }
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _machineIdCtrl.dispose();
    _mouldRemovedCtrl.dispose();
    _mouldInstalledCtrl.dispose();
    _setterNameCtrl.dispose();
    _assistantNamesCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChecklist() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final id = _uuid.v4();
      final data = {
        'id': id,
        'machineId': _machineIdCtrl.text.trim(),
        'mouldRemoved': _mouldRemovedCtrl.text.trim(),
        'mouldInstalled': _mouldInstalledCtrl.text.trim(),
        'date': _selectedDate.toIso8601String(),
        'startTime': '${_startTime.hour}:${_startTime.minute}',
        'setterName': _setterNameCtrl.text.trim(),
        'assistantNames': _assistantNamesCtrl.text.trim(),
        'removalChecks': _removalChecks,
        'removalComments': _removalComments,
        'installationChecks': _installationChecks,
        'installationComments': _installationComments,
        'testingChecks': _testingChecks,
        'testingComments': _testingComments,
        'signoffChecks': _signoffChecks,
        'signoffComments': _signoffComments,
        'completedAt': DateTime.now().toIso8601String(),
        'completedBy': _setterNameCtrl.text.trim(),
      };

      // Use existing box or open if needed
      final box = Hive.isBoxOpen('mouldChangesBox')
          ? Hive.box('mouldChangesBox')
          : await Hive.openBox('mouldChangesBox');

      await box.put(id, data);
      await SyncService.pushChange('mouldChangesBox', id, data);

      LogService.info('Mould change checklist saved: $id');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mould change checklist saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Pop back to the drawer/home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      LogService.error('Failed to save mould change checklist', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          title: const Text('Mould Change Checklist'),
          backgroundColor: const Color(0xFF0F1419),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('Mould Change Checklist'),
        backgroundColor: const Color(0xFF0F1419),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChecklist,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGeneralDetails(),
            const SizedBox(height: 24),
            _buildSection(
              'Section 1: Mould Removal Checklist',
              _removalItems,
              _removalChecks,
              _removalComments,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Section 2: Mould Installation Checklist',
              _installationItems,
              _installationChecks,
              _installationComments,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Section 3: Post-Installation Testing',
              _testingItems,
              _testingChecks,
              _testingComments,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Section 4: Final Sign-off & Documentation',
              _signoffItems,
              _signoffChecks,
              _signoffComments,
            ),
            const SizedBox(height: 24),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralDetails() {
    return Card(
      color: const Color(0xFF1A1F2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'General Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _machineIdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Machine ID',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mouldRemovedCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mould Removed',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mouldInstalledCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mould Installed',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              title:
                  const Text('Date', style: TextStyle(color: Colors.white70)),
              subtitle: Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.calendar_today, color: Colors.blue),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
            ),
            ListTile(
              title: const Text('Start Time',
                  style: TextStyle(color: Colors.white70)),
              subtitle: Text(
                _startTime.format(context),
                style: const TextStyle(color: Colors.white),
              ),
              trailing: const Icon(Icons.access_time, color: Colors.blue),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (time != null) {
                  setState(() => _startTime = time);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _setterNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Setter Name',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _assistantNamesCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Assistant Name(s)',
                labelStyle: TextStyle(color: Colors.white70),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Map<String, String>> items,
    Map<String, bool> checks,
    Map<String, String> comments,
  ) {
    return Card(
      color: const Color(0xFF1A1F2E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              final id = item['id']!;
              return _buildChecklistItem(
                index,
                item['text']!,
                checks[id] ?? false,
                comments[id] ?? '',
                (value) => setState(() => checks[id] = value),
                (value) => comments[id] = value,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    int number,
    String text,
    bool checked,
    String comment,
    Function(bool) onCheckChanged,
    Function(String) onCommentChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '$number.',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Checkbox(
              value: checked,
              onChanged: (value) => onCheckChanged(value ?? false),
              activeColor: Colors.green,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 30, right: 16, bottom: 16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Comments (optional)',
              hintStyle: TextStyle(color: Colors.white38),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onCommentChanged,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saveChecklist,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
        ),
        child: const Text(
          'Save Checklist',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
