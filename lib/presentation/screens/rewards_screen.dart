import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/rewards_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/language_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/reward_model.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  final RewardsService _rewardsService = RewardsService();
  final FirestoreService _firestoreService = FirestoreService();
  final String _currentUid = AuthService.currentUidSync;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(tr('recompensas'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService.getUserStream(_currentUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          }

          final user = snapshot.data!;
          final progress = user.levelProgress;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressHeader(user, progress),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Canjear Recompensas'),
                      _buildRewardsCatalog(user),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Cómo Ganar XP'),
                      _buildXPActionList(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Historial de XP'),
                      _buildXPHistory(),
                      const SizedBox(height: 32),
                      _buildSectionHeader('Sistema de Niveles'),
                      _buildLevelSystem(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader(UserModel user, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TU PROGRESO', style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                  const SizedBox(height: 8),
                  Text(
                    'Nivel ${user.level}: ${user.levelTitle}',
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A00),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${user.points} Puntos',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${user.totalXp - user.currentLevelBaseXp} / ${user.nextLevelXp - user.currentLevelBaseXp} XP', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              Text('Total: ${user.totalXp} XP', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF121212)),
      ),
    );
  }

  Widget _buildRewardsCatalog(UserModel user) {
    final rewards = _rewardsService.getAvailableRewards();
    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: rewards.length,
        itemBuilder: (context, index) {
          final reward = rewards[index];
          final isRedeemed = user.redeemedRewards.contains(reward.id);
          final canAfford = user.points >= reward.xpRequired;
          
          return Container(
            width: 180,
            margin: const EdgeInsets.only(right: 16, bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: isRedeemed ? Colors.green.withOpacity(0.3) : Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(reward.icon, style: const TextStyle(fontSize: 32)),
                    if (isRedeemed)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Text(reward.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Text('${reward.xpRequired} XP', style: TextStyle(color: isRedeemed ? Colors.grey : const Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (canAfford && !isRedeemed) ? () => _redeemReward(reward) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRedeemed ? Colors.green : const Color(0xFF121212),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    child: Text(
                      isRedeemed ? 'Canjeado' : 'Canjear', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildXPActionList() {
    final actions = [
      {'title': 'Publicar un Objeto', 'xp': '+50 XP', 'icon': Icons.add_a_photo},
      {'title': 'Marcar como Recogido', 'xp': '+100 XP', 'icon': Icons.check_circle},
      {'title': 'Referido Exitoso', 'xp': '+100 XP', 'icon': Icons.group_add},
      {'title': 'Primera Acción de Referido', 'xp': '+150 XP', 'icon': Icons.bolt},
      {'title': 'Racha de 7 Días', 'xp': '+200 XP', 'icon': Icons.calendar_today},
      {'title': 'Reporte Válido', 'xp': '+25 XP', 'icon': Icons.flag},
    ];

    return Column(
      children: actions.map((action) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(action['icon'] as IconData, color: const Color(0xFFFF8A00), size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(action['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(action['xp'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildXPHistory() {
    return StreamBuilder<List<XPTransaction>>(
      stream: _rewardsService.getXPHistory(_currentUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aún no tienes historial de XP.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.take(5).length,
          itemBuilder: (context, index) {
            final tx = snapshot.data![index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.add, color: Colors.green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(_formatDate(tx.date), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ),
                  Text('+${tx.xpAmount} XP', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLevelSystem() {
    final levels = [
      {'level': '1', 'title': 'Buscador Novato', 'xp': '0 XP', 'icon': Icons.star_border},
      {'level': '2', 'title': 'Explorador', 'xp': '1,000 XP', 'icon': Icons.explore_outlined},
      {'level': '3', 'title': 'Cazador de Curb', 'xp': '2,500 XP', 'icon': Icons.radar},
      {'level': '4', 'title': 'Héroe de la Comunidad', 'xp': '5,000 XP', 'icon': Icons.favorite_border},
      {'level': '5', 'title': 'Reciclador Élite', 'xp': '10,000 XP', 'icon': Icons.auto_awesome},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: levels.map((lvl) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFFFF8A00).withOpacity(0.2), shape: BoxShape.circle),
                child: Center(child: Text(lvl['level'].toString(), style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lvl['title'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(lvl['xp'].toString(), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ),
              Icon(lvl['icon'] as IconData, color: Colors.white.withOpacity(0.3), size: 20),
            ],
          ),
        )).toList(),
      ),
    );
  }

  void _redeemReward(RewardItem reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Canjear ${reward.title}'),
        content: Text('¿Deseas canjear esta recompensa por ${reward.xpRequired} XP?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processRedemption(reward);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00), foregroundColor: Colors.white),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _processRedemption(RewardItem reward) async {
    setState(() {}); // Trigger loading if needed, though transaction is fast
    
    final success = await _firestoreService.redeemReward(
      _currentUid, 
      reward.id, 
      reward.xpRequired, 
      reward.title
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Recompensa "${reward.title}" canjeada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tienes suficientes XP o hubo un error.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
