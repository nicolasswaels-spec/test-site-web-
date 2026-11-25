# Récapitulatif du projet « Zone Zéro » (pour reprendre avec Claude)

Copie ce document (ou son lien) au début d'une nouvelle conversation avec Claude Code,
en lui demandant de travailler sur ce dépôt et cette branche.

## Où est le code

- Dépôt GitHub : `nicolasswaels-spec/test-site-web-`
- Branche de travail : `claude/godot-fortnite-game-yp1r6h`
- Téléchargement direct :
  https://github.com/nicolasswaels-spec/test-site-web-/archive/refs/heads/claude/godot-fortnite-game-yp1r6h.zip
- Le jeu est dans le dossier `game/` (projet Godot **4.3**, GDScript). On l'ouvre en important
  `game/project.godot` dans Godot 4.3.
- Documentation joueur (commandes, règles, crédits) : `game/README.md`. Elle est tenue à jour à
  chaque modification : c'est la référence des règles actuelles.

Phrase type pour une nouvelle conversation :
> « Travaille sur le dépôt nicolasswaels-spec/test-site-web-, branche claude/godot-fortnite-game-yp1r6h.
> Lis RECAP_PROJET.md et game/README.md avant de commencer. Après chaque modification,
> pousse sur la branche et redonne-moi le lien de téléchargement. »

## Le jeu en bref

Jeu de défense en vagues à la première personne, en français, inspiré de Fortnite (récolte à la
hache, construction sur grille), ambiance forêt stylisée au crépuscule (références : Firewatch,
The Pathless).

- Menu : COMMENCER, JOUER À DEUX (écran scindé), MODE TEST (ressources infinies, toutes les armes,
  bouton ZONE SUIVANTE dans la pause),
  GRAPHISMES (qualité haute/basse), QUITTER.
- Zone 1 : une sphère à défendre, 1 min 30 de préparation puis 10 vagues de squelettes
  (pause de 60 s entre les vagues, lancer en avance reporte 50 % du temps restant).
- Après la 10ᵉ vague : un couloir s'ouvre au nord vers la zone 2 (autre biome, 2ᵉ sphère,
  10 vagues plus dures, qui démarrent seules au bout de 2 min).
- Zone 3 : volcan à l'ouest de la zone 2, TITAN DE LAVE (boss immobile, 4 attaques dont une invocation de squelettes), rejoint en 1 min.
- Zone « 4 » : 3e sphère à la place du titan, dans le volcan, défense au bout de 3 min, avec des squelettes archers.
- Arbres / rochers magiques (4 par zone) : bois / pierre magique → pièces 5× plus solides.
- Récolte : bois (arbres) et pierre (rochers, récolte débloquée par la hache « bois » niveau 5 ; coffres) avec 3 cibles bonus qui apparaissent au 1er coup (+100 % sur le coup, +80 % du gain final par cible) ;
  pièces métalliques au sol (barbelés).
- Construction grille 4 m : murs, sols, rampes, en bois ou pierre ; réparation, 3 niveaux
  d'amélioration, modifications (porte, fenêtre, trappe), barbelés.
- Armes : pistolet (départ), fusil d'assaut (fabriqué après la zone 1), canon cryogénique (coffre),
  hache. 2 armes équipées + hache.
- Améliorations : 8 niveaux par branche (pistolet, fusil, cryo, hache, barbelés).
- Coffres gardés par des groupes de squelettes.
- Ennemis : squelettes de base, à capuche (traqueurs), boss.
- Vies : 5 par joueur, retour instantané sur place avec E / X ; sans vie, attente croissante
  (5 s, +2 s par mort) et réapparition à ~25 m de la sphère.
- Coop local à 2 en écran scindé (clavier/souris + manette, ou deux manettes).
- Os : os (50 % par squelette), os imposant (boss), os en flèche (archer), tas d'os imposant (titan) ;
  visibles seulement dans l'inventaire, usage à définir.
- Menu de la sphère (E / X) : LANCER + CRÉATION D'ARME (dès la 2e sphère : cryo, onde de choc).
- Onde de choc : 1 os par tir, cône 120°, 6 m, 225 dégâts (440 max), 4 s ; améliorations dégâts / rechargement / portée.
- Musique : fichiers à déposer dans `game/assets/music/` (`menu`, `game`, `battle` en mp3/ogg/wav).

## Organisation du code (`game/`)

