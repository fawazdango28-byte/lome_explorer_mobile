import 'dart:io';
import 'package:event_flow/config/theme/app_color.dart';
import 'package:event_flow/core/providers/auth_provider.dart';
import 'package:event_flow/core/providers/geo_provider.dart';
import 'package:event_flow/core/services/lieu_evenement_service.dart';
import 'package:event_flow/domains/entities/lieu_entity.dart';
import 'package:event_flow/domains/injections/service_locator.dart' as getit;
import 'package:event_flow/presentation/pages/auth/guard_lieu_evenement.dart';
import 'package:event_flow/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

class LieuEditPage extends StatefulWidget {
  final LieuEntity lieu;

  const LieuEditPage({super.key, required this.lieu});

  @override
  State<LieuEditPage> createState() => _LieuEditPageState();
}

class _LieuEditPageState extends State<LieuEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _descriptionController;

  GoogleMapController? _mapController;
  String? _selectedCategorie;
  LatLng? _selectedPosition;
  bool _isLoading = false;
  File? _selectedImage;

  // États pour les sections déroulables
  bool _isImageSectionExpanded = false;
  bool _isDescriptionExpanded = true;

  static const LatLng _lomeCenter = LatLng(6.1319, 1.2228);

  final List<String> _categories = [
    'Restaurant',
    'Bar',
    'Hôtel',
    'Musée',
    'Parc',
    'Centre commercial',
    'Salle de sport',
    'Cinéma',
    'Théâtre',
    'Autre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOwnership();
    });

    _nomController = TextEditingController(text: widget.lieu.nom);
    _descriptionController = TextEditingController(text: widget.lieu.description);
    _selectedCategorie = widget.lieu.categorie;

    // Initialiser la position depuis le lieu existant
    _selectedPosition = LatLng(widget.lieu.latitude, widget.lieu.longitude);
  }

  Future<void> _checkOwnership() async {
    final canEdit = await OwnershipGuard.checkOwnershipForAction(
      context: context,
      action: 'modifier',
      lieu: widget.lieu,
    );

    if (!canEdit && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _detectUserLocation() async {
    try {
      final locationNotifier = context.read<UserLocationNotifier>();
      await locationNotifier.detectLocation();

      if (locationNotifier.location != null && mounted) {
        final location = locationNotifier.location!;
        setState(() {
          _selectedPosition = LatLng(location.latitude, location.longitude);
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _selectedPosition!, zoom: 15),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, 'Impossible de détecter votre position');
      }
    }
  }

  void _showQuartiersDialog() {
    final quartiersNotifier = context.read<QuartiersNotifier>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner un quartier'),
        content: SizedBox(
          width: double.maxFinite,
          child: quartiersNotifier.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: quartiersNotifier.quartiers.length,
                  itemBuilder: (context, index) {
                    final quartier = quartiersNotifier.quartiers[index];
                    return ListTile(
                      leading: Icon(
                        Icons.location_city,
                        color: AppColors.primaryGreen,
                      ),
                      title: Text(quartier.nom),
                      onTap: () {
                        _selectQuartier(quartier);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _selectQuartier(dynamic quartier) {
    final latitude = quartier.latitude as double?;
    final longitude = quartier.longitude as double?;

    if (latitude != null && longitude != null) {
      setState(() {
        _selectedPosition = LatLng(latitude, longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedPosition!, zoom: 15),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Modifier le lieu'),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nom du lieu
              CustomTextField(
                label: 'Nom du lieu',
                hint: 'Ex: Le Palmier',
                controller: _nomController,
                prefixIcon: Icons.business,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Nom requis';
                  if (value.length < 3) return 'Min. 3 caractères';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Catégorie
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Catégorie',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategorie,
                    decoration: InputDecoration(
                      hintText: 'Type',
                      prefixIcon: const Icon(Icons.category, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _categories.map((categorie) {
                      return DropdownMenuItem(
                        value: categorie,
                        child: Text(
                          categorie,
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategorie = value);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requis';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section Image (Déroulable)
              _buildExpandableSection(
                title: 'Image du lieu',
                subtitle: _selectedImage != null
                    ? 'Nouvelle image sélectionnée'
                    : (widget.lieu.imageLieu != null && widget.lieu.imageLieu!.isNotEmpty)
                        ? 'Image actuelle (appuyer pour modifier)'
                        : 'Ajouter une image (optionnel)',
                icon: Icons.add_photo_alternate,
                isExpanded: _isImageSectionExpanded,
                onTap: () {
                  setState(() {
                    _isImageSectionExpanded = !_isImageSectionExpanded;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      // Nouvelle image choisie
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: _removeImage,
                                icon: const Icon(Icons.close, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
                      : (widget.lieu.imageLieu != null && widget.lieu.imageLieu!.isNotEmpty)
                          // Image existante depuis le serveur
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: widget.lieu.imageLieu!,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 60,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: ElevatedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: const Text('Changer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          // Aucune image
                          : InkWell(
                              onTap: _pickImage,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Appuyez pour ajouter une image',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 16),

              // Section Description (Déroulable)
              _buildExpandableSection(
                title: 'Description',
                subtitle: _descriptionController.text.isEmpty
                    ? 'Ajouter une description'
                    : '${_descriptionController.text.length} caractères',
                icon: Icons.description,
                isExpanded: _isDescriptionExpanded,
                onTap: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CustomTextField(
                    label: '',
                    hint: 'Décrivez le lieu...',
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Description requise';
                      if (value.length < 10) return 'Min. 10 caractères';
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Section Localisation
              Text(
                'Localisation',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              // Carte interactive
              _buildMap(),
              const SizedBox(height: 12),

              // Boutons d'aide pour la position
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _detectUserLocation,
                      icon: const Icon(Icons.my_location, size: 18),
                      label: const Text('Ma position'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showQuartiersDialog,
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Quartiers'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha((255 * 0.1).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Déplacez le marqueur ou appuyez sur la carte pour changer la position',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Boutons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isExpanded
                  ? AppColors.primaryGreen.withAlpha((255 * 0.05).round())
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isExpanded ? AppColors.primaryGreen : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isExpanded ? AppColors.primaryGreen : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? AppColors.primaryGreen : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: isExpanded ? AppColors.primaryGreen : Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) child,
      ],
    );
  }

  Widget _buildMap() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _selectedPosition ?? _lomeCenter,
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onTap: (position) {
            setState(() {
              _selectedPosition = position;
            });
          },
          markers: _selectedPosition != null
              ? {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: _selectedPosition!,
                    draggable: true,
                    onDragEnd: (newPosition) {
                      setState(() {
                        _selectedPosition = newPosition;
                      });
                    },
                  ),
                }
              : {},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final canEdit = await context.canEditLieu(widget.lieu);
    if (!canEdit) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedPosition == null) {
      SnackBarHelper.showError(
        context,
        'Veuillez sélectionner une position sur la carte',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await getit.getIt<LieuEvenementService>().updateLieu(
        id: widget.lieu.id,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        categorie: _selectedCategorie!,
        latitude: _selectedPosition!.latitude,
        longitude: _selectedPosition!.longitude,
        image: _selectedImage,
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Lieu modifié avec succès');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la modification: ';

        if (e.toString().contains('401') || e.toString().contains('authentication')) {
          errorMessage = 'Erreur d\'authentification. Veuillez vous reconnecter.';
          await context.read<AuthNotifier>().logout();
          if (mounted) {
            await Navigator.pushNamed(context, '/login');
            Navigator.pop(context);
          }
        } else {
          errorMessage += e.toString();
        }

        SnackBarHelper.showError(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}