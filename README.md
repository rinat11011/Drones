# Drones Battle Royale

This is multi-drones single-target game, with a 100x100 game board, on which a group of N drones hunt the same target from different points of view and from different distances.

Each drone tries to detect where is the target on the game board, in order to destroy it. Drones may destroy the target only if the target is no more than some given distance from the drone. When the current target is destroyed, some new target appears on the game board in some randomly chosen place. Every R rounds one of the drones is "eliminated", the last drone left in the game is the winner of the game.

Each drone has a two-dimensional position on the game board: (coordinate x, coordinate y), and direction (angle from x-axis), in addition each drone has a current speed which is increased or decreased in each round. All the above state variables are represented by floating point numbers. 
Drones move according to their speed using their curret heading, from their current place. They then randomly change their speed and heading, before the next move. 
