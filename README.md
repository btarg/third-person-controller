# Godot RPG
[Project: Requiem](https://docs.google.com/document/d/1ciNLXNb76iGfoPWgEIhHHFKyTaYyUXYv_RmkQ1yvwhU/edit?usp=sharing) - Work in progress RPG built in Godot 4 with GDScript

# Credits
- [Third Person Controller template by WaffleAWT](https://github.com/WaffleAWT/Godot-4.3-Third-Person-Controller)
- [Godot debug console plugin by Jitspoe](https://github.com/jitspoe/godot-console)
- [Mixamo Bone Map by catprisbrey](https://github.com/catprisbrey/Godot4-OpenAnimationLibraries/blob/main/BoneMaps/Mixamo%20BoneMap.tres)

# TODO
- Battle basics
    - [x] Multiple player characters
    - [ ] Special skills and MP usage
    
    - [ ] Money and XP
    - [ ] Level up system
    - [ ] Enemies drop items
- Junction system
    - [x] Players can junction items
    - [x] Items can affect stats
- Movement
    - [x] In-battle player movement state
    - [x] Movement in metres as a stat (speed)
    - [x] Pathfinding for players
    - [ ] Pathfinding for enemies
    - [ ] Stuck detection
- Spells and items
    - [x] Spells, attacks etc. can have a radius for targets (range)
        - [ ] Draw the radius visually around the player
- UI/UX
    - [ ] Victory screen / game over screen
    - [ ] Pause menu with options to save, load, quit, etc.
    - [ ] health bars for each player character
    - [ ] UI for choosing spells
    - [ ] UI for choosing what to draw
        - [ ] UI for choosing whether to stock or cast a draw
    - [ ] UI for choosing junctioned items
    - [ ] UI for inventory: able to use items out of combat (e.g. healing potions/spells)
    - [ ] Damage numbers and other hit feedback
- Visuals
    - [ ] Animated characters
- AI
    - [ ] Look into beehaviour
    - [ ] Enemies seek the player and attack
        - [ ] Enemies choose how we enter battle: either by attacking the player or by being attacked by the player
    - [ ] Enemies can attack in battle
        - [ ] Enemies can use spells