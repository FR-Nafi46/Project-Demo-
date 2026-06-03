import 'package:flutter/material.dart';
import 'supabase_service.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  int _selectedTab = 0;
  List<Map<String, dynamic>> _verificationRequests = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _adminLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final requests = await SupabaseService.getVerificationRequests();
      final users = await SupabaseService.getAllUsers();
      final logs = await SupabaseService.getAdminLogs();

      // Generate signed URLs for NID images (private bucket)
      final enrichedRequests = await Future.wait(requests.map((req) async {
        final Map<String, dynamic> enriched = Map.from(req);
        if (req['nid_front_url'] != null) {
          try {
            final signed = await SupabaseService.getSignedNIDUrl(req['nid_front_url'] as String);
            enriched['nid_front_signed'] = signed;
          } catch (_) {
            enriched['nid_front_signed'] = req['nid_front_url'];
          }
        }
        if (req['nid_back_url'] != null) {
          try {
            final signed = await SupabaseService.getSignedNIDUrl(req['nid_back_url'] as String);
            enriched['nid_back_signed'] = signed;
          } catch (_) {
            enriched['nid_back_signed'] = req['nid_back_url'];
          }
        }
        return enriched;
      }));

      setState(() {
        _verificationRequests = enrichedRequests;
        _users = users;
        _adminLogs = logs;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _approveVerification(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Verification'),
        content: const Text('Are you sure you want to approve this user\'s NID verification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SupabaseService.approveVerification(userId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification approved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectVerification(String userId) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g., Image unclear, Invalid NID',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      await SupabaseService.rejectVerification(userId, reason);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification rejected'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleBan(String userId, bool isCurrentlyBanned, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCurrentlyBanned ? 'Unban User' : 'Ban User'),
        content: Text('Are you sure you want to ${isCurrentlyBanned ? 'unban' : 'ban'} $userName?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyBanned ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isCurrentlyBanned ? 'Unban' : 'Ban'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SupabaseService.banUser(userId, !isCurrentlyBanned);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${isCurrentlyBanned ? 'unbanned' : 'banned'} successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleAdmin(String userId, bool isCurrentlyAdmin, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCurrentlyAdmin ? 'Remove Admin' : 'Make Admin'),
        content: Text(
            'Are you sure you want to ${isCurrentlyAdmin ? 'remove admin privileges from' : 'make'} $userName ${isCurrentlyAdmin ? '' : 'an admin'}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(isCurrentlyAdmin ? 'Remove' : 'Make Admin'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await SupabaseService.setAdminStatus(userId, !isCurrentlyAdmin);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Admin status updated for $userName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Admin Panel'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _tabButton('Verification', 0, Icons.verified_user),
                const SizedBox(width: 12),
                _tabButton('Users', 1, Icons.people),
                const SizedBox(width: 12),
                _tabButton('Logs', 2, Icons.history),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _VerificationTab(
                  requests: _verificationRequests,
                  onApprove: _approveVerification,
                  onReject: _rejectVerification,
                ),
                _UsersTab(
                  users: _users,
                  currentUserId: SupabaseService.currentUserId,
                  onToggleBan: _toggleBan,
                  onToggleAdmin: _toggleAdmin,
                ),
                _LogsTab(logs: _adminLogs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String title;

  const _FullScreenImageViewer({required this.imageUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
        centerTitle: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (_, __, ___) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.white54, size: 80),
                const SizedBox(height: 16),
                Text('Could not load image', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification Tab
// ─────────────────────────────────────────────────────────────────────────────
class _VerificationTab extends StatelessWidget {
  final List<Map<String, dynamic>> requests;
  final Function(String) onApprove;
  final Function(String) onReject;

  const _VerificationTab({
    required this.requests,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No pending verifications', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (_, i) {
        final req = requests[i];
        // Use signed URLs if available, fallback to original URLs
        final frontUrl = req['nid_front_signed'] as String? ?? req['nid_front_url'] as String?;
        final backUrl = req['nid_back_signed'] as String? ?? req['nid_back_url'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info row
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF381932).withOpacity(0.1),
                    child: Text(
                      (req['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF381932)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          req['full_name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          req['email'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (req['verification_requested_at'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Requested: ${_formatDate(req['verification_requested_at'])}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // NID Images label
              Row(
                children: [
                  const Icon(Icons.badge, size: 16, color: Color(0xFF381932)),
                  const SizedBox(width: 6),
                  const Text(
                    'NID Card Images',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to enlarge',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.zoom_in, size: 14, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 10),

              // NID image previews — side by side
              Row(
                children: [
                  Expanded(
                    child: _imagePreview(
                      context: context,
                      url: frontUrl,
                      label: 'Front Side',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _imagePreview(
                      context: context,
                      url: backUrl,
                      label: 'Back Side',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onReject(req['id']),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => onApprove(req['id']),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _imagePreview({
    required BuildContext context,
    required String? url,
    required String label,
  }) {
    if (url == null || url.isEmpty) {
      return Container(
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text('Not uploaded', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              imageUrl: url,
              title: 'NID $label',
            ),
          ),
        );
      },
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: const Color(0xFF381932),
                        ),
                        const SizedBox(height: 6),
                        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey.shade400, size: 32),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Text('Load failed', style: TextStyle(fontSize: 10, color: Colors.red.shade300)),
                  ],
                ),
              ),
              // Label badge at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.zoom_in, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Users Tab
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final String? currentUserId;
  final Function(String, bool, String) onToggleBan;
  final Function(String, bool, String) onToggleAdmin;

  const _UsersTab({
    required this.users,
    required this.currentUserId,
    required this.onToggleBan,
    required this.onToggleAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        final userId = user['id'];
        final isCurrentUser = userId == currentUserId;
        final isBanned = user['is_banned'] == true;
        final isAdmin = user['is_admin'] == true;
        final isVerified = user['nid_verified'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBanned ? Colors.red.shade200 : Colors.grey.shade200,
              width: isBanned ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF381932).withOpacity(0.1),
                    child: Text(
                      (user['full_name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF381932)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user['full_name'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Admin',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                                ),
                              ),
                            ],
                            if (isVerified) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Colors.green, size: 16),
                            ],
                          ],
                        ),
                        Text(
                          user['email'] ?? '',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Joined: ${_formatDate(user['created_at'])}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!isCurrentUser) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onToggleBan(userId, isBanned, user['full_name'] ?? 'User'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isBanned ? Colors.green : Colors.red,
                          side: BorderSide(color: isBanned ? Colors.green : Colors.red),
                        ),
                        child: Text(isBanned ? 'Unban' : 'Ban'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onToggleAdmin(userId, isAdmin, user['full_name'] ?? 'User'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF381932),
                          side: const BorderSide(color: Color(0xFF381932)),
                        ),
                        child: Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return 'Unknown';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logs Tab
// ─────────────────────────────────────────────────────────────────────────────
class _LogsTab extends StatelessWidget {
  final List<Map<String, dynamic>> logs;

  const _LogsTab({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No admin logs yet', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final log = logs[i];
        final action = log['action'] ?? 'unknown';
        final admin = log['admin'] as Map<String, dynamic>?;
        final target = log['target'] as Map<String, dynamic>?;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(_getActionIcon(action), size: 24, color: _getActionColor(action)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getActionText(action, admin, target),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(log['created_at']),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'approve_verification':
        return Icons.verified;
      case 'reject_verification':
        return Icons.cancel;
      case 'ban_user':
        return Icons.block;
      case 'unban_user':
        return Icons.check_circle;
      case 'make_admin':
        return Icons.admin_panel_settings;
      case 'remove_admin':
        return Icons.person_remove;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'approve_verification':
        return Colors.green;
      case 'reject_verification':
        return Colors.red;
      case 'ban_user':
        return Colors.red;
      case 'unban_user':
        return Colors.green;
      case 'make_admin':
        return Colors.amber;
      case 'remove_admin':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getActionText(String action, Map<String, dynamic>? admin, Map<String, dynamic>? target) {
    final adminName = admin?['full_name'] ?? 'Admin';
    final targetName = target?['full_name'] ?? 'User';

    switch (action) {
      case 'approve_verification':
        return '$adminName approved NID verification for $targetName';
      case 'reject_verification':
        return '$adminName rejected NID verification for $targetName';
      case 'ban_user':
        return '$adminName banned $targetName';
      case 'unban_user':
        return '$adminName unbanned $targetName';
      case 'make_admin':
        return '$adminName made $targetName an admin';
      case 'remove_admin':
        return '$adminName removed admin privileges from $targetName';
      default:
        return '$adminName performed $action';
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes} minutes ago';
      if (diff.inDays < 1) return '${diff.inHours} hours ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return '';
    }
  }
}