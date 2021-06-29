# [NMRiH] Extinguisher Fun
Supposed to be a joke, but people seemed to like it. 

Extinguishers can be used anywhere and are loaded with paint that stains surfaces and damages zombies.
Paint is finite by default, you can see how much you have left by performing an ammo check.

### ConVars

ConVars are saved to `cfg/sourcemod/plugin.extinguisher-fun.cfg`

- sm_spraypaint_fuel (Default: `1000`)
  - How much paint extinguishers spawn with
- sm_spraypaint_fuel_drain_rate (Default: `1`)
  - Rate in seconds at which the extinguisher depletes. Set to 0 or lower for infinite fuel.
- sm_spraypaint_fuel_drain_amt (Default: `20`)
  - How much paint is used each interval
- sm_spraypaint_range (Default: `200.0`)
  - Range of the hose
- sm_spraypaint_think_interval (Default: `0.1`)
  - How often the plugin logic is run, leave as-is unless you know what you're doing.
- sm_spraypaint_object_spray_interval (Default: `0.1`)
  - Rate at which paint decals are placed on the world and inanimate objects
- sm_spraypaint_zombie_spray_update_time (Default: `5.0`)
  - Rate at which paint decals are updated on zombies
- sm_spraypaint_stun_interval (Default: `10.0`)
  - Delay between zombies reacting to paint (by staggering)
- sm_spraypaint_dmg_interval (Default: `1.0`)
  - Damage interval of paint
- sm_spraypaint_dmg (Default: `18`)
  - Damage dealt by paint in each interval
- sm_spraypaint_props_clientonly (Default: `0`)
  - Sprays are kind of expensive. This makes sprays on props only visible to the client that placed them
- sm_spraypaint_spray_decal (Default: `decals/decal_paintsplattergreen001_subrect`)
  - Texture to use for the paint splatter. 
