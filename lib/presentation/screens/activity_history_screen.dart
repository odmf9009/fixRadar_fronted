import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/activity_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/achievement_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/achievement_service.dart';

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AchievementService _achievementService = AchievementService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _activeFilter = 'All';

  final List<String> _filters = [
    'All',
    'Publications',
    'Collected',
    'Community',
    'Achievements',
    'Ranking'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          tr('historial'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService.getUserStream(_currentUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          }
          final user = userSnapshot.data;
          
          return CustomScrollView(
            slivers: [
              // 1. User Summary Section
              SliverToBoxAdapter(
                child: _buildUserSummary(user),
              ),

              // 2. Monthly Summary Section
              SliverToBoxAdapter(
                child: _buildMonthlySummary(user),
              ),

              // 3. Recent Achievements Section
              SliverToBoxAdapter(
                child: _buildRecentAchievements(),
              ),

              // 4. Activity Categories (Sticky Header-like)
              SliverToBoxAdapter(
                child: _buildFilterTabs(),
              ),

              // 5. Activity Timeline
              StreamBuilder<List<ActivityModel>>(
                stream: _firestoreService.getUserActivities(_currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(child: _buildShimmerTimeline());
                  }

                  final allActivities = snapshot.data ?? [];
                  
                  // Filter logic
                  final filteredActivities = allActivities.where((activity) {
                    if (_activeFilter == 'All') return true;
                    if (_activeFilter == 'Publications') return activity.type == ActivityType.publish;
                    if (_activeFilter == 'Collected') return activity.type == ActivityType.serviceCompleted || activity.type == ActivityType.serviceCompletedByOther;
                    if (_activeFilter == 'Community') return activity.type == ActivityType.confirm || activity.type == ActivityType.photoUpdate || activity.type == ActivityType.communityAppreciation;
                    if (_activeFilter == 'Achievements') return activity.type == ActivityType.achievement || activity.type == ActivityType.levelUp;
                    if (_activeFilter == 'Ranking') return activity.type == ActivityType.rankingEntry;
                    return true;
                  }).toList();

                  if (filteredActivities.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No hay actividad reciente en esta categoría',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _buildActivityItem(filteredActivities[index], index == 0, index == filteredActivities.length - 1);
                      },
                      childCount: filteredActivities.length,
                    ),
                  );
                },
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserSummary(UserModel? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat(user?.postsCount.toString() ?? '0', tr('publicaciones'), Icons.add_a_photo_outlined),
              _buildSummaryStat(user?.foundCount.toString() ?? '0', tr('recogidos'), Icons.shopping_bag_outlined),
              _buildSummaryStat(user?.points.toString() ?? '0', tr('puntos'), Icons.stars_rounded),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryStat('#${user?.level ?? 1}', tr('ranking'), Icons.leaderboard_outlined),
              _buildSummaryStat('${user?.activeStreak ?? 0} d', 'Racha', Icons.local_fire_department_outlined),
              _buildSummaryStat('${user?.totalDistance.toStringAsFixed(1)} mi', 'Explorado', Icons.explore_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF8A00), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _buildMonthlySummary(UserModel? user) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM', 'es').format(now);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumen de $monthName',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildSmallStat('Pubs', user?.postsCount.toString() ?? '0'),
                _buildSmallStat('Recog.', user?.foundCount.toString() ?? '0'),
                _buildSmallStat('Pts', user?.points.toString() ?? '0'),
                _buildSmallStat('Ayudados', user?.usersHelped.toString() ?? '0'),
                _buildSmallStat('Millas', user?.totalDistance.toStringAsFixed(1) ?? '0.0'),
                _buildSmallStat('Conf.', user?.confirmationsCount.toString() ?? '0'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildRecentAchievements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            tr('logros_recientes'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: StreamBuilder<List<AchievementModel>>(
            stream: _achievementService.getUserAchievements(_currentUserId),
            builder: (context, snapshot) {
              final achievements = (snapshot.data ?? []).where((a) => a.isUnlocked).toList();
              if (achievements.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Center(child: Text('¡Empieza a explorar para ganar insignias!', style: TextStyle(color: Colors.grey[400], fontSize: 12))),
                );
              }
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final ach = achievements[index];
                  return Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF121212),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFFF8A00).withOpacity(0.5)),
                          ),
                          child: Icon(ach.icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr(ach.titleKey),
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _activeFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _activeFilter = filter);
              },
              selectedColor: const Color(0xFFFF8A00),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[300]!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActivityItem(ActivityModel activity, bool isFirst, bool isLast) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline Line and Dot
            Column(
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: isFirst ? Colors.transparent : Colors.grey[200],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activity.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(activity.icon, color: activity.color, size: 16),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : Colors.grey[200],
                  ),
                ),
              ],
            ),
          const SizedBox(width: 16),
          // Activity Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[100]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      if (activity.points != 0)
                        Text(
                          '${activity.points > 0 ? '+' : ''}${activity.points} pts',
                          style: const TextStyle(
                            color: Color(0xFFFF8A00),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.description,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatRelativeTime(activity.createdAt),
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'hace ${diff.inHours} horas';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  Widget _buildShimmerTimeline() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          height: 100,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
