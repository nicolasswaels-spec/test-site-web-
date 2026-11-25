# Zone Zéro (Godot 4.3)

Jeu de survie en vagues à la première personne, style « battle royale cartoon » :
récolte du bois à la hache, construis des murs, sols et rampes, et défends la sphère
lumineuse contre 10 vagues de zombies.

## Lancer le jeu

1. Installer **Godot 4.3** (ou une version 4.x plus récente), version standard (pas .NET) : https://godotengine.org/download
2. Dans le gestionnaire de projets, faire **Importer** puis choisir `game/project.godot`.
3. Appuyer sur **F5** (ou le bouton ▶).

Les modèles de nature viennent du pack CC0 de Quaternius (voir Crédits) ; le reste est généré par le code.

## Mode test

Bouton **MODE TEST** du menu : même partie, mais on commence avec toutes les armes (pistolet, fusil d'assaut, canon cryogénique ; on choisit les 2 équipées dans l'inventaire), des ressources illimitées (améliorations et constructions gratuites) et la pierre déjà débloquée.

## Jouer à deux (écran scindé)

- Depuis le menu : **JOUER À DEUX** (avec 2 manettes : une par joueur ; avec 1 manette : clavier/souris pour le joueur 1, manette pour le joueur 2).
- En cours de partie : le joueur 2 appuie sur **Start** d'une manette libre, ou sur **Entrée** du clavier si le joueur 1 joue à la manette.
- Chacun a sa vue, son interface, sa mini-carte, ses ressources, ses armes et ses améliorations. Les squelettes visent le joueur le plus proche.
- À deux, l'inventaire ne met pas le jeu en pause ; seul le joueur qui l'a ouvert le pilote. La pause (Start / Échap) met tout le monde en pause, et seul celui qui l'a déclenchée peut reprendre.
- **Déposer des ressources** : dans l'inventaire (page Résumé), choisir la quantité (10, 50, 100, 500 ou tout) puis DÉPOSER. Un paquet apparaît au sol devant soi ; n'importe quel joueur le ramasse en marchant dessus. Les armes ne se déposent pas.

## Commandes

Les touches sont **physiques** : ZQSD sur un clavier AZERTY, WASD sur un clavier QWERTY.

| Action | Touche |
|---|---|
| Se déplacer | ZQSD / WASD / flèches |
| Sauter / Sprinter | Espace / Maj |
| Tirer, couper, construire | Clic gauche |
| Viser (fusil) | Clic droit |
| Arme 1 / Arme 2 / Hache / Construction | 1 / 2 / 3 / 4 (ou molette) |
| Inventaire | I ou Tab |
| Changer de pièce (mur → sol → rampe) | F (ou F1 / F2 / F3) |
| Changer de matériau (bois / pierre) | V |
| Réparer la construction visée | G |
| Améliorer la construction visée | T |
| Modifier la construction visée (porte, fenêtre, trappe, rampe retournée) | X |
| Escalader une construction | Avancer contre elle |
| Poser des barbelés sur le sol visé (2 pièces) | B |
| Recharger | R |
| Lancer le combat (près de la sphère) | E |
| Pause | Échap |

### Manette (Xbox / PlayStation)

| Action | Xbox | PlayStation |
|---|---|---|
| Se déplacer / viser | Stick gauche / stick droit | Stick gauche / stick droit |
| Sprinter | Clic stick gauche | L3 |
| Sauter | A | Croix |
| Tirer, couper, construire | RT | R2 |
| Viser (fusil) | LT | L2 |
| Changer d'arme | LB / RB | L1 / R1 |
| Arme 1 → arme 2 → hache | Y | Triangle |
| Mode construction (entrer / sortir) | B | Rond |
| En construction : mur / sol / rampe | RT / LT / RB | R2 / L2 / R1 |
| En construction : bois ↔ pierre | Y | Triangle |
| Réparer / améliorer la construction visée | Croix ↓ / ↑ | Croix ↓ / ↑ |
| Modifier la construction visée | Croix → | Croix → |
| Poser des barbelés sur le sol visé | Clic stick droit | R3 |
| Recharger / lancer le combat | X | Carré |
| Pause | Start | Options |
| Inventaire (pages : LB / RB) | Vue (Select) | Share / Create |

Dans les menus : croix directionnelle ou stick gauche pour se déplacer, A / Croix pour valider.

## Règles

