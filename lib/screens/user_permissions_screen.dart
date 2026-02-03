import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../utils/user_permissions.dart';
import '../services/sync_service.dart';
import '../services/log_service.dart';

class UserPermissionsScreen extends StatefulWidget {
  const UserPermissionsScreen({super.key});

  @override
  State<UserPermissionsScreen> createState() => _UserPermissionsScreenState();
}

class _UserPermissionsScreenState extends State<UserPermissionsScreen> {
  String? _selectedUsername;
  Map<String, bool> _permissions = {};

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        title: const Text('User Permissions'),
        backgroundColor: const Color(0xFF0F1419),
      ),
      body: isPortrait
          ? Column(
              children: [
                // User list (top half in portrait)
                Expanded(
                  flex: 1,
                  child: _buildUserList(),
                ),
                const Divider(height: 1),
                // Permissions editor (bottom half in portrait)
                Expanded(
                  flex: 2,
                  child: _selectedUsername == null
                      ? const Center(
                          child: Text(
                            'Select a user to edit permissions',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : _buildPermissionsEditor(),
                ),
              ],
            )
          : Row(
              children: [
                // User list (left side in landscape)
                SizedBox(
                  width: 250,
                  child: _buildUserList(),
                ),
                const VerticalDivider(width: 1),
                // Permissions editor (right side in landscape)
                Expanded(
                  child: _selectedUsername == null
                      ? const Center(
                          child: Text(
                            'Select a user to edit permissions',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : _buildPermissionsEditor(),
                ),
              ],
            ),
    );
  }

  Widget _buildUserList() {
    final usersBox = Hive.box('usersBox');
    final users = usersBox.values.cast<Map>().toList();

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final username = user['username'] as String;
        final level = user['level'] as int;
        final isSelected = username == _selectedUsername;

        return ListTile(
          selected: isSelected,
          selectedTileColor: Colors.blue.withOpacity(0.2),
          title: Text(
            username,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            'Level $level',
            style: const TextStyle(color: Colors.white70),
          ),
          onTap: () => _selectUser(username, user),
        );
      },
    );
  }

  void _selectUser(String username, Map user) {
    setState(() {
      _selectedUsername = username;
      final level = user['level'] as int;

      // Start with defaults for this level
      _permissions = UserPermissions.getDefaultPermissions(level);

      // Merge in any custom permissions (overriding defaults)
      if (user['permissions'] != null) {
        final customPermissions =
            Map<String, bool>.from(user['permissions'] as Map);
        _permissions.addAll(customPermissions);
      }

      LogService.debug(
          'Loaded permissions for $username (level $level): $_permissions');
    });
  }

  Widget _buildPermissionsEditor() {
    final allPermissions = UserPermissions.getAllPermissions();

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1A1F2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Permissions for $_selectedUsername',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: OutlinedButton(
                            onPressed: _resetToDefaults,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                            ),
                            child: const Text('Reset to Defaults'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ElevatedButton(
                            onPressed: _savePermissions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Save Permissions'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Permissions list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: allPermissions.length,
            itemBuilder: (context, index) {
              final permission = allPermissions[index];
              final pageName = UserPermissions.getPageName(permission);
              final isEnabled = _permissions[permission] ?? false;

              return Card(
                color: const Color(0xFF1A1F2E),
                margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  title: Text(
                    pageName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    permission,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: isEnabled,
                  onChanged: (value) {
                    setState(() {
                      _permissions[permission] = value;
                    });
                  },
                  activeColor: Colors.green,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _resetToDefaults() async {
    if (_selectedUsername == null) return;

    try {
      final usersBox = Hive.box('usersBox');

      // Find user by iterating through all entries to get the correct key
      dynamic userKey;
      Map? userData;
      
      for (var key in usersBox.keys) {
        final user = usersBox.get(key) as Map?;
        if (user != null && user['username'] == _selectedUsername) {
          userKey = key;
          userData = user;
          break;
        }
      }

      if (userData == null || userKey == null) {
        throw Exception('User not found: $_selectedUsername');
      }

      final user = Map<String, dynamic>.from(userData);
      final level = user['level'] as int;

      // Reset to defaults
      final defaults = UserPermissions.getDefaultPermissions(level);
      setState(() {
        _permissions = Map<String, bool>.from(defaults);
      });

      // Save the reset permissions using the original key
      user['permissions'] = Map<String, bool>.from(_permissions);
      await usersBox.put(userKey, user);
      await SyncService.pushChange('usersBox', userKey.toString(), user);

      LogService.info('Reset permissions to defaults for $_selectedUsername');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset to default permissions and saved'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LogService.error('Failed to reset permissions', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedUsername == null) {
      LogService.warning('No user selected for permissions save');
      return;
    }

    try {
      final usersBox = Hive.box('usersBox');

      LogService.debug(
          'Attempting to save permissions for: $_selectedUsername');
      LogService.debug('Permissions to save: $_permissions');

      // Find user by iterating through all entries to get the correct key
      dynamic userKey;
      Map? userData;
      
      for (var key in usersBox.keys) {
        final user = usersBox.get(key) as Map?;
        if (user != null && user['username'] == _selectedUsername) {
          userKey = key;
          userData = user;
          LogService.debug('Found user at key: $key');
          break;
        }
      }

      if (userData == null || userKey == null) {
        LogService.error(
            'User not found after search: $_selectedUsername', null);
        throw Exception('User not found: $_selectedUsername');
      }

      final user = Map<String, dynamic>.from(userData);

      // Save the complete permission set
      user['permissions'] = Map<String, bool>.from(_permissions);

      LogService.debug(
          'Saving user with permissions to key: $userKey');
      LogService.debug('User data before save: ${user.toString()}');
      LogService.debug('Permissions being saved: $_permissions');

      // Save using the original key (could be index or username)
      await usersBox.put(userKey, user);

      // Verify the save
      final savedUser = usersBox.get(userKey);
      LogService.debug('User data after save: ${savedUser.toString()}');

      await SyncService.pushChange('usersBox', userKey.toString(), user);

      LogService.info(
          'Successfully updated permissions for $_selectedUsername');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissions saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      LogService.error('Failed to save permissions: $e', null);
      LogService.debug('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving permissions: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
