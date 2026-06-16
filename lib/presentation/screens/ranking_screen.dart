import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _activeTab = 'local'; // local, nacional, global
  String _activeSubFilter = 'points'; // points, postsCount, confirmationsCount
  final String _currentUserId = AuthService.currentUidSync;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              tr('ranking'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Filter Tabs (Local, Nacional, Global)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterTab(tr('local'), 'local'),
                    _buildFilterTab(tr('nacional'), 'nacional'),
                    _buildFilterTab(tr('global'), 'global'),
                  ],
                ),
              ),
              
              // Current User Position
              StreamBuilder<UserModel?>(
                stream: _firestoreService.getUserStream(_currentUserId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final user = snapshot.data!;
                  return _buildCurrentUserCard(user);
                },
              ),

              // Sub-filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSubFilter(tr('puntos'), 'points'),
                      _buildSubFilter(tr('publicaciones'), 'postsCount'),
                      _buildSubFilter('Reparaciones', 'foundCount'),
                      _buildSubFilter(tr('confirmaciones'), 'confirmationsCount'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),

              // Ranking List
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: _firestoreService.getTopUsers(sortBy: _activeSubFilter),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildShimmerRanking();
                    }
                    
                    final users = snapshot.data ?? [];
                    
                    if (users.isEmpty) {
                      return Center(child: Text(tr('no_hay_ranking')));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildRankingItem(
                          (index + 1).toString(),
                          user,
                          isSelf: user.id == _currentUserId,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildCurrentUserCard(UserModel user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('tu_perfil_actual'),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey,
                  backgroundImage: NetworkImage(
                    user.profileImageUrl.isNotEmpty 
                      ? user.profileImageUrl 
                      : 'https://i.pravatar.cc/150?u=${user.id}'
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.username.isNotEmpty ? '@${user.username}' : user.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${tr('nivel')} ${user.level} - ${user.levelTitle}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${_getDisplayValue(user)} ${_activeSubFilter == 'points' ? 'pts' : ''}',
                  style: const TextStyle(
                    color: Color(0xFFFF8A00),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, String tabKey) {
    final isSelected = _activeTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (tabKey == 'nacional' || tabKey == 'global') {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white),
                    const SizedBox(width: 10),
                    Text('¡${tr('nacional').toUpperCase()} & ${tr('global').toUpperCase()}! ${tr('proximamente')}...'),
                  ],
                ),
                backgroundColor: const Color(0xFFFF8A00),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          setState(() => _activeTab = tabKey);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[300]!),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubFilter(String label, String value) {
    final isSelected = _activeSubFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeSubFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF8A00).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFF8A00) : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerRanking() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: Colors.grey[200]!,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          height: 60,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildRankingItem(String pos, UserModel user, {bool isSelf = false}) {
    Color? medalColor;
    bool isMedal = false;
    
    if (pos == '1') {
      isMedal = true;
      medalColor = Colors.amber;
    } else if (pos == '2') {
      isMedal = true;
      medalColor = Colors.grey[400];
    } else if (pos == '3') {
      isMedal = true;
      medalColor = Colors.brown[300];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelf ? const Color(0xFFFF8A00).withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isSelf ? Border.all(color: const Color(0xFFFF8A00).withOpacity(0.3)) : null,
        boxShadow: [
          if (!isSelf) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: isMedal 
              ? Icon(Icons.emoji_events, color: medalColor, size: 20)
              : Text(pos, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[200],
            backgroundImage: NetworkImage(
              user.profileImageUrl.isNotEmpty 
                ? user.profileImageUrl 
                : 'https://i.pravatar.cc/150?u=${user.id}'
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.username.isNotEmpty ? '@${user.username}' : user.name, 
                style: const TextStyle(fontWeight: FontWeight.bold)
              ),
              Text('${tr('nivel')} ${user.level} - ${user.levelTitle}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const Spacer(),
          Text(
            _getDisplayValue(user),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _getDisplayValue(UserModel user) {
    switch (_activeSubFilter) {
      case 'postsCount':
        return '${user.postsCount}';
      case 'foundCount':
        return '${user.foundCount}';
      case 'confirmationsCount':
        return '${user.confirmationsCount}';
      case 'points':
      default:
        return '${user.points}';
    }
  }
}
