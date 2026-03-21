import 'package:equatable/equatable.dart';
import 'package:event_flow/domains/entities/evenement_entity.dart';
import 'package:event_flow/domains/entities/lieu_entity.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

// ==================== MODELS LIEU ====================

class LieuModel extends Equatable {
  final String id;
  final String nom;
  final String description;
  final String categorie;
  final double latitude;
  final double longitude;
  final DateTime dateCreation;
  final String proprietaireNom;
  final String proprietaireId;
  final int nombreEvenements;
  final double? moyenneAvis;
  final String? imageLieu; 

  const LieuModel({
    required this.id,
    required this.nom,
    required this.description,
    required this.categorie,
    required this.latitude,
    required this.longitude,
    required this.dateCreation,
    required this.proprietaireNom,
    required this.proprietaireId,
    required this.nombreEvenements,
    this.moyenneAvis,
    this.imageLieu, 
  });

  factory LieuModel.fromJson(Map<String, dynamic> json) {
    String proprietaireId = '';
    
    if (json['proprietaire_id'] != null && json['proprietaire_id'].toString().isNotEmpty) {
      proprietaireId = json['proprietaire_id'].toString();
      _logger.d('proprietaire_id trouvé: "$proprietaireId"');
    } else if (json['proprietaire'] != null) {
      if (json['proprietaire'] is String) {
        proprietaireId = json['proprietaire'] as String;
        _logger.d('proprietaire (string) trouvé: "$proprietaireId"');
      } else if (json['proprietaire'] is Map) {
        final propMap = json['proprietaire'] as Map<String, dynamic>;
        proprietaireId = propMap['id']?.toString() ?? '';
        _logger.d('proprietaire.id (map) trouvé: "$proprietaireId"');
      }
    }
    
    _logger.d('RÉSULTAT FINAL: proprietaireId = "$proprietaireId"');

    String description = '';
    if (json['description'] != null) {
      description = json['description'].toString().trim();
    }

    // Extraction de l'URL de l'image
    String? imageLieu;
    if (json['image_lieu'] != null && json['image_lieu'].toString().isNotEmpty) {
      imageLieu = json['image_lieu'].toString();
      _logger.d('image_lieu trouvée: "$imageLieu"');
    }

    return LieuModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      description: description,
      categorie: json['categorie'] as String,
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      dateCreation: json['date_creation'] != null
          ? DateTime.parse(json['date_creation'] as String)
          : DateTime.now(),
      proprietaireNom: json['proprietaire_nom'] as String? ?? 'Inconnu',
      proprietaireId: proprietaireId,
      nombreEvenements: json['nombre_evenements'] as int? ?? 0,
      moyenneAvis: json['moyenne_avis'] != null
          ? double.parse(json['moyenne_avis'].toString())
          : null,
      imageLieu: imageLieu, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'categorie': categorie,
      'latitude': latitude,
      'longitude': longitude,
      'date_creation': dateCreation.toIso8601String(),
      'proprietaire_nom': proprietaireNom,
      'proprietaire_id': proprietaireId, 
      'nombre_evenements': nombreEvenements,
      'moyenne_avis': moyenneAvis,
      'image_lieu': imageLieu, 
    };
  }

  LieuEntity toEntity() {
    _logger.d('LieuModel.toEntity - "$nom"');
    _logger.d(' proprietaireId: "$proprietaireId"');
    _logger.d(' imageLieu: "$imageLieu"');

    return LieuEntity(
      id: id,
      nom: nom,
      description: description,
      categorie: categorie,
      latitude: latitude,
      longitude: longitude,
      dateCreation: dateCreation,
      proprietaireNom: proprietaireNom,
      proprietaireId: proprietaireId,
      nombreEvenements: nombreEvenements,
      moyenneAvis: moyenneAvis,
      imageLieu: imageLieu, 
    );
  }

  @override
  List<Object?> get props => [
    id,
    nom,
    description,
    categorie,
    latitude,
    longitude,
    dateCreation,
    proprietaireNom,
    proprietaireId,
    nombreEvenements,
    moyenneAvis,
    imageLieu, 
  ];

  @override
  String toString() {
    return 'LieuModel(id: $id, nom: $nom, proprietaireId: $proprietaireId, '
        'categorie: $categorie, imageLieu: $imageLieu)';
  }
}

