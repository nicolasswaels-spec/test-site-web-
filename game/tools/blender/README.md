# Modèles d'armes (Blender, par script)

Chaque arme est un script Python qui construit le modèle avec `bpy` (Blender en module Python,
`pip install bpy`, Python 3.11+). Outils communs : `common.py` (matériaux, profils extrudés,
pièces de révolution, découpes, éclairage d'aperçu, export).

```
python3 pistol.py <dossier_aperçus>                 # 3 rendus : _side, _34, _back
python3 pistol.py - ../../assets/weapons/pistol.glb  # export pour le jeu (sans rendu)
```

Conventions : mètres, X = avant de l'arme, Z = haut (la hache : manche selon Z, tranchant vers X).
Repères vides lus par le jeu : `muzzle` (bouche), `sight` (viseur), `hand_r` (poignée),
`hand_l` (main d'appui). Le maillage nommé `sight_crystal` devient translucide quand on vise.
Le bois procédural est « cuit » dans une texture à l'export (Godot ne lit pas les nœuds Blender).
