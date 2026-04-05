# Sanqi (三棋)

Sanqi (chino 三棋, Sānqí, “Tres Ajedrez” o “Ajedrez triple”) es un juego de estrategia para dos jugadores en el que la coordinación entre las piezas desempeña un papel central.

Los dos jugadores, Blanco y Negro, se turnan para mover. Blanco comienza.

Sanqi se juega sobre un tablero de ajedrez. Cada jugador tiene dieciséis piezas, que ocupan las dos filas más cercanas a dicho jugador.

![Figura 1: Posición inicial](images/sanqi-start.svg "Figura 1: Posición inicial")

Un movimiento requiere tres piezas: una pieza atacante (la que se mueve) y dos piezas de apoyo (que no se mueven). Cualquier pieza puede desempeñar el papel de atacante o de apoyo.

Las dos piezas de apoyo determinan un punto de pivote, que es el punto situado exactamente a mitad de camino entre ellas. El punto de pivote puede encontrarse en el centro de una casilla, en el punto medio del lado entre dos casillas o en una esquina donde se encuentran cuatro casillas.

La pieza atacante se mueve a través del punto de pivote hasta el lado opuesto, de manera que el punto de pivote queda exactamente en el centro entre la casilla de origen y la casilla de destino (véase la Figura 2). La casilla de origen y la de destino no pueden ser la misma, incluso si la pieza atacante se encuentra inicialmente sobre un punto de pivote.

No hay restricción en la distancia que puede recorrer la pieza atacante, salvo que debe permanecer dentro del tablero. La dirección del movimiento no tiene que ser paralela a los bordes ni a las diagonales del tablero; son posibles muchas direcciones.

La casilla de destino debe estar vacía o ocupada por una pieza del oponente; en este último caso, dicha pieza es capturada y retirada del juego.

![Figura 2: Ejemplos de movimientos posibles](images/sanqi-moves.svg "Figura 2: Ejemplos de movimientos posibles")

Un jugador pierde si no tiene ningún movimiento legal. Esto puede ocurrir, por ejemplo, si le quedan menos de tres piezas. También puede suceder que un jugador pierda porque sus propias piezas se bloquean entre sí, de modo que no es posible realizar ningún movimiento.

![Figura 3: Ejemplo de una posición sin movimientos posibles](images/sanqi-blocked.svg "Figura 3: Ejemplo de una posición sin movimientos posibles")