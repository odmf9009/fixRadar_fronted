import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/language_service.dart';

/// Diálogo de confirmación de borrado de cuenta, compartido entre Perfil y
/// Privacidad para que el mensaje y el comportamiento sean siempre iguales.
void showDeleteAccountDialog(BuildContext context) {
  final uid = AuthService.currentUidSync;
  if (uid.isEmpty) return;

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(tr('delete_account_q'), style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(tr('delete_account_confirm')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final firestoreService = FirestoreService();
              // El backend borra la cuenta (datos propios + la de Firebase Auth
              // si aplica). El cliente solo limpia su sesión local después.
              await firestoreService.deleteUserAccount(uid);
              await AuthService().signOut();

              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
              }
            } catch (e) {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(tr('delete_account_error').replaceAll('{e}', '$e'))),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text(tr('delete_all'), style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}