```
project.godot          scène de départ = menu ; autoloads GameInput, Sfx, Settings, Music
scenes/menu.tscn       scènes minimales : tout est construit par script
scenes/main.tscn
scripts/
  main.gd              monde, décor, zones 1 et 2, vagues, coffres, ramassables,
                       joueurs et écran scindé, vies/réapparition, mode test
  player.gd            joueur : déplacement, armes (GUNS), hache, construction, réparation,
                       améliorations, avatar 3D + bras FPS, vies
  zombie.gd            squelettes : IA (chasse, itinéraire, gardiens), statuts de glace,
                       struct_mult (dégâts aux constructions),
                       barbelés, recul
  structure.gd         pièces de construction (PV, niveaux, réparation, modifications, pièges)
  upgrades.gd          TOUS les coûts et effets des améliorations
  hud.gd               interface d'un joueur (barres, minimap, pause, fin, navigation manette)
  hud_group.gd         diffuse les messages généraux aux HUD des deux joueurs
  inventory_ui.gd      inventaire en cases (ressources, os, armes + fiche d'actions) et page Améliorations
  menu.gd              menu principal
  titan.gd             titan de lave (boss de la zone volcanique : boules de feu, onde de choc, éruptions)
  orb.gd               sphère à défendre
  tree.gd, rock.gd     ressources à la hache ; harvest.gd = cibles et bonus (HIT_BONUS, FINAL_PER_HIT) ; weak_spot.gd = cible
  chest.gd             coffres et tirage du butin
  pickup.gd            pièces métalliques ; resource_drop.gd = ressources lâchées au sol
  nature.gd            placement des modèles de nature
  input_setup.gd       actions clavier/manette par joueur (« action@index ») — autoload GameInput
  input_router.gd      répartit les entrées entre les joueurs en coop
  sfx.gd               sons générés par code — autoload Sfx
  music.gd             musique de fond avec fondus — autoload Music
  settings.gd          options (qualité, coop, mode test) — autoload Settings
  mats.gd, ui.gd       matériaux et style d'interface
assets/                modèles 3D CC0 : nature (Quaternius), skeletons, chests, characters (KayKit) ;
                       ui/ (icônes de ressources, générées par tools/make_icons.py) ;
                       music/ (tes morceaux)
```

## Où régler l'équilibrage

- `scripts/main.gd` (en tête) : durées (START_TIME 90 s, BREAK_TIME 60 s, ZONE2_TIME 120 s, BOSS_TRAVEL_TIME 60 s, ZONE4_TIME 180 s,
  LATE_COUNT_MULT / LATE_HP_MULT / LATE_STRUCT_MULT (sphères 2 et 3), MAGIC_PER_ZONE, CARRY_RATIO 0,5),
  vies (OUT_WAIT_BASE, OUT_WAIT_STEP, REVIVE_INVULN, OUT_RESPAWN_DIST), taille des zones,
  nombre de vagues ; `difficulty()`, `_start_wave`, `_spawn_zombie` : nombre, PV, vitesse ennemis.
- `scripts/player.gd` : GUNS (chargeur, cadence, dégâts), cadence de la hache (`swing_cd`),
  coût des pièces, PV du joueur, START_LIVES.
- `scripts/upgrades.gd` : coûts et effets de toutes les améliorations, recettes de création d'arme (CRAFTS),
  onde de choc (SHOCK_COSTS, SHOCK_LEVELS, SHOCK_HALF_ANGLE).
- `scripts/zombie.gd` : niveaux des squelettes (level_hp, level_speed, level_struct_damage, level_player_damage),
  portées de chasse, effets de la glace. `main.gd` : max_level(), _wave_levels() et _roll_level() (répartition des niveaux).
- `scripts/chest.gd` : probabilités et contenu du butin.
- `scripts/orb.gd` : PV de la sphère.
- `scripts/titan.gd` : PV et dégâts du titan (BASE_HP, FIREBALL_*, SLAM_*, ERUPT_*).
- `scripts/structure.gd` : MAGIC_MULT (×5) et MAGIC_REPAIR_FULL (1000) des pièces magiques.

## Conventions et méthode de travail

- Interface et commentaires en français.
- Les scènes ne sont presque pas utilisées : objets créés par code.
- En coop, chaque joueur a ses propres actions (`interact@0`, `interact@1`…) ; utiliser `p.a("action")`.
- Tests : scripts Godot lancés sans écran (`godot --headless -s test.gd` depuis `game/`),
  captures d'écran avec un rendu logiciel.
- Après chaque modification : mettre à jour `game/README.md`, committer, pousser sur la branche,
  donner le lien de téléchargement.
- Préférence de l'utilisateur : réponses franches et objectives, corriger les erreurs
  sans complaisance.
