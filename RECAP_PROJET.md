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
- Zone 5 (ciel) : escalier de nuages au nord du volcan → île de nuages (SKY_Y 32), COLOSSE DES NUÉES (sky_titan.gd,
  1 min pour le rejoindre), puis 4e sphère à sa place, 10 vagues après 2 min 30,
  anges squelettes volants, ressource NUAGE (murs ×3 pierre), nuage magique 1/50. Code : main.gd (_build_sky, spawn_cloud), cloud_res.gd.
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
- Arbre de compétences (page PERSONNAGE de l'inventaire) : 27 compétences, prérequis + jetons (1 / vague, 3 après le titan).
- Fusil de précision (création d'arme) ; défense sans fin après la 4e sphère (flux continu, niveaux croissants,
  chronomètre et record dans user://records.cfg).
- Éclair de Zeus (création d'arme à la sphère des nuages seulement ; ZEUS_* dans upgrades.gd).
- Interface : thème dans ui.gd (polices Lilita One / Nunito, boutons principal / « SecondaryButton », fonds flous),
  menu principal 3D dans menu.gd, images OpenArt dans assets/ui/ (logo.png, keyart.jpg, icônes).
- Armes en main : modèles Blender faits par script (`tools/blender/<arme>.py`, outils communs dans `common.py`),
  exportés en `assets/weapons/<arme>.glb` ; chargés par `_gun_from_model()` / `_attach_model()` dans player.gd
  (repères muzzle / sight / hand_r / hand_l lus dans le modèle ; cristal « sight_crystal » qui s'estompe en visée).
- Personnage : voyageur encapuchonné (OpenArt → Meshy : image vers 3D, squelette, animations Idle / Walking_A /
  Running_A / Jump_Idle / Death_A) ; assemblé par tools/blender/assemble_character.py → assets/characters/traveler.glb ;
  bras 1re personne : modèle Meshy dédié (2 vues) + squelette doigt par doigt par rig_fp_arm.py -> fp_arm.glb ;
  player.gd : _add_arm (placement paume / coude / normale de paume, bras gauche en miroir), set_grip (poses GRIPS). Clé API Meshy enregistrée dans l'environnement
  (hôte api.meshy.ai), fichiers sur assets.meshy.ai. Préférence : générer UNE seule version à la fois et demander l'avis.
- Menu principal : vidéo menu_loop.ogv (OpenArt Wan 2.7, 8 s en boucle, convertie en Ogg Theora avec ffmpeg) ;
  image fixe menu_art.jpg en secours (animée par code : yeux, sphère, brume, lucioles).
- Armes Meshy (en cours, une par une avec validation) : visuel OpenArt -> image-to-3d Meshy -> glow_weapon.py (émission)
  -> finalize_meshy_weapon.py (orientation, taille, repères). Fait : Éclair de Zeus (rayons de lumière : _add_light_rays).
- Sphères : socle Meshy (orb_altar.glb, prepare_orb.py), sphère animée turquoise (orb.gd, CORE_Y 1.78) ; les sphères
  volcan / nuages sont centrées sur une case (main.gd : orb_cell()).
- Armes et bras : matériaux Meshy rendus mats (player.gd : matte()) car trop brillants sur un vrai GPU ;
  bras avec coude (os « upper » orienté vers l'épaule chaque image : _update_arms()).
- Musique : fichiers à déposer dans `game/assets/music/` (mp3/ogg/wav) : menu, game, battle, volcano, volcano_battle,
  volcano_boss, sky, sky_battle, sky_boss, endless (+ boss en secours) ; main.gd : music_region(), music.gd : play_region / play_any.

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
  menu.gd              menu principal (illustration animée)
  skills.gd            arbre de compétences (données : effets, parents, prérequis) ; effets codés dans player.gd
  cloud_res.gd         petits nuages à récolter (couche 128 : traversables mais touchés par la hache)
  sky_titan.gd         colosse des nuées (variante du titan : grêle, éclairs, bourrasque, tempête < 30 %, anges)
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

### Retours de test (sphère, bras)
- Sphère : la boule est désormais celle du modèle Meshy (objet « ball » séparé du socle, texturé), qui flotte et tourne ; plus de noyau/coquille/anneaux lumineux, lumière ramenée à ~1,4.
- Bras FPS : épaules placées très bas (manchon hors champ), armes rapprochées de la caméra (fusils z −0,5, pistolet −0,34 ; crosse hors écran), paume posée contre la poignée (GRIP_HALF) et doigts moins serrés pour ne plus traverser la poignée, index tendu sur la gâchette.

### Interface et zone volcanique
- Messages d'information en bas de l'écran (au-dessus de la barre d'armes), plus au milieu de la vue.
- Barres de vie stylisées (scripts/hp_bar.gd, même dessin en 3D et dans l'interface) : bouts biseautés, liseré doré, reflet, graduations, traîne claire qui rattrape les dégâts. Utilisées pour les murs, le monstre visé, et la barre du haut (sphère en turquoise, titan de lave et colosse des nuées en orange).
- Barre de vie d'une construction : seulement quand on la vise (ou pendant sa réparation).
- Radar tournant : la flèche du joueur pointe toujours vers le haut, la carte tourne, le « N » suit le nord.
- Zone volcanique (scripts/volcanic.gd + tools/blender/volcanic_props.py) : rochers de basalte à facettes avec fissures de lave, volcans à cratère avec coulées sur les flancs et panache de fumée, arbres calcinés (charbon + braises), vraies coulées de lave animées (croûte qui dérive, bourrelets de roche) qui remplacent les mares (zone de dégâts suivant la coulée), braises plus nombreuses et cendres qui tombent, brouillard enfumé rouge au lieu du rose.
- Arbres à couper de la zone volcanique : arbres calcinés modélisés (tools/blender/charred_trees.py, 4 variantes : tronc crevassé, racines, branches mortes cassées, sans feuillage), aussi utilisés en décor.
- Rochers à miner de la zone volcanique : rochers magmatiques (formes de volcanic_props.py, veines de lave irrégulières, Volcanic.magma_material).
- Bras FPS, nouvelle piste : le voyageur exporté sans squelette pour Mixamo (game/tools/mixamo/traveler_for_mixamo.fbx, tools/blender/export_for_mixamo.py) ; le fichier riggé par Mixamo est attendu dans game/tools/mixamo/.
- Vie et bouclier du joueur : fioles verticales le long du bord gauche (HpBar.VIAL) : verre, bouchon doré, liquide qui ondule, s'agite quand la valeur change, bulles, traîne claire ; vie en rouge (clignote sous 25 %), bouclier en bleu (visible seulement s'il est débloqué). Le panneau en bas à gauche n'affiche plus que les vies.
- Zone volcanique d'après le visuel OpenArt (concept validé) : arbres calcinés et rochers magmatiques modélisés sur Meshy (tools/blender/finalize_volcanic.py : taille + émission des veines de lave), textures peintes OpenArt pour la lave (tex_lava, deux couches qui coulent), les berges et plaques flottantes (tex_crust) et le sol de cendre (tex_ash, deux échelles) ; textures rendues répétables par tools/seamless.py.
- Fioles de vie / bouclier illustrées (OpenArt, détourées par tools/key_vial.py : assets/ui/vial/vial_frame.png + vial_mask.png) ; le liquide (HpBar.VIAL_LIQUID) est dessiné dans l'intérieur du verre et entre en ébullition sous 55 % de vie (bulles, écume, vapeur, couleur qui chauffe), à fond sous 10 %.
- Bras FPS (actifs, USE_MIXAMO_ARMS dans player.gd) : voyageur régénéré en T-pose doigts écartés (Meshy), riggé par Mixamo avec 65 os (5 doigts séparés). tools/blender/extract_mixamo_arms.py garde les bras (poids limités aux os du bras) ; scripts/fp_arms.gd pose chaque main sur la poignée de l'arme visible par cinématique inverse à deux os (épaule hors champ, coude vers le bas), oriente la main (doigts, paume contre la poignée) et plie les doigts selon la prise. Calque de rendu par joueur (arms_layer) : les petites lumières des armes ne l'éclairent pas (gants verdâtres), l'autre joueur ne le voit pas. Animations Mixamo dans game/tools/mixamo (exclues de l'import Godot).
- Modèles blancs sur Mac : Mats.fix_glb_textures() rebranche explicitement les textures extraites des .glb (albedo, émission) et coupe l'émission si sa texture manque (sinon Godot met du blanc ×2-3 : modèle entièrement blanc). Appelé pour les armes, arbres/rochers volcaniques, socle de la sphère, coffres, avatar.
- Prises des mains (fp_arms.GRIPS) : écart paume-poignée par prise (« half »), index presque tendu sur la gâchette, main d'appui moins refermée pour ne pas traverser le garde-main.
- Modèles blancs sous Godot 4.7 (vraie cause, reproduite avec Godot 4.7.2) : libjpeg-turbo de Godot 4.7 refuse les JPEG écrits par Blender avec des balises de métadonnées (APP1 « NeoGeo », profil ICC, commentaires) ; les .glb se chargeaient sans texture et l'émission blanche ×3 rendait tout blanc. tools/clean_glb_jpeg.py retire ces balises (sans réencoder) dans les .glb et les .jpg extraits : à relancer après chaque export Blender.
- Bras FPS : direction des doigts explicite par main (main d'appui en travers sous le garde-main, poing de hache) au lieu de la déduire de l'avant-bras ; bras recalés juste avant le rendu (RenderingServer.frame_pre_draw), après recul/balancement/coup de hache : plus d'image de retard entre l'arme et les mains. Canon de Zeus agrandi (0,62 -> 0,85). Coup de hache moins ample (hache presque verticale, avant-bras horizontal), hache remontée de 9 cm.
