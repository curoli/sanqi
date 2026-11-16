# Sanqi (三棋)

Sanqi (chinois 三棋, Sānqí, « trois échecs ») est un jeu de stratégie pour deux joueurs dans lequel la coordination des pièces joue un rôle central.

Les deux joueurs, les Blancs et les Noirs, jouent à tour de rôle. Les Blancs commencent.

Sanqi se joue sur un échiquier. Chaque joueur dispose de seize pièces, placées sur les deux rangées les plus proches de lui.

![Figure 1 : Position initiale](images/sanqi-start.svg "Figure 1 : Position initiale")

Un coup fait intervenir trois pièces : une pièce attaquante (celle qui se déplace) et deux pièces de soutien (qui ne se déplacent pas). Toute pièce peut jouer le rôle d’attaquante ou de soutien.

Les deux soutiens définissent un point de pivot situé exactement à mi-distance entre eux. Ce point peut se trouver au centre d’une case, au milieu du bord séparant deux cases, ou à un coin où quatre cases se rejoignent.

La pièce attaquante est déplacée de l’autre côté du pivot, de sorte que celui-ci se trouve exactement à mi-distance entre la case de départ et la case d’arrivée (figure 2). Ces deux cases doivent être différentes, même si la pièce attaquante se trouve initialement sur un point de pivot.

La distance parcourue n’est pas limitée, à condition que la pièce arrive à l’intérieur du plateau. Le déplacement ne doit pas nécessairement être parallèle aux bords ou aux diagonales du plateau ; de nombreuses directions sont possibles.

La case d’arrivée doit être vide ou occupée par une pièce adverse, qui est alors capturée et retirée du jeu.

![Figure 2 : Exemples de coups possibles](images/sanqi-moves.svg "Figure 2 : Exemples de coups possibles")

Un joueur perd s’il ne dispose d’aucun coup légal. Cela peut arriver, par exemple, s’il lui reste moins de trois pièces. Il peut aussi perdre parce que ses pièces se bloquent mutuellement et empêchent tout déplacement.

![Figure 3 : Exemple de position sans coup légal](images/sanqi-blocked.svg "Figure 3 : Exemple de position sans coup légal")
