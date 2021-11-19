#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define MAX_ENTITIES 2048
#define MAX_SURVIVORS 9

float nextBspDecalTime;
float nextEntDecalTime;

float nextStaggerTime[MAX_ENTITIES+1] = {-1.0, ...};
float nextDmgTime[MAX_ENTITIES+1] = {-1.0, ...};
float nextThinkTime[MAX_SURVIVORS+1] = {-1.0, ...};
float nextEntRepaintTime[MAX_ENTITIES+1] = {-1.0, ...};

public Plugin myinfo = 
{
	name = "Fire Extinguisher Fun",
	author = "Dysphie",
	description = "Extinguishers paint surfaces and damage zombies",
	version = "0.2.3",
	url = ""
};

int sprayDecal;

ConVar cvFF;
ConVar cvAlwaysFire;
ConVar cvSprayRange;
ConVar cvThinkRate;
ConVar cvEntDecalRate;
ConVar cvBspDecalRate;
ConVar cvDmgPlayers;
ConVar cvDmgZombies;
ConVar cvShoveZombies;
ConVar cvShoveZombiesRate;
ConVar cvDmgRate;
ConVar cvHumanDmgPerTick;
ConVar cvZombieDmgPerTick;
ConVar cvSprayTexture;
ConVar cvEntRepaintRate;
ConVar cvPaintPlayers;

Handle fnShoveZombie;

bool originalAlwaysFire;

public void OnPluginStart()
{
	PrepSDKCalls();

	cvFF = FindConVar("mp_friendlyfire");
	cvAlwaysFire = FindConVar("sv_extinguisher_always_fire");
	cvSprayRange = CreateConVar("sm_spraypaint_range", "200.0");
	cvThinkRate = CreateConVar("sm_spraypaint_think_interval", "0.1");

	cvBspDecalRate = CreateConVar("sm_spraypaint_world_decal_interval", "0.3");
	cvEntDecalRate = CreateConVar("sm_spraypaint_entity_decal_interval", "0.3");
	cvEntRepaintRate = CreateConVar("sm_spraypaint_entity_repaint_interval", "3.0");

	cvPaintPlayers = CreateConVar("sm_spraypaint_paints_humans", "1");

	cvDmgPlayers = CreateConVar("sm_spraypaint_hurts_humans", "1");
	cvDmgZombies = CreateConVar("sm_spraypaint_hurts_zombies", "1");

	cvShoveZombies = CreateConVar("sm_spraypaint_stuns_zombies", "1");
	cvShoveZombiesRate = CreateConVar("sm_spraypaint_stun_interval", "10.0");

	cvDmgRate = CreateConVar("sm_spraypaint_dmg_interval", "1.0");

	cvZombieDmgPerTick = CreateConVar("sm_spraypaint_zombie_dmg_per_tick", "30");
	cvHumanDmgPerTick = CreateConVar("sm_spraypaint_human_dmg_per_tick", "5");

	cvSprayTexture = CreateConVar("sm_spraypaint_spray_decal", "decals/decal_paintsplatterblue001");

	cvAlwaysFire.AddChangeHook(OnCvAlwaysFireChanged);
	cvSprayTexture.AddChangeHook(ConVarChangedSprayTexture);

	AutoExecConfig();
}

public void OnConfigsExecuted()
{
	originalAlwaysFire = cvAlwaysFire.BoolValue;
	cvAlwaysFire.BoolValue = true;
}

public void OnCvAlwaysFireChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cvAlwaysFire.BoolValue = true;
}

public void OnPluginEnd()
{
	cvAlwaysFire.RemoveChangeHook(OnCvAlwaysFireChanged);
	cvAlwaysFire.BoolValue = originalAlwaysFire;
}

public void ConVarChangedSprayTexture(ConVar convar, const char[] oldValue, const char[] newValue)
{
	sprayDecal = PrecacheDecal(newValue);
}

public void OnMapStart()
{
	char decal[PLATFORM_MAX_PATH];
	cvSprayTexture.GetString(decal, sizeof(decal));
	sprayDecal = PrecacheDecal(decal);
}

