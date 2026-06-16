import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../core/models/portfolio_item.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/upload_service.dart';

class ManagePortfolioScreen extends StatefulWidget {
  const ManagePortfolioScreen({super.key});

  @override
  State<ManagePortfolioScreen> createState() => _ManagePortfolioScreenState();
}

class _ManagePortfolioScreenState extends State<ManagePortfolioScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final UploadService _uploadService = UploadService();

  @override
  Widget build(BuildContext context) {
    final String userId = AuthService.currentUidSync;

    return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text('Mi Portafolio', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF121212),
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => setState(() {}),
              )
            ],
          ),
          body: userId.isEmpty 
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<List<PortfolioItem>>(
                stream: _firestoreService.getPortfolio(userId),
                builder: (context, snapshot) {
                  print('DEBUG_PORTFOLIO: Projects Stream state: ${snapshot.connectionState}, hasData: ${snapshot.hasData}');

                  if (snapshot.hasError) {
                    print('DEBUG_PORTFOLIO: Projects Stream ERROR: ${snapshot.error}');
                    return _buildErrorState(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Color(0xFFFF8A00)));
                  }

                  final items = snapshot.data ?? [];
                  print('DEBUG_PORTFOLIO: Projects count: ${items.length}');

                  if (items.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildProgressHeader(items.length),
                      const SizedBox(height: 16),
                      ...items.map((item) => _buildPortfolioCard(item)).toList(),
                      const SizedBox(height: 100), // Safety margin
                    ],
                  );
                },
              ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddItemSheet(),
            backgroundColor: const Color(0xFFFF8A00),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
  }

  Widget _buildProgressHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$count/10 proyectos',
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / 10,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A00)),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              'Todavía no has agregado trabajos a tu portafolio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Muestra tus mejores proyectos para atraer a más clientes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showAddItemSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Agregar Proyecto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8A00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: () => setState(() {}), child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioCard(PortfolioItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      shadowColor: Colors.black12,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showItemDetails(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildCardImage(item),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${item.imageUrls.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildActionMenu(item),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8A00).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.category,
                          style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('dd MMM yyyy').format(item.date),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage(PortfolioItem item) {
    String? imageUrl;
    if (item.thumbnailUrls.isNotEmpty) {
      imageUrl = item.thumbnailUrls.first;
    } else if (item.imageUrls.isNotEmpty) {
      imageUrl = item.imageUrls.first;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 180,
          width: double.infinity,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 48),
        ),
      );
    } else {
      return Container(
        height: 180,
        width: double.infinity,
        color: Colors.grey[200],
        child: const Icon(Icons.image, color: Colors.grey, size: 48),
      );
    }
  }

  Widget _buildActionMenu(PortfolioItem item) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: (value) {
        if (value == 'edit') {
          _showAddItemSheet(item: item);
        } else if (value == 'delete') {
          _confirmDelete(item);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Editar')])),
        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
      ],
    );
  }

  void _showItemDetails(PortfolioItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(item.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: Color(0xFFFF8A00)),
                  const SizedBox(width: 4),
                  Text(item.category, style: const TextStyle(color: Color(0xFFFF8A00), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(DateFormat('dd MMMM yyyy').format(item.date), style: const TextStyle(color: Colors.grey)),
                ],
              ),
              if (item.location != null && item.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(item.location!, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Text(item.description, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
              const SizedBox(height: 32),
              const Text('Galería de Fotos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ...item.imageUrls.map((url) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 250,
                        color: Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(PortfolioItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Estás seguro de que deseas eliminar "${item.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.deletePortfolioItem(item.id);
                // Cleanup Storage
                for (var url in item.imageUrls) {
                  await _uploadService.deleteImageByUrl(url);
                }
                for (var url in item.thumbnailUrls) {
                  await _uploadService.deleteImageByUrl(url);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proyecto eliminado')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddItemSheet({PortfolioItem? item}) async {
    final userId = AuthService.currentUidSync;
    if (userId.isEmpty) return;

    // Fetch user to get specialties
    final user = await _firestoreService.getUser(userId);
    final specialties = user?.specialties ?? [];

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddPortfolioItemSheet(item: item, specialties: specialties),
      );
    }
  }
}

class AddPortfolioItemSheet extends StatefulWidget {
  final PortfolioItem? item;
  final List<String> specialties;
  const AddPortfolioItemSheet({super.key, this.item, required this.specialties});

  @override
  State<AddPortfolioItemSheet> createState() => _AddPortfolioItemSheetState();
}

class _AddPortfolioItemSheetState extends State<AddPortfolioItemSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  late String _category;
  DateTime _selectedDate = DateTime.now();
  final List<dynamic> _images = []; 
  bool _isUploading = false;
  final UploadService _uploadService = UploadService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    
    if (widget.item != null) {
      _category = widget.item!.category;
      _titleController.text = widget.item!.title;
      _descController.text = widget.item!.description;
      _locationController.text = widget.item!.location ?? '';
      _selectedDate = widget.item!.date;
      _images.addAll(widget.item!.imageUrls);
    } else {
      _category = widget.specialties.isNotEmpty ? widget.specialties.first : 'Otros';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> displayCategories = List.from(widget.specialties);
    if (widget.item != null && !displayCategories.contains(widget.item!.category)) {
      displayCategories.add(widget.item!.category);
    }
    if (displayCategories.isEmpty) {
      displayCategories.add('Otros');
    }

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.item == null ? 'Nuevo Proyecto' : 'Editar Proyecto',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context), 
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            if (widget.specialties.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No tienes especialidades configuradas. Por favor, edita tu perfil primero.',
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                  ],
                ),
              ),
            _buildTextField(_titleController, 'Título del proyecto', 'Ej: Renovación de Cocina Moderna'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: displayCategories.contains(_category) ? _category : displayCategories.first,
              items: displayCategories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _category = val!),
              decoration: _inputDecoration('Categoría', 'Basado en tus especialidades'),
            ),
            const SizedBox(height: 16),
            _buildTextField(_descController, 'Descripción', 'Cuéntanos qué hiciste en este proyecto...', maxLines: 3),
            const SizedBox(height: 16),
            _buildDatePicker(),
            const SizedBox(height: 16),
            _buildTextField(_locationController, 'Ubicación (Opcional)', 'Ciudad o área del trabajo', icon: Icons.location_on_outlined),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fotos del proyecto (Máx 5)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${_images.length}/5', 
                  style: TextStyle(color: _images.length >= 5 ? Colors.red : Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _buildImagePicker(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8A00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          SizedBox(width: 12),
                          Text('Guardando...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text(
                        widget.item == null ? 'Publicar Proyecto' : 'Guardar Cambios',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, IconData? icon}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(label, hint).copyWith(
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFFF8A00)) : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF8A00))),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildDatePicker() {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (date != null) setState(() => _selectedDate = date);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Color(0xFFFF8A00), size: 20),
              const SizedBox(width: 12),
              Text(
                'Fecha: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_images.length < 5)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 110,
                height: 110,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100], 
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: Color(0xFFFF8A00), size: 32),
                    SizedBox(height: 8),
                    Text('Añadir fotos', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ..._images.asMap().entries.map((entry) {
            final int index = entry.key;
            final dynamic img = entry.value;
            return Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), 
                    image: DecorationImage(
                      image: img is File ? FileImage(img) : NetworkImage(img) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 18,
                  child: GestureDetector(
                    onTap: () => setState(() => _images.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedList = await picker.pickMultiImage(imageQuality: 70);
    
    if (pickedList.isNotEmpty) {
      setState(() {
        for (var picked in pickedList) {
          if (_images.length < 5) {
            _images.add(File(picked.path));
          }
        }
      });
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, agrega un título y al menos una foto del proyecto.')),
      );
      return;
    }

    setState(() => _isUploading = true);
    final String userId = AuthService.currentUidSync;

    try {
      final List<String> fullUrls = [];
      final List<String> thumbUrls = [];

      for (var img in _images) {
        if (img is File) {
          final result = await _uploadService.uploadOptimizedImage(img, 'portfolio/$userId');
          fullUrls.add(result['full']!);
          thumbUrls.add(result['thumb']!);
        } else {
          fullUrls.add(img);
          if (widget.item != null) {
            int idx = widget.item!.imageUrls.indexOf(img);
            if (idx != -1 && idx < widget.item!.thumbnailUrls.length) {
              thumbUrls.add(widget.item!.thumbnailUrls[idx]);
            } else {
              thumbUrls.add(img);
            }
          }
        }
      }

      final item = PortfolioItem(
        id: widget.item?.id ?? '',
        technicianId: userId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _category,
        date: _selectedDate,
        imageUrls: fullUrls,
        thumbnailUrls: thumbUrls,
        location: _locationController.text.trim(),
        createdAt: widget.item?.createdAt ?? DateTime.now(),
      );

      if (widget.item == null) {
        await _firestoreService.addPortfolioItem(item);
      } else {
        await _firestoreService.updatePortfolioItem(item);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null ? '¡Proyecto publicado con éxito!' : 'Cambios guardados'), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
