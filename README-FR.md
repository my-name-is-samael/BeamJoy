# BeamJoy  
Mod tout-en-un pour BeamMP

<p align="center">
  <img src="https://raw.githubusercontent.com/my-name-is-samael/BeamJoy/refs/heads/main/assets/logo_white.png" style="width: 49%; height: auto;" />
  <a target="_blank" href="https://www.youtube.com/watch?v=l-lbXQDEz-o" alt="Trailer">
      <img src="https://raw.githubusercontent.com/my-name-is-samael/BeamJoy/refs/heads/main/assets/trailer_preview.jpg" style="width: 49%; height: auto;" />
  </a>
</p>

Ce mod a pour objectif de fournir un accès facile aux outils de modération et aux activités pour les joueurs de votre serveur BeamMP.
De plus, il intègre un framework modulaire permettant aux développeurs d’ajouter facilement de nouvelles fonctionnalités.

🎮 Venez l'essayer sur mon serveur de démonstration: Cherchez "BeamJoy DEMO" dans la liste des serveurs en jeu.

## Sommaire
1. [Fonctionnalités](#fonctionnalités)
2. [Comment Installer](#comment-installer)
3. [Comment Ajouter une Carte Moddée](#comment-ajouter-une-carte-moddée-à-votre-serveur)
4. [Comment Installer les Données du Jeu de Base (Stations-service, Garages, Points de Livraison, Courses, etc.)](#comment-installer-les-données-des-cartes-du-jeu-de-base)
5. [Comment Configurer ou Ajouter une Langue](#comment-configurer-ou-ajouter-une-langue-à-votre-serveur)
6. [Tutoriels Vidéo](#tutoriels-vidéo)
7. [Participation](#participation)
8. [Roadmap](#roadmap)
9. [Remerciements](#remerciements)

## Fonctionnalités

<details>
  <summary>Montrer</summary>

### Globales et Synchronisation

- Synchronisation activable pour le Soleil, la Météo, la Gravité, la Vitesse de Simulation, et la Température Atmosphérique par heure.
- Configuration des paramètres pour le Soleil, la Météo, la Gravité, la Vitesse de Simulation, et la Température Atmosphérique par heure.
- Le temps qui passe est synchronisé entre tous les joueurs.
- Empêche les joueurs de mettre la simulation en pause.
- Switcheur de cartes optimisé (aucune de vos cartes moddées ne doit être envoyée aux joueurs qui rejoignent, ce qui évite les temps de téléchargement).
- Les joueurs peuvent voter pour changer de carte.
- Système de Niveau de Réputation (similaire à l’XP). Les joueurs gagnent des points en conduisant et en participant à des activités. Ce système est hautement personnalisable et sert uniquement à classer les joueurs.
- Traductions complètes (validée uniquement pour EN et FR; n’hésitez pas à soumettre des modifications pour d’autres langues).
- Système de permissions modulaire, vous permettant de créer des groupes et d’ajuster les permissions.
- Message de connexion personnalisable par langue.
- Annonces de chat pour les connexions et déconnexions des joueurs.
- Système d'annonce de messages à intervalles définis, personnalisable par langue.
- Toutes les configurations du serveur peuvent être modifiées en jeu, avec les permissions adéquates; aucune modification dans les fichiers n’est nécessaire.
- Console, WorldEditor et NodeGrabber activables/désactivables pour les joueurs (certains scénarios désactivent ces fonctions pour éviter la triche).
- Système de commandes dans le chat entièrement traduit et dynamique.

### Qualité de Vie (QoL)

- Nametags des joueurs retravaillées et activables/désactivables, indiquant qui est spectateur, qui joue, et les véhicules inactifs. Les props n'ont pas de nametags, ni les remorques si leur propriétaire les tracte.
- Chat en jeu retravaillé avec indicateur de Rang ou Niveau de Réputation.
- Feux du véhicule automatiques en fonction du cycle jour-nuit, activables/désactivables.
- Caméra libre adoucie activable/désactivable.
- Sélecteur de champ de vision (FoV) précis.
- Mode fantôme pour éviter que les joueurs rapides ne percutent des joueurs nouvellement apparus.
- Indicateur de drift à l’écran, activable/désactivable.
- Annonce activable pour les gros drifts.
- Récompenses de réputation en fonction de la longueur des drifts.
- Presque toutes les applications d'interface du jeu de base fonctionnent dans chaque scénario.
- Les missions du menu Carte sont supprimées car indisponibles sur BeamMP.
- La gestion du trafic est effectuée avec une permission VehicleCap par groupe pour éviter un soft-lock du jeu lorsque la permission est manquante.
- Empêche les utilisateurs d’activer leurs propres mods et de ruiner l’expérience du serveur.
- Un sélecteur de véhicules secondaire et réactif, avec toutes les fonctionnalités de base, avec les images de prévisualisation (fonctionne aussi avec les véhicules moddées).
- Éditeur de thème complet pour les fenêtres, disponible pour les admins et certains joueurs sélectionnés.
- Blacklist de modèles de véhicules pour empêcher leur utilisation sur votre serveur (seuls le staff peut les voir et les faire apparaître).
- Permissions spécifiques pour faire apparaître des remorques et des props. Les véhicules d’une catégorie pour laquelle vous n’avez pas la permission seront cachés dans les deux sélecteurs de véhicules.
- Présélections intégrées pour le temps de jeu (crépuscule, midi, aube, minuit) et la météo (clair, nuageux, pluie légère, pluvieux, neige légère, et neigeux).
- Conservation de carburant/énergie activable lorsque le véhicule est réinitialisé, rendant les stations-service et les stations de recharge indispensables.
- Systène de ravitaillement d'urgence configurable pour les véhicules des joueurs qui tombent en panne.

### Services et infrastructures de carte

- Stations-service et Stations de Recharge, avec types de carburant indépendants.
- Éditeur complet de stations pour les admins et certains joueurs sélectionnés.
- Garages pour réparer les véhicules et remplir le NOS.
- Éditeur complet des garages pour les admins et certains joueurs sélectionnés.
- GPS fonctionnel pour trouver des stations-service, des garages, et des joueurs (et plus encore dans certains scénarios).

### Modération

- Mute des joueurs.
- Kick des joueurs.
- Ban temporaire des joueurs.
- Ban des joueurs.
- Les joueurs peuvent voter pour kicker les perturbateurs.
- Blocage du véhicule spécifique d’un joueur (ou de tous ses véhicules).
- Activation/désactivation du moteur d’un joueur spécifique (ou de tous ses véhicules).
- Explosion du véhicule d’un joueur spécifique.
- Téléportation de véhicules.
- Nametags activables/désactivables.
- Points de voyage rapide activables dans le menu Carte.
- Possibilité pour les joueurs de créer des monocycles (mode marche), activable/désactivable.
- Whitelist activable (outrepassée par le staff).
- Par défaut, les joueurs du groupe "aucun" n’ont pas la permission de faire apparaître des véhicules et apparaissent dans une liste spécifique, ce qui permet aux modérateurs de les promouvoir facilement.

### Scénarios

#### Courses

- Courses multijoueurs avec classement et delta de temps.
- Courses solo avec classement et delta de temps.
- Éditeur de courses pour les admins et certains joueurs sélectionnés.
- Les courses multijoueurs peuvent être forcées par le staff ou votées par les joueurs.
- Stratégies de réapparition variées : Tous les types de réapparition, aucune réapparition (avec compteur DNF), réapparition au dernier point de contrôle et réapparition dans les stands.
- Stand de ravitaillement fonctionnel.
- Les joueurs peuvent utiliser n’importe quel véhicule, un modèle spécifique ou une configuration spécifique définie au lancement de la course.
- Editeur dynamique des courses permettant des raccourcis ou des détours.
- Enregistrement persistant des records de chaque course.
- Récompenses de réputation pour la participation, la victoire et les records battus, hautement personnalisables.
- Compteur de temps en temps réel avec indication au passage des points de contrôle, et affichage dans l’interface.
- Diffusion des temps pour les courses solo activable.
- Outils pratiques dans l'éditeur de courses, notamment la rotation à 180 degrés du véhicule et l'inversion de course.

#### Chasseur / CarHunt

- Système de Hunter fonctionnel où le fugitif et les chasseurs ne peuvent pas voir les plaques nominatives de l’autre équipe.
- Le fugitif doit franchir un certain nombre de points de contrôle sans être attrapé par les chasseurs ou se bloquer par ses propres erreurs de conduite.
- Chaque chasseur peut réinitialiser son véhicule, mais aura une pénalité de temps avant de pouvoir reprendre la chasse.
- Configurations de véhicules imposées au lancement possibles.
- Éditeur complet des positions de départ (Chasseurs et Fugitif) et des points de contrôle pour les admins et certains joueurs sélectionnés.
- Récompenses de réputation pour les participants et les vainqueurs, hautement personnalisables.

#### Livraisons

- Livraisons de véhicules (comme dans le jeu solo).
- Livraisons de colis.
- Livraisons en équipe (tous les participants livrent au même endroit en même temps).
- Éditeur de points de livraison pour les admins et certains joueurs sélectionnés.
- Récompenses de réputation, hautement personnalisables.
- Liste noire de modèles de véhicules pour la livraison de véhicules, personnalisable (par défaut *atv* et *citybus*).

#### Missions de Bus

- Trajets de bus (comme dans le jeu solo).
- Applications UI fonctionnelles.
- Informations dynamiques sur les trajets de bus.
- Éditeur de trajets pour les admins et certains joueurs sélectionnés.
- Récompenses de réputation en fonction des kilomètres parcourus, hautement personnalisables.

#### Jeu de Speed

- Jeu type Battle Royale où les joueurs doivent rester au-dessus d’une vitesse minimale qui augmente. Rester en dessous trop longtemps vous fait exploser.
- Peut être forcé par le staff ou voté par les joueurs.
- Récompenses de réputation, hautement personnalisables.

#### Destruction Derby

- Jeu type Battle Royale où le dernier véhicule en mouvement gagne.
- Peut être lancé avec un nombre de vies défini.
- Des modèles de véhicules spécifiques peuvent être imposés pour un jeu thématique.
- Plusieurs arènes possibles par carte.
- Éditeur complet des arènes et des positions de départ pour les admins et certains joueurs sélectionnés.
- Récompenses de réputation pour la participation et la victoire, hautement personnalisables.

### Technique

- Framework intégré pour les scénarios et événements, facile à utiliser et faire évoluer pour les développeurs.
- Limites de communication améliorées entre le serveur et les clients.
- Manager par fonctionnalité.
- Système de création de fenêtres facile pour les développeurs (builders).
- Système de cache par domaine avec auto-request lors des changements.
- Système de traduction pour les clients, le serveur et les communications serveur-client.
- Couche DAO système de fichiers facilement remplaçable pour migrer vers des systèmes de bases de données (No)SQL.

</details>

## Comment installer

- Installez votre serveur BeamMP ([Télécharger BeamMP Server](https://beammp.com)) et configurez-le (au minimum votre *AuthKey*).
- Lancez votre serveur au moins une fois pour initialiser les fichiers.
- Téléchargez la dernière version du mod ([Mod Releases](https://github.com/my-name-is-samael/BeamJoy/releases)).
- Décompressez l’archive du mod dans le dossier *Resources* de votre serveur.
- Connectez votre jeu à votre serveur.
- Tapez dans la console du serveur `bj setgroup <votre_nom_de_joueur> owner` pour obtenir les permissions.
(*votre_nom_de_joueur* n'est pas sensible à la casse et peut être une sous-partie de votre nom de joueur).

## Comment ajouter une carte moddée à votre serveur

- Assurez-vous d'avoir la permission *SetMaps*.
- Placez l'archive de la carte dans le dossier *Resources* de votre serveur (pas dans *Client* ni *Server*).
- En jeu, allez dans le menu *Configuration* > *Serveur* > *Libellés des Cartes*.
- En bas, remplissez le *Nom Technique* (nom du dossier dans l'archive), le *Libellé de la Carte* (le nom que vos joueurs verront) et le *Nom Complet de l'Archive* (y compris l'extension) : par exemple, "ks_spa", "SPA Francorchamps", "ks_spa_v20230929.zip".
- Cliquez sur le bouton vert *Ajouter*.
- Votre carte sera désormais disponible dans le switch de carte et dans le vote de carte.

L'objectif du switcheur de carte optimisé est de n'envoyer que la carte moddée actuelle aux joueurs rejoignant le serveur, et de ne pas envoyer tous les autres mods de carte non utilisés.

**Attention** : Lors du passage depuis ou vers une carte moddée, le serveur redémarrera automatiquement. Prenez donc vos précautions pour avoir un système de redémarrage actif pour votre serveur.

## Comment installer les données des cartes du jeu de base

- Téléchargez l'archive des données ([disponible ici](https://github.com/my-name-is-samael/BeamJoy/releases/tag/datapack-2024-12-20)).
- Extrayez-la dans le dossier *Resources/Server/BeamJoyData/db/scenarii/*.
- Redémarrez le serveur.
- Vous aurez maintenant tous les scénarios et services disponibles sur les cartes du jeu de base pour vos joueurs.

## Comment configurer ou ajouter une langue à votre serveur

Le mod est fourni avec les langues EN, FR, DE, IT, ES, PT et RU.

Si vous voulez supprimer une ou plusieurs langues:
- Allez dans le dossier *Resources/Server/BeamJoyCore/lang* et supprimez les fichiers des langues indésirables.
- Mettez à jour le fichier *Resources/Server/BeamJoyData/db/bjc.json* pour supprimer toute occurence de ces langues dans :
    - Server.Lang
    - Server.Broadcasts
    - Server.WelcomeMessage

Si vous voulez ajouter une langue :
- Vous souhaitez ajouter une langue présente dans le jeu:
- - Dans le menu principal de BeamNG, ouvrez la console et tapez `dump(Lua:getSelectedLanguage())`.
- - Vous obtiendrez un résultat comme *"en_EN"*. Votre fichier JSON sera nommé selon la partie avant l’underscore et devra être en minuscules (par exemple, *Tr_UI* donnera un fichier nommé *tr.json*).
- Vous souhaitez ajouter une nouvelle langue:
- - Déterminez le code de votre langue (habituellement 2 ou 3 lettres). Votre fichier JSON sera nommé avec ce code en minuscules (par exemple, *tr.json*)
- Vous pouvez copier le fichier *Resources/Server/BeamJoyCore/lang/en.json* sous le nom que vous avez déterminé dans l’étape précédente, dans le même dossier.
- Vous pouvez traduire ce fichier nouvellement créé, mais n'oubliez pas de ne modifier que les valeurs et pas les clés, ni les variables entre accolades (**{** et **}**).

Si vous souhaitez modifier certains libellés :
- Trouvez votre fichier de langue dans *Resources/Server/BeamJoyCore/lang*.
- Comme mentionné précédemment, ne changez pas les clés ni les variables entre accolades (**{** et **}**) dans les valeurs.

## Tutoriels Vidéo

Bientôt disponibles...

## Participation

N'hésitez pas à créer des pull-requests, tant que vous respectez les normes de code actuelles.

N'hésitez pas non plus à signaler des bugs ou à proposer des améliorations sur n'importe quelle fonctionnalité. Je ferai de mon mieux pour vous répondre rapidement, mais gardez à l’esprit que je ne travaille plus à temps plein sur ce projet.

Vous pouvez aussi corriger les traductions si elles sont incorrectes :
<ul>
    <li>
        <a href="https://gitlocalize.com/repo/9945/fr?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/fr/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/de?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/de/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/it?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/it/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/es?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/es/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/pt?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/pt/badge.svg" /> </a>
    </li>
    <li>
        <a href="https://gitlocalize.com/repo/9945/ru?utm_source=badge"> <img src="https://gitlocalize.com/repo/9945/ru/badge.svg" /> </a>
    </li>
</ul>

## Roadmap

- [ ] Fork avec uniquement les fonctionnalités de course
- [ ] Présélections de météo aléatoires automatiques activables (peut-être avec des transitions douces, en attente de modifications du jeu de base sur la température et la météo)
- [ ] Recherche d’un système de cache côté client (type cookie, utile pour les records personnels dans les courses, par exemple)

Implementer les fonctionnalités de BeamMP v3.5+ quand il sortira:
- Ajouter la configuration Core pour AllowGuests ([#335](https://github.com/BeamMP/BeamMP-Server/pull/335))
- Bypass du maximum de joueurs à la connection pour les membres du staff ([#372](https://github.com/BeamMP/BeamMP-Server/pull/372))

## Remerciements

Merci à tous les BETA-testeurs qui m'ont aidé à tester et déboguer les fonctionnalités :
dvergar, Trina, Baliverne0, Rodjiii, Lotax, Nath_YT, korrigan_91, et bien d'autres.

Un grand merci à prestonelam2003 pour son travail sur [CobaltEssentials](https://github.com/prestonelam2003/CobaltEssentials), qui m'a inspiré à créer BeamJoy, bien que je n'aie copié aucune ligne de son code.
Un autre grand merci à StanleyDudek pour son travail sur [CobaltEssentialsInterface](https://github.com/StanleyDudek/CobaltEssentialsInterface), qui m'a appris à créer des mods front-end pour BeamMP, à communiquer avec le serveur et à utiliser les bases de imgui.
