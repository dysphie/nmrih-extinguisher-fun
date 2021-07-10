# [NMRiH] Extinguisher Fun
Supposed to be a joke, but people seemed to like it. 

Extinguishers can be used anywhere and are loaded with paint that stains surfaces and damages zombies.

![image](https://user-images.githubusercontent.com/11559683/123833008-4fe8e580-d8dc-11eb-8dbe-1619c1e640fc.png)


### ConVars

ConVars are saved to `cfg/sourcemod/plugin.extinguisher-fun.cfg`

- sm_spraypaint_range (Default: `200.0`)
  - Range of the hose

- sm_spraypaint_world_decal_interval (Default: `0.3`)
  - Global rate at which decals can be placed on brushes, in seconds
  
- sm_spraypaint_entity_decal_interval (Default: `0.3`)
  - Global rate at which decals can be placed on entities, in seconds
 
- sm_spraypaint_entity_repaint_interval (Default: `2.0`)
  - How often a painted entity will recompute its decal position, in seconds

- sm_spraypaint_hurts_humans (Default: `1`)
  - Whether paint hurts humans (abides by `mp_friendlyfire` and infection rules)
   
- sm_spraypaint_hurts_zombies (Default: `1`)
  - Wether paint hurts zombies

- sm_spraypaint_stuns_zombies (Default: `1`)
  - Wether paint causes zombies to stagger

- sm_spraypaint_stun_interval (Default: `10`)
  - How often a zombie will stagger, in seconds 

- sm_spraypaint_spray_decal (Default: `decals/decal_paintsplatterblue001`)
  - Texture to use for the paint splatter. 

- sm_spraypaint_dmg_interval (Default: `1.0`)
  - How often paint deals damage, in seconds

- sm_spraypaint_zombie_dmg_per_tick (Default: `30`)
  - Damage dealt to zombies per interval

- sm_spraypaint_human_dmg_per_tick (Default: `5`)
  - Damage dealt to humans per interval. Note: This is scaled by `sv_friendly_fire_factor`

- sm_spraypaint_think_interval (Default: `0.1`)
  - How often the plugin logic is run, leave as-is unless you know what you're doing.

### Configuration file

ConVars are saved to `cfg/sourcemod/plugin.extinguisher-fun.cfg`