// ==================== MODELS ÉVÉNEMENT (inchangé) ====================

class EvenementModel extends Equatable {
  final String id;
  final String nom;
  final String description;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String lieuId;
  final String lieuNom;
  final double? lieuLatitude;
  final double? lieuLongitude;
  final String organisateurId;
  final String organisateurNom;
  final double? moyenneAvis;
  final int nombreAvis;
  final double? distance;

  const EvenementModel({
    required this.id,
    required this.nom,
    required this.description,
    required this.dateDebut,
    required this.dateFin,
    required this.lieuId,
    required this.lieuNom,
    this.lieuLatitude,
    this.lieuLongitude,
    required this.organisateurId,
    required this.organisateurNom,
    this.moyenneAvis,
    required this.nombreAvis,
    this.distance,
  });

  factory EvenementModel.fromJson(Map<String, dynamic> json) {
    _logger.d('EvenementModel.fromJson - Parsing événement: ${json['nom']}');
  
    String organisateurId = '';
    if (json['organisateur_id'] != null && json['organisateur_id'].toString().isNotEmpty) {
      organisateurId = json['organisateur_id'].toString();
      _logger.d('organisateur_id trouvé: "$organisateurId"');
    } else if (json['organisateur'] != null) {
      if (json['organisateur'] is String) {
        organisateurId = json['organisateur'] as String;
      } else if (json['organisateur'] is Map) {
        organisateurId = (json['organisateur'] as Map)['id']?.toString() ?? '';
      }
    }

    String description = '';
    if (json['description'] != null) {
      description = json['description'].toString().trim();
    }

    return EvenementModel(
      id: json['id'] as String,
      nom: json['nom'] as String,
      description: description,
      dateDebut: DateTime.parse(json['date_debut'] as String),
      dateFin: DateTime.parse(json['date_fin'] as String),
      lieuId: json['lieu'] as String? ?? '',
      lieuNom: json['lieu_nom'] as String,
      lieuLatitude: json['lieu_latitude'] != null
          ? double.parse(json['lieu_latitude'].toString())
          : null,
      lieuLongitude: json['lieu_longitude'] != null
          ? double.parse(json['lieu_longitude'].toString())
          : null,
      organisateurId: organisateurId,
      organisateurNom: json['organisateur_nom'] as String,
      moyenneAvis: json['moyenne_avis'] != null
          ? double.parse(json['moyenne_avis'].toString())
          : null,
      nombreAvis: json['nombre_avis'] as int? ?? 0,
      distance: json['distance'] != null
          ? double.parse(json['distance'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'description': description,
      'date_debut': dateDebut.toIso8601String(),
      'date_fin': dateFin.toIso8601String(),
      'lieu': lieuId,
      'lieu_nom': lieuNom,
      'lieu_latitude': lieuLatitude,
      'lieu_longitude': lieuLongitude,
      'organisateur_id': organisateurId,  
      'organisateur_nom': organisateurNom,
      'moyenne_avis': moyenneAvis,
      'nombre_avis': nombreAvis,
      'distance': distance,
    };
  }

  EvenementEntity toEntity() {
    return EvenementEntity(
      id: id,
      nom: nom,
      description: description,
      dateDebut: dateDebut,
      dateFin: dateFin,
      lieuId: lieuId,
      lieuNom: lieuNom,
      lieuLatitude: lieuLatitude,
      lieuLongitude: lieuLongitude,
      organisateurId: organisateurId,
      organisateurNom: organisateurNom,
      moyenneAvis: moyenneAvis,
      nombreAvis: nombreAvis,
      distance: distance,
    );
  }

  @override
  List<Object?> get props => [
    id,
    nom,
    description,
    dateDebut,
    dateFin,
    lieuId,
    lieuNom,
    lieuLatitude,
    lieuLongitude,
    organisateurId,
    organisateurNom,
    moyenneAvis,
    nombreAvis,
    distance,
  ];

  @override
  String toString() {
    return 'EvenementModel(id: $id, nom: $nom, organisateurId: $organisateurId, lieu: $lieuNom)';
  }
}