- **Inventaire** (Select / I / Tab) : page **Résumé** (ressources, armes possédées, choix des 2 armes équipées ; la hache est toujours équipée) et page **Améliorations** (LB / RB pour changer de page).
- **Améliorations** : pistolet et fusil (cadence, dégâts par balle, chargeur, vitesse de rechargement, défense quand l'arme est en main), hache (récolte de bois payée en bois, récolte de pierre payée en pierre), barbelés (ralentissement : 80 % de vitesse → 60 % au niveau 8, dégâts), canon cryogénique s'il est obtenu (à 10 statuts : ralentissement 30 % → 40 %, vulnérabilité +10 % → +40 % ; dégâts 70 → 200 / s ; durée d'un statut 1 s → 3 s, soit ~30 s pour perdre 10 statuts ; coûts élevés dès le niveau 1 : de 800 bois + 400 pierre + 10 pièces à 5200 bois + 3600 pierre + 60 pièces). 8 niveaux par branche, chaque niveau exige le précédent. Coûts : niveaux 1-2 en bois, 3-4 en pierre, 5-6 bois + pierre, 7-8 bois + pierre + pièces (valeurs dans `scripts/upgrades.gd`).
- **Armes** : on commence avec un **pistolet** (12 balles, coup par coup). Le **fusil d'assaut** (30 balles, automatique) se fabrique à la fin de la 1re sphère (proposé à l'écran, ou depuis l'inventaire). Munitions illimitées, tirs à la tête ×2. Viser un ennemi affiche sa barre de vie.
- **Hache** : un arbre tombe en ~8 coups ; chaque coup donne +15 bois et le dernier +40. Sur un rocher (à partir de la vague 5) : +10 pierre par coup et +30 au dernier. Au 1er coup, **3 cibles turquoise** apparaissent en même temps sur l'arbre ou le rocher (toujours visibles, posées sur la surface). Toucher une cible donne +50 % de ressources sur ce coup et la fait disparaître. Quand la ressource est terminée, le gain final prend **+60 % par cible touchée** (3 cibles = +180 %, soit ×2,8). La hache frappe toutes les 0,9 s : mieux vaut viser les cibles que taper vite. La hache frappe aussi les ennemis.
- **Construction** : grille de 4 m comme dans Fortnite, 10 bois (ou 10 pierres) par pièce. La pierre se débloque à la vague 5 et a 2× plus de PV que le bois. Les PV s'affichent au-dessus de chaque pièce. On peut l'escalader en avançant contre elle, la modifier (mur → porte → fenêtre, sol → trappe, rampe retournée ; les portes laissent passer le joueur mais pas les squelettes), la démolir à la hache, réparer la pièce visée (coût proportionnel aux dégâts) et l'améliorer jusqu'à 3 fois avec le même matériau : niveau 1 = PV ×3 (50), niveau 2 = PV ×2 (150), niveau 3 = PV ×4 (1000, avec confirmation). La réparation prend 5 s (symbole au-dessus de la pièce) et ne rend que les PV qui manquaient au début. Une pièce apparaît à 30 % de sa solidité et se renforce en 1,5 s. Fantôme bleu : placement possible, rouge : impossible.
- **Ennemis** (squelettes animés) : ils passent de préférence par le côté le moins barricadé (sans en faire une règle absolue). Trois types. Les squelettes de base foncent sur la sphère et ne s'en prennent au joueur que de très près (6,5 m, moins encore loin de la sphère). Ceux à capuche traquent le joueur (13 m). Les boss ignorent le joueur et ne visent que la sphère ; ils sont insensibles aux barbelés et font 2× plus de dégâts aux constructions. Les squelettes normaux font moitié moins de dégâts au joueur et aux constructions. ils sortent de terre au bord de la zone (repérés par des colonnes rouges) et marchent vers la sphère. Si tu passes à moins de 13 m, ils te prennent en chasse. Une construction qui leur barre la route est frappée jusqu'à ce qu'elle casse.
- **Début de partie** (mode classique) : 1 min 30 de préparation, puis la 1re vague se lance toute seule. On peut la lancer plus tôt avec E / X près de la sphère.
- **Vagues** : 10 vagues de plus en plus nombreuses, rapides et résistantes. Un boss arrive à la vague 5, deux à la vague 10. Entre deux vagues, tu as 60 s (E / X pour passer). Lancer une vague en avance reporte **50 %** du temps restant sur la pause suivante. Après chaque vague : +50 bois, ta vie est restaurée et la sphère est réparée de 150 PV.
- **Après la 10ᵉ vague**, la partie continue : la forêt s'ouvre au nord par un couloir vers un **nouveau biome** (érables pourpres, bouleaux dorés, sol mauve) où se trouve une **2ᵉ sphère** (colonne de lumière). On y construit, ses 10 vagues démarrent seules au bout de **2 min** (ou plus tôt avec E / X, ce qui reporte 50 % du temps restant sur la pause suivante ; le temps reporté d'une vague 10 lancée en avance s'ajoute aussi à ces 2 min). Les squelettes n'attaquent plus que cette sphère. Sa vague 1 est aussi dure que la vague 8 de la 1re sphère, et la difficulté continue de monter.
- **Coffres** : 2 dans chaque zone (modèles KayKit), gardés par 5 à 8 squelettes immobiles qui se réveillent quand on approche ; dès qu'on touche l'un d'eux, tout le groupe charge à vitesse maximale. On les ouvre avec E / X. Butin : commun (60 %) 100-300 bois ; rare (30 %) 300-500 bois, ou 100-300 pierre, ou 200-300 bois + 50-150 pierre ; légendaire (10 %) 1500-2500 bois, ou 1000-1800 pierre, ou 30-50 pièces, ou 1000 bois + 1000 pierre + 20 pièces, ou (4 %) le **canon cryogénique** : rayon de glace continu (70 dégâts/s) qui pose des **statuts de glace** sur la cible, de 1 à 10 (~1,5 s de rayon pour atteindre 10). Le ralentissement s'applique aussi aux boss et se multiplie avec celui des barbelés ; la vulnérabilité s'applique à tous les dégâts, y compris ceux du rayon. Ralentissement et vulnérabilité sont proportionnels au nombre de statuts : à 10, la cible avance à 70 % de sa vitesse et subit +10 % de dégâts. Elle perd un statut toutes les secondes.
- **Pièces** : petites pièces métalliques (engrenages, boulons) éparpillées dans les deux zones ; on les ramasse en passant dessus, elles réapparaissent ailleurs. 2 pièces = des **barbelés** à poser sur un sol plein : les squelettes qui les traversent avancent à 80 % de leur vitesse et perdent 6 PV/s.
- **Mort et vies** : chaque joueur a **5 vies**. Mort avec au moins une vie : appuie sur **E / X** pour revenir instantanément à l'endroit de ta mort (−1 vie), les squelettes proches sont repoussés et tu es invulnérable 5 s. Sans vie : attente de 5 s, puis réapparition à ~25 m de la sphère (3 s d'invulnérabilité) ; chaque nouvelle mort sans vie ajoute 2 s d'attente (5, 7, 9 s…). Les vies restantes s'affichent à côté des PV.
- **Musique** : place tes morceaux dans `game/assets/music/` sous les noms `menu`, `game` (exploration / préparation / pauses) et `battle` (vagues), en `.mp3`, `.ogg` ou `.wav` (ex. `battle.mp3`). Ils bouclent et s'enchaînent en fondu ; un fichier absent = silence. Volume : `VOLUME_DB` dans `scripts/music.gd`.
- **Défaite** si la sphère est détruite. **Victoire** après la 10ᵉ vague.

## Structure

```
game/
  project.godot
  scenes/menu.tscn, main.tscn   (scènes minimales, tout est construit par script)
  scripts/
    menu.gd        menu principal
    main.gd        monde, décor, gestion des vagues
    player.gd      joueur, armes, construction
    zombie.gd      IA et modèle des zombies
    tree.gd        arbres coupables
    orb.gd         sphère à défendre
    structure.gd   murs / sols / rampes
    hud.gd         interface, pause, écran de fin
    sfx.gd         sons générés (autoload)
    music.gd       musique de fond, fondus (autoload)
    input_setup.gd actions clavier/souris (autoload)
    mats.gd, ui.gd utilitaires
```

Pour équilibrer le jeu, les valeurs se trouvent en tête de `player.gd` (dégâts, coût des pièces),
dans `main.gd` (`_start_wave` et `_spawn_zombie` : nombre, PV et vitesse des zombies) et dans `orb.gd` (PV de la sphère).

## Crédits

- Modèles 3D de nature (sapins, herbe, plantes, buissons, rochers, arbres morts) et leurs textures :
  pack **Ultimate Stylized Nature** de [Quaternius](https://quaternius.com), licence **CC0** (domaine public).
  Fichiers dans `assets/nature/`, textures réduites à 1024 px, recolorées en code (`scripts/nature.gd`).
- Coffres : pack **KayKit Dungeon Remastered** de Kay Lousberg, licence **CC0** (`assets/chests/`).
- Personnages des joueurs : pack **KayKit Character Pack: Adventurers** de Kay Lousberg, licence **CC0** (`assets/characters/`).
- Ennemis : squelettes animés du pack **KayKit Character Pack: Skeletons** de [Kay Lousberg](https://www.kaylousberg.com), licence **CC0**. Fichiers dans `assets/skeletons/`.
- Tout le reste (fusil, hache, sphère, constructions, sons, shaders) est généré par le code du jeu.
