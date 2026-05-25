import 'package:flutter/material.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────────────────────────
// ChatListPage
// ─────────────────────────────────────────────────────────────
class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  List<Map<String, dynamic>> conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUserId;
    if (uid == null) { setState(() => _loading = false); return; }
    try {
      final data = await SupabaseService.fetchConversations(uid);
      setState(() { conversations = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  String _otherName(Map<String, dynamic> conv) {
    final uid = SupabaseService.currentUserId;
    final buyer = conv['buyer'] as Map<String, dynamic>?;
    final seller = conv['seller'] as Map<String, dynamic>?;
    if (conv['buyer_id'] == uid) return seller?['full_name'] ?? 'Seller';
    return buyer?['full_name'] ?? 'Buyer';
  }

  String _otherAvatar(Map<String, dynamic> conv) {
    final uid = SupabaseService.currentUserId;
    final buyer = conv['buyer'] as Map<String, dynamic>?;
    final seller = conv['seller'] as Map<String, dynamic>?;
    if (conv['buyer_id'] == uid) return seller?['avatar_url'] ?? '';
    return buyer?['avatar_url'] ?? '';
  }

  String _lastMessage(Map<String, dynamic> conv) {
    final msgs = conv['messages'];
    if (msgs == null || (msgs as List).isEmpty) return 'No messages yet';
    final last = msgs.last as Map<String, dynamic>;
    return last['text'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor, foregroundColor: Colors.white,
        title: const Text('Messages'), centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SupabaseService.currentUserId == null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Text('Please log in to view messages'),
      ]))
          : conversations.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        Text('Start a conversation from a product page', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
      ]))
          : RefreshIndicator(
        onRefresh: _load,
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: conversations.length,
          itemBuilder: (_, i) {
            final conv = conversations[i];
            return _ConvCard(
              name: _otherName(conv),
              avatar: _otherAvatar(conv),
              lastMessage: _lastMessage(conv),
              productName: (conv['products'] as Map<String, dynamic>?)?['name'],
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailPage(
                conversationId: conv['id'],
                otherUserName: _otherName(conv),
                otherUserAvatar: _otherAvatar(conv),
                productName: (conv['products'] as Map<String, dynamic>?)?['name'],
              ))).then((_) => _load()),
            );
          },
        ),
      ),
    );
  }
}

class _ConvCard extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final String name, avatar, lastMessage;
  final String? productName;
  final VoidCallback onTap;
  const _ConvCard({required this.name, required this.avatar, required this.lastMessage, this.productName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          backgroundColor: primaryColor.withOpacity(0.2),
          child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
          if (productName != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('Re: $productName', style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w500)),
            ),
          ],
        ]),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ChatDetailPage
// ─────────────────────────────────────────────────────────────
class ChatDetailPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserAvatar;
  final String? productName;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserAvatar,
    this.productName,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  static const Color primaryColor = Color(0xFF381932);
  static const Color backgroundColor = Color(0xFFF0EDE9);

  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await SupabaseService.fetchMessages(widget.conversationId);
      setState(() { _messages = data; _loading = false; });
      _scrollToBottom();
    } catch (_) { setState(() => _loading = false); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    final uid = SupabaseService.currentUserId;
    if (uid == null) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await SupabaseService.sendMessage(widget.conversationId, uid, text);
      await _loadMessages();
    } catch (_) {} finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.currentUserId;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: widget.otherUserAvatar.isNotEmpty ? NetworkImage(widget.otherUserAvatar) : null,
            backgroundColor: Colors.white24,
            child: widget.otherUserAvatar.isEmpty ? const Icon(Icons.person, size: 16) : null,
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.otherUserName, style: const TextStyle(fontSize: 16)),
            if (widget.productName != null)
              Text('Re: ${widget.productName}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
        ]),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final msg = _messages[i];
                final isMe = msg['sender_id'] == myId;
                return _MessageBubble(text: msg['text'] ?? '', isMe: isMe, time: _formatTime(msg['created_at']));
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: backgroundColor, borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(hintText: 'Type a message…', border: InputBorder.none),
                    maxLines: null,
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                child: IconButton(
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: _sending ? null : _send,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $period';
    } catch (_) { return ''; }
  }
}

class _MessageBubble extends StatelessWidget {
  static const Color primaryColor = Color(0xFF381932);
  final String text, time;
  final bool isMe;
  const _MessageBubble({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade600)),
        ]),
      ),
    );
  }
}