# Godot RPG

[Project: Requiem](https://docs.google.com/document/d/1ciNLXNb76iGfoPWgEIhHHFKyTaYyUXYv_RmkQ1yvwhU/edit?usp=sharing) - Work in progress RPG built in Godot 4 with GDScript

[Current design doc (TTRPG version)](https://btarg.github.io/requiem-vault/)

## Credits

- [Third Person Controller template by WaffleAWT](https://github.com/WaffleAWT/Godot-4.3-Third-Person-Controller)
- [Godot debug console plugin by Jitspoe](https://github.com/jitspoe/godot-console)
- [Mixamo Bone Map by catprisbrey](https://github.com/catprisbrey/Godot4-OpenAnimationLibraries/blob/main/BoneMaps/Mixamo%20BoneMap.tres)

## Unfinished Features / Todo List

- [x] Magic: Implement MP costs for spells
- [ ] Magic: Implement projectiles for spells
- [ ] Magic: Implement multi-target direct battle spells
- [ ] Magic: Implement Affinity Points or other system for levelling affinities
- [ ] Affinities: Implement [Mastery](https://btarg.github.io/requiem-vault/Players/Concepts/Mechanics/Magic/Mastery)
- [ ] Affinities: Implement [Scanning](https://btarg.github.io/requiem-vault/Players/Concepts/Mechanics/Elements-and-Affinities/Scanning)
- [ ] Levelling: Implement levelling up with shared XP pool and Hoard system
- [ ] Battle mechanics: Implement [Knockdown rolls](https://btarg.github.io/requiem-vault/Players/Concepts/Mechanics/Critical-Hits-and-Knockdowns)
- [ ] Battle mechanics: Implement [Saving Throws](https://btarg.github.io/requiem-vault/Players/Concepts/Mechanics/Saving-Throws)
- [ ] Battle mechanics: Implement [Status Effects](https://btarg.github.io/requiem-vault/Players/Concepts/Mechanics/Conditions)
- [ ] Battle mechanics: Implement Battle Zones: currently once we enter the "Battle State" we are in battle until it ends, but we should be able to leave the battle zone, and other characters outside the zone should be able to join the battle like in Baldur's Gate 3
- [ ] Battle mechanics: Implement Fleeing from battle

- [ ] AI: Implement Enemies reviving (they currently disappear when defeated, the win condition for a battle should be when all enemies are dead)

- [ ] AI: Implement Enemies being able to use AOE spells and multi-target spells effectively (choose multiple targets, avoid hitting allies)
