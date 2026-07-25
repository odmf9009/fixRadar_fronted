import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/view_mode_service.dart';
import '../../core/services/achievement_service.dart';
import '../../core/widgets/photo_source_picker.dart';
import '../../core/models/service_request.dart';
import '../../core/models/user_model.dart';
import '../../core/config/service_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UploadService _uploadService = UploadService();
  final AchievementService _achievementService = AchievementService();
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
  }

  void _checkUserAchievements(UserModel user) {
    _achievementService.checkAchievements(user);
  }

  void _showEditAliasDialog(BuildContext context, UserModel user, FirestoreService service) {
    final TextEditingController controller = TextEditingController(text: user.username);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('set_public_alias'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('alias_desc'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: tr('alias_hint'),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.updateUserAlias(user.id, controller.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('alias_updated'))));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('error_label')}: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00), minimumSize: const Size(80, 36)),
            child: Text(tr('save'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSpecialtiesDialog(BuildContext context, UserModel user) {
    final List<String> allCategories = ServiceConstants.categoryNames;
    
    List<String> tempSpecialties = List.from(user.specialties);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFFF5E6D3), // Matching the beige/nude tone from image
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Text(tr('my_specialties'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: allCategories.map((cat) {
                    final bool isSelected = tempSpecialties.contains(cat);
                    
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          // Selección ÚNICA en la UI: solo una especialidad a la vez.
                          // Se sigue guardando como List<String> para que la
                          // estructura admita varias en el futuro sin cambios.
                          if (isSelected) {
                            tempSpecialties = [];
                          } else {
                            tempSpecialties = [cat];
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFFF8A00) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? const Color(0xFFFF8A00) : Colors.grey[300]!),
                          boxShadow: [
                            if (isSelected) BoxShadow(color: const Color(0xFFFF8A00).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(
                          ServiceConstants.getDisplayName(cat),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: Text(tr('cancel'), style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await _firestoreService.updateUserRole(user.id, user.role, specialties: tempSpecialties);
                  await _firestoreService.refreshUserStream(user.id);
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(tr('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          );
        },
      ),
    );
  }

  Future<void> _updateProfilePhoto(String userId) async {
    // Permite elegir entre tomar la foto con la cámara o elegirla de la galería.
    final source = await PhotoSourcePicker.chooseSource(context);
    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _uploadService.uploadProfileImage(File(pickedFile.path), userId);
      if (imageUrl != null) {
        await _firestoreService.updateUserProfileImage(userId, imageUrl);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('profile_photo_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('error_uploading_photo').replaceAll('{e}', '$e')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = AuthService.currentUidSync;
    final String? currentUserEmail = FirebaseAuth.instance.currentUser?.email;
    final bool isAdmin = currentUserEmail == 'krvillamil1990@gmail.com';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          tr('mi_perfil'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _firestoreService.getUserStream(currentUserId),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
          }

          final user = userSnapshot.data;
          if (user != null) {
            _checkUserAchievements(user);
          }

          final bool accountIsTech = user?.role == 'technician' || user?.userType == 'technician';
          // Vista profesional ("Trabajar") vs cliente ("Necesito ayuda"): el
          // resumen sigue el lente, no solo el rol.
          final bool proView = accountIsTech && ViewModeService.instance.isProLens;

          return StreamBuilder<List<ServiceRequest>>(
            stream: proView
                ? _firestoreService.getTechnicianHistory(currentUserId)
                : _firestoreService.getClientRequests(currentUserId),
            builder: (context, snapshot) {
              final allRequests = snapshot.data ?? [];
              // En vista profesional solo contamos los trabajos ganados (asignados a mí).
              final requests = proView
                  ? allRequests.where((p) => p.technicianId == currentUserId).toList()
                  : allRequests;
              final activeCount = requests.where((p) => p.status != ServiceRequestStatus.completed && p.status != ServiceRequestStatus.cancelled).length;
              final completedCount = requests.where((p) => p.status == ServiceRequestStatus.completed).length;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    // User Info Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _updateProfilePhoto(currentUserId),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: NetworkImage(
                                    user?.profileImageUrl.isNotEmpty == true 
                                      ? user!.profileImageUrl 
                                      : 'https://i.pravatar.cc/150?u=$currentUserId'
                                  ),
                                  child: _isUploading 
                                    ? const CircularProgressIndicator(color: Color(0xFFFF8A00))
                                    : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Color(0xFFFF8A00), shape: BoxShape.circle),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.name ?? 'Usuario',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        user?.username != null && user!.username.isNotEmpty 
                                          ? '@${user.username}' 
                                          : tr('no_alias_configured'),
                                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: Color(0xFFFF8A00)),
                                      onPressed: () => _showEditAliasDialog(context, user ?? UserModel(id: currentUserId, name: 'Usuario', email: ''), _firestoreService),
                                    ),
                                  ],
                                ),
                                Text(
                                  tr('level_prefix').replaceAll('{n}', '${user?.level ?? 1}').replaceAll('{title}', user?.levelTitle ?? tr('explorer_default')),
                                  style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                
                    const SizedBox(height: 24),
                    
                    // Progress Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${user?.totalXp ?? 0} / ${user?.nextLevelXp ?? 1000} XP', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: user?.levelProgress ?? 0.0,
                              minHeight: 8,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    // Main Stats
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(requests.length.toString(), tr('pedidos_stat')),
                          _buildStatItem(completedCount.toString(), tr('completados_stat')),
                          _buildStatItem('${(user?.rating ?? 0.0).toStringAsFixed(1)}', tr('rating_stat')),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    
                    if (user?.role == 'technician')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('tech_settings'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 16),
                            Material(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: Text(tr('tech_status'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(tr('tech_status_desc'), style: const TextStyle(fontSize: 12)),
                                      trailing: Switch(
                                        activeThumbColor: const Color(0xFFFF8A00),
                                        value: user?.notificationsEnabled ?? true,
                                        onChanged: (val) async {
                                          await _firestoreService.updateNotificationsStatus(currentUserId, val);
                                        },
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    InkWell(
                                      onTap: () => _showSpecialtiesDialog(context, user!),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(tr('my_specialties'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                  const SizedBox(height: 6),
                                                  user!.specialties.isEmpty
                                                      ? Text(tr('none_selected'), style: const TextStyle(fontSize: 12, color: Colors.grey))
                                                      : Wrap(
                                                          spacing: 6,
                                                          runSpacing: 6,
                                                          children: user.specialties.map((s) => Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: const Color(0xFFFF8A00).withValues(alpha: 0.12),
                                                              borderRadius: BorderRadius.circular(20),
                                                              border: Border.all(color: const Color(0xFFFF8A00).withValues(alpha: 0.4)),
                                                            ),
                                                            child: Text(ServiceConstants.getDisplayName(s), style: const TextStyle(fontSize: 12, color: Color(0xFFCC6F00), fontWeight: FontWeight.w500)),
                                                          )).toList(),
                                                        ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(Icons.edit, size: 20, color: Colors.grey),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: Text(tr('my_portfolio'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(tr('my_portfolio_desc'), style: const TextStyle(fontSize: 12)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pushNamed(context, AppRoutes.managePortfolio),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: Text(tr('professional_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(tr('professional_profile_desc'), style: const TextStyle(fontSize: 12)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pushNamed(context, AppRoutes.editTechProfile, arguments: user),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),
                    
                    if (isAdmin)
                      _buildMenuItem(Icons.admin_panel_settings, tr('admin_panel_title'), () {
                        Navigator.pushNamed(context, AppRoutes.adminPanel);
                      }),
                    _buildMenuItem(Icons.edit_note_outlined, proView ? tr('my_jobs') : tr('my_orders'), () {
                      Navigator.pushNamed(context, AppRoutes.myPosts);
                    }, count: activeCount),
                    _buildMenuItem(Icons.history, tr('historial_menu'), () {
                      Navigator.pushNamed(context, AppRoutes.activityHistory);
                    }),

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {int? count}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
          leading: Icon(icon, color: Colors.black87, size: 24),
          title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count != null && count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFF8A00).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(count.toString(), style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(height: 1, indent: 24, endIndent: 24),
      ],
    );
  }
}
