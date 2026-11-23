# Zone Zéro (Godot 4.3)

Jeu de survie en vagues à la première personne, style « battle royale cartoon » :
récolte du bois à la hache, construis des murs, sols et rampes, et défends la sphère
lumineuse contre 10 vagues de zombies.

## Lancer le jeu

1. Installer **Godot 4.3** (ou une version 4.x plus récente), version standard (pas .NET) : https://godotengine.org/download
2. Dans le gestionnaire de projets, faire **Importer** puis choisir `game/project.godot`.
3. Appuyer sur **F5** (ou le bouton ▶).

Les modèles de nature viennent du pack CC0 de Quaternius (voir Crédits) ; le reste est généré par le code.

## Commandes

Les touches sont **physiques** : ZQSD sur un clavier AZERTY, WASD sur un clavier QWERTY.

| Action | Touche |
|---|---|
| Se déplacer | ZQSD / WASD / flèches |
| Sauter / Sprinter | Espace / Maj |
| Tirer, couper, construire | Clic gauche |
| Viser (fusil) | Clic droit |
| Fusil / Hache / Construction | 1 / 2 / 3 (ou molette) |
| Changer de pièce (mur → sol → rampe) | F (ou F1 / F2 / F3) |
| Changer de matériau (bois / pierre) | V |
| Réparer la construction visée | G |
| Améliorer la construction visée (×3 PV) | T |
| Modifier la construction visée (porte, fenêtre, trappe, rampe retournée) | X |
| Escalader une construction | Avancer contre elle |
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
| Fusil ↔ hache | Y | Triangle |
| Mode construction (entrer / sortir) | B | Rond |
| En construction : mur / sol / rampe | RT / LT / RB | R2 / L2 / R1 |
| En construction : bois ↔ pierre | Y | Triangle |
| Réparer / améliorer la construction visée | Croix ↓ / ↑ | Croix ↓ / ↑ |
| Modifier la construction visée | Croix → | Croix → |
| Recharger / lancer le combat | X | Carré |
| Pause | Start | Options |

Dans les menus : croix directionnelle ou stick gauche pour se déplacer, A / Croix pour valider.

## Règles

- **Fusil d'assaut** : chargeur de 30 balles, munitions illimitées, rechargement en 1,6 s. Les tirs à la tête font double dégât (marqueur jaune).
- **Hache** : chaque coup sur un arbre donne +10 bois (+20 quand il tombe), sur un rocher +10 pierre (+20 quand il casse, à partir de la vague 5). Elle frappe aussi les ennemis.
- **Construction** : grille de 4 m comme dans Fortnite, 10 bois (ou 10 pierres) par pièce. La pierre se débloque à la vague 5 et a 2× plus de PV que le bois. Les PV s'affichent au-dessus de chaque pièce. On peut l'escalader en avançant contre elle, la modifier (mur → porte → fenêtre, sol → trappe, rampe retournée ; les portes laissent passer le joueur mais pas les squelettes), la démolir à la hache, réparer la pièce visée (coût proportionnel aux dégâts) et l'améliorer une fois pour 50 du même matériau (PV ×3, renforts en fer). Une pièce apparaît à 30 % de sa solidité et se renforce en 1,5 s. Fantôme bleu : placement possible, rouge : impossible.
- **Ennemis** (squelettes animés) : trois types. Les squelettes de base foncent sur la sphère et ne s'en prennent au joueur que de très près (6,5 m, moins encore loin de la sphère). Ceux à capuche traquent le joueur (13 m). Les boss ignorent le joueur et ne visent que la sphère. ils sortent de terre au bord de la zone (repérés par des colonnes rouges) et marchent vers la sphère. Si tu passes à moins de 13 m, ils te prennent en chasse. Une construction qui leur barre la route est frappée jusqu'à ce qu'elle casse.
- **Vagues** : 10 vagues de plus en plus nombreuses, rapides et résistantes. Un boss arrive à la vague 5, deux à la vague 10. Entre deux vagues, tu as 60 s (E pour passer), +50 bois, ta vie est restaurée et la sphère est réparée de 150 PV.
- **Mort** : tu réapparais près de la sphère après 5 s, avec 3 s d'invulnérabilité.
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
    input_setup.gd actions clavier/souris (autoload)
    mats.gd, ui.gd utilitaires
```

Pour équilibrer le jeu, les valeurs se trouvent en tête de `player.gd` (dégâts, coût des pièces),
dans `main.gd` (`_start_wave` et `_spawn_zombie` : nombre, PV et vitesse des zombies) et dans `orb.gd` (PV de la sphère).

## Crédits

- Modèles 3D de nature (sapins, herbe, plantes, buissons, rochers, arbres morts) et leurs textures :
  pack **Ultimate Stylized Nature** de [Quaternius](https://quaternius.com), licence **CC0** (domaine public).
  Fichiers dans `assets/nature/`, textures réduites à 1024 px, recolorées en code (`scripts/nature.gd`).
- Ennemis : squelettes animés du pack **KayKit Character Pack: Skeletons** de [Kay Lousberg](https://www.kaylousberg.com), licence **CC0**. Fichiers dans `assets/skeletons/`.
- Tout le reste (fusil, hache, sphère, constructions, sons, shaders) est généré par le code du jeu.
