import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/config/routes.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/upload_service.dart';
import '../../core/services/language_service.dart';
import '../../core/services/achievement_service.dart';
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
        title: const Text('Configurar Alias Público', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Este nombre se mostrará a otros usuarios en la comunidad.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ej: FixerMister99',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              try {
                await service.updateUserAlias(user.id, controller.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alias actualizado correctamente')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8A00), minimumSize: const Size(80, 36)),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
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
            title: const Text('Mis Especialidades', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
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
                          if (isSelected) {
                            tempSpecialties.remove(cat);
                          } else {
                            // Force only one specialty
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
                          cat,
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
                child: const Text('Cancelar', style: TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold))
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await _firestoreService.updateUserRole(user.id, user.role, specialties: tempSpecialties);
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final imageUrl = await _uploadService.uploadProfileImage(userId, File(pickedFile.path));
      await _firestoreService.updateUserProfileImage(userId, imageUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Foto de perfil actualizada!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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

          return StreamBuilder<List<ServiceRequest>>(
            stream: _firestoreService.getClientRequests(currentUserId),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
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
                                          : 'Sin alias configurado',
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
                                  'Nivel ${user?.level ?? 1} - ${user?.levelTitle ?? 'Explorador'}',
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
                          _buildStatItem(requests.length.toString(), 'Pedidos'),
                          _buildStatItem(completedCount.toString(), 'Completados'),
                          _buildStatItem('${user?.rating.toStringAsFixed(1)}', 'Calificación'),
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
                            const Text('Configuración de Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                                      title: const Text('Estado Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Activa o desactiva las alertas de nuevos trabajos.', style: TextStyle(fontSize: 12)),
                                      trailing: Switch(
                                        activeThumbColor: const Color(0xFFFF8A00),
                                        value: user?.notificationsEnabled ?? true,
                                        onChanged: (val) async {
                                          await _firestoreService.updateNotificationsStatus(currentUserId, val);
                                        },
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: const Text('Mis Especialidades', style: TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: Text(user!.specialties.isEmpty ? 'Ninguna seleccionada' : user.specialties.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                      trailing: const Icon(Icons.edit, size: 20),
                                      onTap: () => _showSpecialtiesDialog(context, user),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: const Text('Mi Portafolio', style: TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Muestra tus trabajos a los clientes.', style: TextStyle(fontSize: 12)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.pushNamed(context, AppRoutes.managePortfolio),
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                      title: const Text('Perfil Profesional', style: TextStyle(fontWeight: FontWeight.bold)),
                                      subtitle: const Text('Completa tu información para los clientes.', style: TextStyle(fontSize: 12)),
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
                      _buildMenuItem(Icons.admin_panel_settings, 'Panel de Administrador', () {
                        Navigator.pushNamed(context, AppRoutes.adminPanel);
                      }),
                    _buildMenuItem(Icons.edit_note_outlined, 'Mis pedidos', () {
                      Navigator.pushNamed(context, AppRoutes.myPosts);
                    }, count: activeCount),
                    _buildMenuItem(Icons.history, 'Historial', () {
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