void PrepSDKCalls()
{
	GameData gamedata = new GameData("spraypaint.games");
	if (!gamedata)
		SetFailState("Failed to load QOL game data.");

	int offset = gamedata.GetOffset("CNMRiH_BaseZombie::GetShoved");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(offset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	fnShoveZombie = EndPrepSDKCall();

	if (!fnShoveZombie)
		SetFailState("Failed to find offset for CNMRiH_BaseZombie::GetShoved");

	delete gamedata;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weaponDontUseThis, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	float curTime = GetTickedTime();
	if (curTime < nextThinkTime[client])
		return;

	nextThinkTime[client] = curTime + cvThinkRate.FloatValue;
	
	int curWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (curWeapon == -1 || 
		!HasEntProp(curWeapon, Prop_Send, "m_bHoseFiring") || 
		!GetEntProp(curWeapon, Prop_Send, "m_bHoseFiring"))
		return;

	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);

	TR_TraceRayFilter(eyePos, eyeAng, MASK_ALL, RayType_Infinite, TraceFilter_DontHitSelf, client);
	TR_GetEndPosition(endPos);

	if (GetVectorDistance(endPos, eyePos) > cvSprayRange.FloatValue)
		return;

	int target = TR_GetEntityIndex();
	if (target == -1)
		return;

	if (target == 0)
	{
		TryWorldSplat(endPos);
	}
	else 
	{
		TryEntitySplat(endPos, eyePos, target, TR_GetHitBoxIndex());

		if (IsEntityPlayer(target))
		{
			OnPlayerSprayed(target, client, curWeapon);
		}
		else if (IsEntityZombie(target))
		{
			OnZombieSprayed(target, client, curWeapon);
		}
	}
}

void TryEntitySplat(float endPos[3], float startPos[3], int target, int hitbox)
{
	if (0 < target <= MaxClients && !cvPaintPlayers.BoolValue)
		return;

	float curTime = GetTickedTime();

	// Check global decal limit
	if (curTime < nextEntDecalTime)
		return;
	nextEntDecalTime = curTime + cvEntDecalRate.FloatValue;

	// Check individual decal limit
	if (curTime < nextEntRepaintTime[target])
		return;
	nextEntRepaintTime[target] = curTime + cvEntRepaintRate.FloatValue;

	TE_Start("Entity Decal");
	TE_WriteVector("m_vecOrigin", endPos);
	TE_WriteVector("m_vecStart", startPos);
	TE_WriteNum("m_nEntity", target);
	TE_WriteNum("m_nHitbox", hitbox);
	TE_WriteNum("m_nIndex", sprayDecal);
	TE_SendToAll();
}

void TryWorldSplat(float endPos[3])
{
	float curTime = GetTickedTime();
	if (curTime < nextBspDecalTime)
		return;

	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", endPos);
	TE_WriteNum("m_nIndex", sprayDecal);
	TE_SendToAll();
	nextBspDecalTime = curTime + cvBspDecalRate.FloatValue;
}

void OnPlayerSprayed(int client, int attacker, int weapon)
{
	float curTime = GetTickedTime();
	if (curTime < nextDmgTime[client])
		return;

	if (cvDmgPlayers.BoolValue && (cvFF.BoolValue || IsClientInfected(client)))
	{
		// FIXME: Doesn't actually play drowning sounds
		SDKHooks_TakeDamage(client, weapon, attacker, cvHumanDmgPerTick.FloatValue, DMG_DROWN);
		nextDmgTime[client] = curTime + cvDmgRate.FloatValue;
	}
}

void OnZombieSprayed(int zombie, int attacker, int weapon)
{
	float curTime = GetTickedTime();

	if (cvDmgZombies.BoolValue)
	{	
		if (curTime >= nextDmgTime[zombie])
		{
			SDKHooks_TakeDamage(zombie, weapon, attacker, cvZombieDmgPerTick.FloatValue, DMG_POISON);
			nextDmgTime[zombie] = curTime + cvDmgRate.FloatValue;
		}
	}

	if (cvShoveZombies.BoolValue)
	{	
		if (curTime >= nextStaggerTime[zombie])
		{
			SDKCall(fnShoveZombie, zombie, attacker);
			nextStaggerTime[zombie] = curTime + cvShoveZombiesRate.FloatValue;
		}
	}
}

bool IsEntityZombie(int entity)
{
	return HasEntProp(entity, Prop_Send, "_headSplit");
}

bool IsEntityPlayer(int entity)
{
	return 0 < entity <= MaxClients;
}

public bool TraceFilter_DontHitSelf(int entity, int contentsmask, int client)
{
	return entity != client;
}

bool IsClientInfected(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flInfectionTime") != -1.0;
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEdict(entity))
	{
		nextStaggerTime[entity] = -1.0;
		nextEntRepaintTime[entity] = -1.0;
		nextDmgTime[entity] = -1.0;
	}
}
