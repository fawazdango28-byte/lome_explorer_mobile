import 'dart:io';
import 'package:event_flow/config/theme/app_color.dart';
import 'package:event_flow/core/providers/auth_provider.dart';
import 'package:event_flow/core/providers/geo_provider.dart';
import 'package:event_flow/core/services/lieu_evenement_service.dart';
import 'package:event_flow/domains/injections/service_locator.dart' as getit;
import 'package:event_flow/presentation/pages/auth/auth_guard.dart';
import 'package:event_flow/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class LieuCreatePage extends StatefulWidget {
  const LieuCreatePage({super.key});

  @override
  State<LieuCreatePage> createState() => _LieuCreatePageState();
}

class _LieuCreatePageState extends State<LieuCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  GoogleMapController? _mapController;
  String? _selectedCategorie;
  LatLng? _selectedPosition;
  bool _isLoading = false;
  File? _selectedImage;
  
  // États pour les sections déroulables
  bool _isImageSectionExpanded = false;
  bool _isDescriptionExpanded = false;

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

  static const LatLng _lomeCenter = LatLng(6.1319, 1.2228);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
    _loadQuartiers();
    _detectUserLocation();
  }

  Future<void> _checkAuthentication() async {
    final authNotifier = context.read<AuthNotifier>();

    if (!authNotifier.isAuthenticated) {
      final shouldLogin = await AuthGuard.requireAuth(
        context,
        message: 'Vous devez être connecté pour créer un lieu.',
      );

      if (!shouldLogin && mounted) {
        Navigator.pop(context);
        return;
      }

      if (shouldLogin && mounted) {
        final result = await Navigator.pushNamed(context, '/login');
        if (result != true && mounted) {
          Navigator.pop(context);
          return;
        }
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadQuartiers() async {
    final quartiersNotifier = context.read<QuartiersNotifier>();
    await quartiersNotifier.fetchQuartiers();
  }

  Future<void> _detectUserLocation() async {
    try {
      final locationNotifier = context.read<UserLocationNotifier>();
      await locationNotifier.detectLocation();

      if (locationNotifier.location != null && mounted) {
        final location = locationNotifier.location!;
        setState(() {
          _selectedPosition = LatLng(location.latitude, location.longitude);
          _latitudeController.text = location.latitude.toStringAsFixed(6);
          _longitudeController.text = location.longitude.toStringAsFixed(6);
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _selectedPosition!, zoom: 15),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _selectedPosition = _lomeCenter;
        _latitudeController.text = _lomeCenter.latitude.toStringAsFixed(6);
        _longitudeController.text = _lomeCenter.longitude.toStringAsFixed(6);
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Créer un lieu'),
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
                  if (value == null || value.isEmpty) {
                    return 'Nom requis';
                  }
                  if (value.length < 3) {
                    return 'Min. 3 caractères';
                  }
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
                      if (value == null || value.isEmpty) {
                        return 'Requis';
                      }
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
                    ? 'Image sélectionnée' 
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
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
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
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
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
                      if (value == null || value.isEmpty) {
                        return 'Description requise';
                      }
                      if (value.length < 10) {
                        return 'Min. 10 caractères';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      // Mettre à jour le compteur de caractères
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
                        'Recherchez un lieu, cliquez sur la carte ou utilisez votre position',
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
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Créer'),
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

  // Widget pour les sections déroulables
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
                color: isExpanded 
                    ? AppColors.primaryGreen 
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isExpanded 
                      ? AppColors.primaryGreen 
                      : Colors.grey.shade600,
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
                          color: isExpanded 
                              ? AppColors.primaryGreen 
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isExpanded 
                      ? Icons.keyboard_arrow_up 
                      : Icons.keyboard_arrow_down,
                  color: isExpanded 
                      ? AppColors.primaryGreen 
                      : Colors.grey.shade600,
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
            zoom: 14,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          onTap: (position) {
            setState(() {
              _selectedPosition = position;
              _latitudeController.text = position.latitude.toStringAsFixed(6);
              _longitudeController.text = position.longitude.toStringAsFixed(6);
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
                        _latitudeController.text = newPosition.latitude
                            .toStringAsFixed(6);
                        _longitudeController.text = newPosition.longitude
                            .toStringAsFixed(6);
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
                        _selectSearchResult(quartier);
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

  void _selectSearchResult(dynamic quartier) {
    final latitude = quartier.latitude as double?;
    final longitude = quartier.longitude as double?;

    if (latitude != null && longitude != null) {
      setState(() {
        _selectedPosition = LatLng(latitude, longitude);
        _latitudeController.text = latitude.toStringAsFixed(6);
        _longitudeController.text = longitude.toStringAsFixed(6);
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _selectedPosition!, zoom: 15),
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    final authNotifier = context.read<AuthNotifier>();
    if (!authNotifier.isAuthenticated) {
      SnackBarHelper.showError(
        context,
        'Vous devez être connecté pour créer un lieu',
      );

      final shouldLogin = await AuthGuard.requireAuth(context);
      if (shouldLogin && mounted) {
        await Navigator.pushNamed(context, '/login');
      }
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedPosition == null) {
      SnackBarHelper.showError(
        context,
        'Veuillez sélectionner une position sur la carte',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final nom = _nomController.text.trim();
      final description = _descriptionController.text.trim();
      final categorie = _selectedCategorie!;
      final latitude = double.parse(_latitudeController.text.trim());
      final longitude = double.parse(_longitudeController.text.trim());

      await getit.getIt<LieuEvenementService>().createLieu(
        nom: nom,
        description: description,
        categorie: categorie,
        latitude: latitude,
        longitude: longitude,
        image: _selectedImage,
      );

      if (mounted) {
        SnackBarHelper.showSuccess(context, 'Lieu créé avec succès');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la création: ';

        if (e.toString().contains('401') ||
            e.toString().contains('authentication')) {
          errorMessage =
              'Erreur d\'authentification. Veuillez vous reconnecter.';

          await context.read<AuthNotifier>().logout();
          if (mounted) {
            await Navigator.pushNamed(context, '/login');
            Navigator.pop(context);
          }
        } else if (e.toString().contains('Network')) {
          errorMessage =
              'Erreur de connexion. Vérifiez votre connexion Internet.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Erreur serveur. Veuillez réessayer plus tard.';
        } else {
          errorMessage += e.toString();
        }

        SnackBarHelper.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}