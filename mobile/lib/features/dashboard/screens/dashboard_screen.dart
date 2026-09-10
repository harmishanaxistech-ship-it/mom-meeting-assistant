import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/background_processing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../meetings/controllers/meeting_controller.dart';
import '../../meetings/screens/create_meeting_screen.dart';
import '../../meetings/screens/meeting_details_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _filterDate;
  String _searchQuery = '';
  String _selectedFilterChip = 'All'; // 'All', 'Completed', 'Processing', 'Today', 'Audio'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF10B981);
      case 'transcribing':
      case 'analyzing':
      case 'mom_generated':
      case 'uploading':
        return const Color(0xFFF59E0B);
      case 'failed':
        return AppTheme.errorColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'MOM READY';
      case 'transcribing':
        return 'TRANSCRIBING';
      case 'analyzing':
        return 'ANALYZING';
      case 'mom_generated':
        return 'PROCESSING';
      case 'uploading':
        return 'UPLOADING';
      case 'failed':
        return 'FAILED';
      default:
        return status.toUpperCase();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              minimumSize: const Size(90, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backgroundProcessingProvider);
    final authState = ref.watch(authControllerProvider);
    final meetingState = ref.watch(meetingControllerProvider);
    final user = authState.user;
    final now = DateTime.now();

    // Calculate metrics
    final totalCount = meetingState.meetings.length;
    final completedCount = meetingState.meetings.where((m) => m.status == 'completed').length;
    final inProgressCount = meetingState.meetings.where((m) => m.status != 'completed' && m.status != 'failed').length;

    // Filter meetings based on Date, Search, and Filter Chip
    final filteredMeetings = meetingState.meetings.where((m) {
      if (_filterDate != null) {
        final sameDay = m.dateTime.year == _filterDate!.year &&
            m.dateTime.month == _filterDate!.month &&
            m.dateTime.day == _filterDate!.day;
        if (!sameDay) return false;
      }

      // Filter chips
      if (_selectedFilterChip == 'Completed' && m.status != 'completed') {
        return false;
      } else if (_selectedFilterChip == 'Processing' && (m.status == 'completed' || m.status == 'failed')) {
        return false;
      } else if (_selectedFilterChip == 'Today') {
        final isToday = m.dateTime.year == now.year &&
            m.dateTime.month == now.month &&
            m.dateTime.day == now.day;
        if (!isToday) return false;
      } else if (_selectedFilterChip == 'Audio') {
        final hasAudio = m.audioFileName != null && m.audioFileName!.isNotEmpty;
        if (!hasAudio) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = m.title.toLowerCase().contains(query);
        final matchAgenda = m.agenda.toLowerCase().contains(query);
        final matchType = m.meetingType.toLowerCase().contains(query);
        if (!matchTitle && !matchAgenda && !matchType) return false;
      }
      return true;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    letterSpacing: -0.3,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'AI Meeting Studio',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF475569)),
            ),
            tooltip: 'Refresh Meetings',
            onPressed: () => ref.read(meetingControllerProvider.notifier).fetchMeetings(),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFEF4444)),
            ),
            tooltip: 'Logout',
            onPressed: () => _showLogoutDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateMeetingScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
        label: const Text(
          'New Meeting',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF1E3A8A),
          onRefresh: () => ref.read(meetingControllerProvider.notifier).fetchMeetings(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Executive Hero Banner Card
                      _buildHeroCard(user?.name, user?.email, totalCount, completedCount, inProgressCount),
                      const SizedBox(height: 16),

                      // Search Bar & Date Picker Row
                      _buildSearchAndDateRow(),
                      const SizedBox(height: 12),

                      // Interactive Filter Chips Row
                      _buildFilterChipsRow(totalCount, completedCount, inProgressCount),
                      const SizedBox(height: 16),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                _filterDate != null
                                    ? 'Meetings on ${DateFormat('dd MMM yyyy').format(_filterDate!)}'
                                    : _selectedFilterChip == 'All'
                                        ? 'All Meetings'
                                        : '$_selectedFilterChip Meetings',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${filteredMeetings.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_filterDate != null || _selectedFilterChip != 'All' || _searchQuery.isNotEmpty)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _filterDate = null;
                                  _selectedFilterChip = 'All';
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  'Reset Filters',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Meetings List or Empty State
              if (meetingState.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  ),
                )
              else if (filteredMeetings.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final meeting = filteredMeetings[index];
                        return _buildMeetingCard(meeting);
                      },
                      childCount: filteredMeetings.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Hero Card with Gradient & KPI Metrics
  Widget _buildHeroCard(String? name, String? email, int total, int completed, int inProgress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(80),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & User row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(50), width: 2),
                ),
                child: Center(
                  child: Text(
                    (name != null && name.isNotEmpty) ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()}, ${name ?? 'Executive'} 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      email ?? 'Ready to summarize meetings',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withAlpha(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      'AI Studio',
                      style: TextStyle(
                        color: Colors.white.withAlpha(240),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Stats Cards Row
          Row(
            children: [
              _buildMetricCard(
                title: 'Total Meetings',
                value: '$total',
                icon: Icons.folder_outlined,
                color: const Color(0xFF38BDF8),
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                title: 'MOM Ready',
                value: '$completed',
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF34D399),
              ),
              const SizedBox(width: 8),
              _buildMetricCard(
                title: 'In Progress',
                value: '$inProgress',
                icon: Icons.hourglass_top_rounded,
                color: const Color(0xFFFBBF24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withAlpha(190),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Search & Date Picker Bar
  Widget _buildSearchAndDateRow() {
    return Row(
      children: [
        // Search field
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search title, agenda, topic...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Date Picker Button
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _filterDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFF1E3A8A),
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Color(0xFF0F172A),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _filterDate = picked);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _filterDate != null ? const Color(0xFF1E3A8A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _filterDate != null ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: _filterDate != null ? Colors.white : const Color(0xFF1E3A8A),
                ),
                if (_filterDate != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMM').format(_filterDate!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _filterDate = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Filter Chips Row
  Widget _buildFilterChipsRow(int total, int completed, int inProgress) {
    final chips = [
      {'key': 'All', 'label': 'All ($total)'},
      {'key': 'Completed', 'label': 'MOM Ready ($completed)'},
      {'key': 'Processing', 'label': 'Processing ($inProgress)'},
      {'key': 'Today', 'label': 'Today'},
      {'key': 'Audio', 'label': '🎙️ With Audio'},
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final item = chips[index];
          final isSelected = _selectedFilterChip == item['key'];

          return InkWell(
            onTap: () => setState(() => _selectedFilterChip = item['key']!),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  item['label']!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Meeting Card Design
  Widget _buildMeetingCard(dynamic meeting) {
    final hasAudio = meeting.audioFileName != null && meeting.audioFileName!.isNotEmpty;
    final statusColor = _getStatusColor(meeting.status);
    final statusLabel = _formatStatusLabel(meeting.status);
    final isCompleted = meeting.status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MeetingDetailsScreen(
                  meetingId: meeting.id,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Status Pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.task_alt_rounded
                            : hasAudio
                                ? Icons.graphic_eq_rounded
                                : Icons.groups_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meeting.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meeting.agenda != null && meeting.agenda!.isNotEmpty
                                ? meeting.agenda!
                                : 'No agenda specified',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withAlpha(40)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 9.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Divider line
                Container(
                  height: 1,
                  color: const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 10),

                // Bottom Meta Row: Date, Type, Audio badge, Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Date chip
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd MMM, hh:mm a').format(meeting.dateTime),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),

                        // Meeting Type Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            meeting.meetingType,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Audio Attached Indicator & Chevron
                    Row(
                      children: [
                        if (hasAudio) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.mic_rounded, size: 11, color: Color(0xFF10B981)),
                                SizedBox(width: 3),
                                Text(
                                  'Audio',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Empty State Widget
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 40,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _filterDate != null
                  ? 'No Meetings on This Date'
                  : _searchQuery.isNotEmpty
                      ? 'No Matching Meetings Found'
                      : 'No Meetings Created Yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _filterDate != null || _searchQuery.isNotEmpty
                  ? 'Try clearing filters or searching for something else.'
                  : 'Start by creating your first meeting to record audio and auto-generate AI MOM.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            if (_filterDate != null || _searchQuery.isNotEmpty || _selectedFilterChip != 'All')
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _filterDate = null;
                    _selectedFilterChip = 'All';
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Clear All Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1E3A8A),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateMeetingScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Meeting', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

