# Tour de Garde

Un jeu de tir à la première personne, en 3D, où tu défends un relais au milieu du désert.
Des vagues d'ennemis arrivent de l'horizon. Tu tires, tu récupères de la ferraille sur
leurs carcasses, et entre deux vagues tu dépenses cette ferraille pour devenir plus fort.

Fait avec [Godot 4](https://godotengine.org/), un moteur de jeu gratuit et open source.

---

## Jouer

Télécharge le jeu, double-clique, c'est tout. Rien à installer.

- **Windows** : `TourDeGarde.exe`
- **Linux** : `TourDeGarde.x86_64`

Le fichier est autonome : tout le jeu tient dans cet unique fichier.

**Où le télécharger ?** Dans l'onglet **Releases** du dépôt.
Si aucune Release n'existe encore, va dans l'onglet **Actions**, clique sur la dernière
ligne verte, et descends jusqu'à **Artifacts**.

> Au premier lancement, Windows peut afficher « Windows a protégé votre ordinateur ».
> C'est normal pour un programme sans signature payante : clique sur
> *Informations complémentaires* puis *Exécuter quand même*.

## Commandes

| Touche | Action |
|---|---|
| **ZQSD** / **WASD** | Se déplacer |
| **Souris** | Viser |
| **Clic gauche** | Tirer |
| **Espace** | Sauter |
| **Maj** | Sprinter |
| **R** | Recharger |
| **Tab** | Ouvrir / fermer l'atelier |
| **Entrée** | Lancer la vague suivante tout de suite (ou rejouer) |
| **Échap** | Libérer la souris |

Les touches sont lues par leur **position physique** : sur un clavier AZERTY, c'est
naturellement ZQSD.

## Comment on joue

1. **Entracte.** Tu as quelques secondes avant chaque vague. Place des tourelles,
   améliore ton arme, répare le relais. Appuie sur **Entrée** si tu es prêt avant la fin
   du décompte.
2. **Vague.** Les ennemis foncent vers le relais. S'ils t'approchent, ils s'en prennent
   à toi d'abord.
3. **La partie s'arrête** si le relais tombe à zéro, ou si tu meurs.

Chaque ennemi tué rapporte de la ferraille, automatiquement. Plus tu survis longtemps,
plus les vagues sont grosses et résistantes.

### Les ennemis

| Nom | Apparition | Comportement |
|---|---|---|
| **Rôdeur** | dès la vague 1 | Équilibré. Le gros des troupes. |
| **Traqueur** | vague 3 | Rapide et fragile. Te déborde si tu l'ignores. |
| **Colosse** | vague 5 | Lent, énorme, très résistant, frappe fort. |

### L'atelier (Tab)

| Amélioration | Effet |
|---|---|
| Tourelle automatique | Se pose sur un des 6 socles autour du relais et tire toute seule. |
| Dégâts +20% | Cumulable. |
| Réparer le relais | Rend 200 points de structure. |
| Chargeur +10 | Cumulable. |
| Trousse de soin | Rend toute ta santé. |

Chaque achat fait monter le prix du suivant. L'atelier ne met **pas** le jeu en pause :
l'ouvrir pendant une vague est risqué.

---

## Modifier le jeu

Tu n'as besoin de rien installer pour *jouer*. Pour *modifier*, il te faut Godot :

1. Télécharge **Godot 4.3** sur [godotengine.org](https://godotengine.org/download)
   (version *standard*, pas .NET). C'est un simple fichier à lancer, pas d'installation.
2. Lance Godot, clique sur **Importer**, et choisis le fichier `project.godot` de ce dossier.
3. Appuie sur **F5** pour lancer le jeu.

### Où se trouve quoi

```
scenes/     Les objets du jeu (structure 3D, meshes, matériaux)
  main.tscn     Le niveau : terrain, lumière, relais, socles à tourelles
  player.tscn   Le joueur et son arme
  enemy.tscn    Un ennemi
  turret.tscn   Une tourelle

scripts/    Le comportement (langage GDScript, proche de Python)
  game.gd         État global : ferraille, vague en cours, touches
  main.gd         Chef d'orchestre : relie tout, gère les achats et la défaite
  player.gd       Déplacement, visée, tir, rechargement, santé
  enemy.gd        IA : marcher vers le relais, attaquer
  wave_manager.gd Composition et déclenchement des vagues
  relay.gd        La structure à défendre
  turret.gd       Visée et tir automatiques
  hud.gd          L'interface (barres, compteurs, messages)
  shop.gd         L'atelier
  crosshair.gd    Le réticule
  effects.gd      Traceurs de balles, impacts, explosions
```

Il n'y a **aucun asset externe** : tous les visuels sont des formes générées par le
moteur (cubes, capsules, cylindres). C'est ce qui rend le projet léger et facile à
bidouiller — change une couleur dans un script et relance.

### Quelques réglages faciles pour commencer

| Envie | Fichier | Ligne à changer |
|---|---|---|
| Vagues plus longues à arriver | `scripts/wave_manager.gd` | `INTERMISSION` |
| Arme plus puissante | `scripts/player.gd` | `BASE_DAMAGE` |
| Plus d'ennemis par vague | `scripts/wave_manager.gd` | `_build_composition()` |
| Relais plus solide | `scenes/main.tscn` | `max_health` du nœud `Relay` |
| Sauter plus haut | `scripts/player.gd` | `JUMP_VELOCITY` |

---

## Compilation automatique

À chaque modification envoyée sur `main`, GitHub compile le jeu pour Windows et Linux
(voir `.github/workflows/build.yml`). Les fichiers se récupèrent dans l'onglet **Actions**.

Pour publier une vraie **Release** téléchargeable :

```bash
git tag v1.0
git push origin v1.0
```

## Idées pour la suite

- Du son : tirs, impacts, musique qui monte pendant les vagues
- Un menu principal et un meilleur score sauvegardé
- D'autres armes (fusil à pompe, lance-roquettes)
- Des ennemis qui tirent à distance
- Placer les tourelles librement au lieu des 6 socles fixes
- Un boss toutes les 10 vagues
