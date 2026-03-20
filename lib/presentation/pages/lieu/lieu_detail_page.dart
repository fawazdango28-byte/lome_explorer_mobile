import 'package:event_flow/config/app_routers.dart';
import 'package:event_flow/config/theme/app_color.dart';
import 'package:event_flow/core/providers/auth_provider.dart';
import 'package:event_flow/core/providers/lieu_evenement_provider.dart';
import 'package:event_flow/core/services/lieu_evenement_service.dart';
import 'package:event_flow/domains/injections/service_locator.dart' as getit;
import 'package:event_flow/domains/entities/lieu_entity.dart';
import 'package:event_flow/presentation/pages/auth/guard_lieu_evenement.dart';
import 'package:event_flow/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';


class LieuDetailPage extends StatefulWidget {
  final String lieuId;

  const LieuDetailPage({super.key, required this.lieuId});

  @override
  State<LieuDetailPage> createState() => _LieuDetailPageState();
}

class _LieuDetailPageState extends State<LieuDetailPage> {
  bool _hasTriedFetch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLieu();
    });
  }

  Future<void> _fetchLieu({bool forceRefresh = false}) async {
    if (!mounted) return;

    final notifier = context.read<LieuDetailNotifier>();
    await notifier.fetchLieu(widget.lieuId, forceRefresh: forceRefresh);

    if (mounted) {
      setState(() => _hasTriedFetch = true);

      if (notifier.error != null) {
        SnackBarHelper.showError(
          context,
          'Erreur de chargement: ${notifier.error}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Détails du lieu',
        actions: [
          Consumer<LieuDetailNotifier>(
            builder: (context, notifier, _) {
              final lieu = notifier.cache[widget.lieuId];
              if (lieu == null) return const SizedBox.shrink();

              return Row(
                children: [
                  OwnershipEditButton(
                    lieu: lieu,
                    onPressed: () async {
                      final result = await AppRoutes.navigateTo(
                        context,
                        AppRoutes.lieuEdit,
                        arguments: {'lieu': lieu},
                      );

                      if (result == true && mounted) {
                        setState(() => _hasTriedFetch = false);
                        _fetchLieu(forceRefresh: true);
                      }
                    },
                  ),
                  OwnerOnly(
                    lieu: lieu,
                    fallback: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showPublicMenu(context, lieu),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showOwnerMenu(context, lieu),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<LieuDetailNotifier>(
        builder: (context, detailNotifier, _) {
          if (detailNotifier.isLoading && !_hasTriedFetch) {
            return const LoadingWidget(message: 'Chargement des détails...');
          }

          if (detailNotifier.error != null) {
            return AppErrorWidget(
              message: detailNotifier.error!,
              onRetry: () {
                setState(() => _hasTriedFetch = false);
                _fetchLieu();
              },
            );
          }

          final lieu = detailNotifier.cache[widget.lieuId];
          if (lieu == null) {
            return EmptyStateWidget(
              title: 'Lieu non trouvé',
              message: 'Le lieu demandé n\'existe pas ou a été supprimé',
              icon: Icons.location_off,
              onAction: () => Navigator.pop(context),
              actionLabel: 'Retour',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _hasTriedFetch = false);
              await _fetchLieu();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image du lieu
                  _buildImageHeader(lieu),

                  // Informations principales compactes
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // // Nom du lieu
                        // Text(
                        //   lieu.nom,
                        //   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                        // const SizedBox(height: 12),

                        // Catégorie, Note et Événements sur la même ligne
                        Row(
                          children: [
                            // Nom du lieu
                        Text(
                          lieu.nom,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12, width: 20,),
                            // Catégorie
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withAlpha((255 * 0.1).round()),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryGreen),
                              ),
                              child: Text(
                                lieu.categorie,
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Note moyenne
                            if (lieu.moyenneAvis != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.ratingColor.withAlpha((255 * 0.1).round()),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star, color: AppColors.ratingColor, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      lieu.moyenneAvis!.toStringAsFixed(1),
                                      style: TextStyle(
                                        color: AppColors.ratingColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(width: 12),

                            // Nombre d'événements
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlue.withAlpha((255 * 0.1).round()),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event, color: AppColors.primaryBlue, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${lieu.nombreEvenements}',
                                    style: TextStyle(
                                      color: AppColors.primaryBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Description
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          lieu.description.isNotEmpty
                              ? lieu.description
                              : 'Pas de description disponible.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: Colors.grey[700],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Bouton de navigation
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              AppRoutes.navigateTo(
                                context,
                                AppRoutes.map,
                                arguments: {
                                  'latitude': lieu.latitude,
                                  'longitude': lieu.longitude,
                                  'lieuNom': lieu.nom,
                                },
                              );
                            },
                            icon: const Icon(Icons.navigation),
                            label: const Text('Naviguer vers ce lieu'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Section Événements
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Événements à ce lieu',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (lieu.nombreEvenements > 0)
                              TextButton(
                                onPressed: () {
                                  SnackBarHelper.showInfo(
                                    context,
                                    'Liste des événements à venir',
                                  );
                                },
                                child: const Text('Voir tout'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (lieu.nombreEvenements == 0)
                          const EmptyStateWidget(
                            title: 'Aucun événement',
                            message: 'Il n\'y a pas encore d\'événements pour ce lieu',
                            icon: Icons.event_busy,
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withAlpha((255 * 0.05).round()),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primaryBlue.withAlpha((255 * 0.2).round()),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: AppColors.primaryBlue, size: 32),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${lieu.nombreEvenements} événement${lieu.nombreEvenements > 1 ? 's' : ''} organisé${lieu.nombreEvenements > 1 ? 's' : ''} à ce lieu',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 28),

                        // Section Avis
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Avis des visiteurs',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                AppRoutes.navigateTo(
                                  context,
                                  AppRoutes.avisLieuList,
                                  arguments: {
                                    'lieuId': widget.lieuId,
                                    'lieuNom': lieu.nom,
                                  },
                                );
                              },
                              child: const Text('Voir tout'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (lieu.moyenneAvis != null)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.ratingColor.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.star,
                                  color: AppColors.ratingColor,
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  lieu.moyenneAvis!.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ratingColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '/ 5',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.mediumGrey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star_border, color: Colors.grey, size: 32),
                                const SizedBox(width: 12),
                                Text(
                                  'Aucun avis pour le moment',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              AppRoutes.navigateTo(
                                context,
                                AppRoutes.avisLieuList,
                                arguments: {
                                  'lieuId': widget.lieuId,
                                  'lieuNom': lieu.nom,
                                },
                              );
                            },
                            icon: const Icon(Icons.reviews),
                            label: const Text('Voir tous les avis'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: AppColors.primaryGreen,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: Consumer<LieuDetailNotifier>(
        builder: (context, notifier, _) {
          final lieu = notifier.cache[widget.lieuId];
          if (lieu == null) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () {
              // Vérifier si l'utilisateur est connecté
              final authNotifier = context.read<AuthNotifier>();
              if (!authNotifier.isAuthenticated) {
                // Rediriger vers la page de connexion
                AppRoutes.navigateTo(context, AppRoutes.login);
                // Afficher un message
                SnackBarHelper.showInfo(
                  context,
                  'Veuillez vous connecter pour donner votre avis',
                );
                return;
              }

              AppRoutes.navigateTo(
                context,
                AppRoutes.avisLieuCreate,
                arguments: {'lieuId': lieu.id, 'lieuNom': lieu.nom},
              );
            },
            icon: const Icon(Icons.rate_review),
            label: const Text('Donner mon avis'),
            backgroundColor: AppColors.primaryOrange,
          );
        },
      ),
    );
  }

  Widget _buildImageHeader(dynamic lieu) {
    if (lieu.imageLieu != null && lieu.imageLieu!.isNotEmpty) {
      return SizedBox(
        width: double.infinity,
        height: 250,
        child: CachedNetworkImage(
          imageUrl: lieu.imageLieu!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey.shade300,
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 60,
            ),
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        height: 250,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryOrange,
              AppColors.primaryOrange.withAlpha((255 * 0.7).round()),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.place,
            size: 80,
            color: Colors.white.withAlpha((255 * 0.5).round()),
          ),
        ),
      );
    }
  }

  void _showOwnerMenu(BuildContext context, LieuEntity lieu) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () async {
                Navigator.pop(context);
                final canEdit = await context.canEditLieu(lieu);
                if (canEdit && context.mounted) {
                  AppRoutes.navigateTo(
                    context,
                    AppRoutes.lieuEdit,
                    arguments: {'lieu': lieu},
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                final canDelete = await context.canDeleteLieu(lieu);
                if (canDelete && context.mounted) {
                  _showDeleteDialog(context, lieu);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(context, 'Partage à venir');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPublicMenu(BuildContext context, LieuEntity lieu) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(context, 'Partage à venir');
              },
            ),
            ListTile(
              leading: const Icon(Icons.favorite_border),
              title: const Text('Ajouter aux favoris'),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(context, 'Favoris à venir');
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                SnackBarHelper.showInfo(context, 'Signalement à venir');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, LieuEntity lieu) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Supprimer le lieu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer ce lieu ?',
              style: Theme.of(dialogContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha((255 * 0.1).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha((255 * 0.3).round())),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.place, size: 20, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          lieu.nom,
                          style: Theme.of(dialogContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cette action est irréversible',
                          style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tous les événements associés à ce lieu seront également affectés.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );

        await getit.getIt<LieuEvenementService>().deleteLieu(lieu.id);

        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          SnackBarHelper.showSuccess(
            context,
            '${lieu.nom} a été supprimé avec succès',
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) Navigator.pop(context);

        if (context.mounted) {
          String errorMessage = 'Erreur lors de la suppression: ';

          if (e.toString().contains('401')) {
            errorMessage = 'Session expirée. Veuillez vous reconnecter.';
            await context.read<AuthNotifier>().logout();
            if (context.mounted) {
              await Navigator.pushNamed(context, '/login');
              Navigator.pop(context);
            }
          } else if (e.toString().contains('403')) {
            errorMessage = 'Vous n\'avez pas la permission de supprimer ce lieu.';
          } else {
            errorMessage += e.toString();
          }

          SnackBarHelper.showError(context, errorMessage);
        }
      }
    }
  }
}