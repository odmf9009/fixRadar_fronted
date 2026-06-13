import 'package:flutter/material.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return DefaultTabController(
      length: 1,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Panel de Administrador',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          bottom: const TabBar(
            labelColor: Color(0xFFFF8A00),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFFF8A00),
            tabs: [
              Tab(text: 'Usuarios', icon: Icon(Icons.people_outline)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersTab(firestoreService),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab(FirestoreService service) {
    return StreamBuilder<List<UserModel>>(
      stream: service.getAllUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return const Center(child: Text('No hay usuarios registrados'));
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.orange.withOpacity(0.05),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  const SizedBox(width: 12),
                  Text(
                    'Total de usuarios registrados: ${users.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: user.profileImageUrl.isNotEmpty 
                        ? NetworkImage(user.profileImageUrl) 
                        : null,
                      child: user.profileImageUrl.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        _roleBadge(user.role),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.username.isNotEmpty ? '@${user.username} (${user.email})' : user.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Nivel ${user.level} • ${user.points} pts', style: const TextStyle(color: Color(0xFFFF8A00), fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_attributes_outlined, color: Colors.blue),
                          onPressed: () => _showChangeRoleDialog(context, user, service),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _showDeleteUserConfirm(context, user, service),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteUserConfirm(BuildContext context, UserModel user, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar a ${user.name}'),
        content: const Text('Se eliminará el perfil y TODOS los pedidos asociados a este usuario. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await service.deleteUserAccount(user.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario y datos eliminados.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar Permanentemente', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final bool isTech = role == 'technician';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isTech ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isTech ? Colors.orange.withOpacity(0.3) : Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        isTech ? 'TÉCNICO' : 'CLIENTE',
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold, 
          color: isTech ? Colors.orange[800] : Colors.blue[800]
        ),
      ),
    );
  }

  void _showChangeRoleDialog(BuildContext context, UserModel user, FirestoreService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cambiar rol de ${user.name}'),
        content: const Text('Selecciona el nuevo rol para este usuario:'),
        actions: [
          TextButton(
            onPressed: () async {
              await service.updateUserRole(user.id, 'client');
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hacer CLIENTE', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              await service.updateUserRole(user.id, 'technician');
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hacer TÉCNICO', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
