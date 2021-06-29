#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define MAX_ENTITTIES 2048
#define WORLDSPAWN 0

float nextThinkTime[MAXPLAYERS+1];
float objectSprayTime[MAXPLAYERS+1];
float nextShovedTime[MAX_ENTITTIES+1];
float nextDmgTime[MAX_ENTITTIES+1];
float nextZedPaintTime[MAX_ENTITTIES+1];
float nextDrainTime[MAX_ENTITTIES+1];

int fuel[MAX_ENTITTIES+1];

Handle shoveZombieFn;  
int sprayDecal;
Handle hudSync;

bool lateloaded;

ConVar cvThinkInterval, cvObjectSprayInterval, cvShoveInterval, cvDmgInterval;
ConVar cvZedSprayInterval, cvDmgPerTick, cvSprayTexture, cvSprayRange, cvAlwaysFire;
ConVar cvCheapMode, cvFuel, cvDrainRate, cvDrainAmt;

public Plugin myinfo = 
{
	name        = "Fire Extinguisher Fun",
	author      = "Dysphie",
	description = "Extinguishers paint surfaces and damage zombies",
	version     = "0.1.0",
	url         = ""
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	lateloaded = late;
}

public void OnPluginStart()
{
	hudSync = CreateHudSynchronizer();

	cvFuel = CreateConVar("sm_spraypaint_fuel", "1000");
	cvDrainRate = CreateConVar("sm_spraypaint_fuel_drain_rate", "1");
	cvDrainAmt = CreateConVar("sm_spraypaint_fuel_drain_amt", "20");

	cvAlwaysFire = FindConVar("sv_extinguisher_always_fire");
	cvSprayRange = CreateConVar("sm_spraypaint_range", "200.0");
	cvThinkInterval = CreateConVar("sm_spraypaint_think_interval", "0.1");
	cvObjectSprayInterval = CreateConVar("sm_spraypaint_object_spray_interval", "0.1");
	cvZedSprayInterval = CreateConVar("sm_spraypaint_zombie_spray_update_time", "5.0");
	cvShoveInterval = CreateConVar("sm_spraypaint_stun_interval", "10.0");
	cvDmgInterval = CreateConVar("sm_spraypaint_dmg_interval", "1.0");
	cvDmgPerTick = CreateConVar("sm_spraypaint_dmg", "18");
	cvCheapMode = CreateConVar("sm_spraypaint_props_clientonly", "0");
	cvSprayTexture = CreateConVar("sm_spraypaint_spray_decal", "decals/decal_paintsplattergreen001_subrect");
	cvSprayTexture.AddChangeHook(ConVarChangedSprayTexture);

	GameData gamedata = new GameData("spraypaint.games");
	if (!gamedata)
		SetFailState("Failed to load QOL game data.");

	int offset = gamedata.GetOffset("CNMRiH_BaseZombie::GetShoved");
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetVirtual(offset);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	shoveZombieFn = EndPrepSDKCall();

	if (!shoveZombieFn)
		SetFailState("Failed to find offset for CNMRiH_BaseZombie::GetShoved");

	delete gamedata;

	if (lateloaded)
	{
		int e = -1;
		while ((e = FindEntityByClassname(e, "tool_extinguisher")) != -1)
			OnExtinguisherSpawned(e);
	}


	AutoExecConfig();
}

public void OnConfigsExecuted()
{
	cvAlwaysFire.BoolValue = true;
	cvAlwaysFire.AddChangeHook(ConVarChangedAlwaysFire);
}

public void ConVarChangedAlwaysFire(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cvAlwaysFire.BoolValue = true;
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

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weaponDontUseThis, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	float curTime = GetGameTime();
	if (curTime < nextThinkTime[client])
		return;

	nextThinkTime[client] = curTime + cvThinkInterval.FloatValue;
	
	int curWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (curWeapon == -1)
		return;

	char classname[20];
	GetEdictClassname(curWeapon, classname, sizeof(classname));
	if (!StrEqual(classname, "tool_extinguisher"))
		return;

	if (!GetEntProp(curWeapon, Prop_Send, "m_bHoseFiring"))
		return;

	if (buttons & IN_RELOAD)
		DisplayFuel(client, fuel[curWeapon]);

	if (cvDrainAmt.IntValue > 0)
	{
		if (fuel[curWeapon] <= 0)
			return;

		if (curTime >= nextDrainTime[curWeapon])
		{
			fuel[curWeapon] -= cvDrainAmt.IntValue;
			nextDrainTime[curWeapon] = curTime + cvDrainRate.FloatValue;
		}
	}

	float eyePos[3], eyeAng[3], endPos[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);

	TR_TraceRayFilter(eyePos, eyeAng, MASK_ALL, RayType_Infinite, TraceFilter_DontHitSelf, client);
	TR_GetEndPosition(endPos);

	if (GetVectorDistance(endPos, eyePos) > cvSprayRange.FloatValue)
		return;

	int target = TR_GetEntityIndex();
	if (!IsValidEdict(target))
		return;

	if (target == WORLDSPAWN && curTime >= objectSprayTime[client])
	{
		TE_Start("World Decal");
		TE_WriteVector("m_vecOrigin", endPos);
		TE_WriteNum("m_nIndex", sprayDecal);
		TE_SendToAll();

		objectSprayTime[client] = curTime + cvObjectSprayInterval.FloatValue;
	}
	else 
	{
		bool isNPC = IsZombie(target);
		if (isNPC)
		{
			OnZombieSprayed(target, client, curWeapon);

			if (curTime < nextZedPaintTime[target])
				return;
			nextZedPaintTime[target] = curTime + cvZedSprayInterval.FloatValue;
		}
		else 
		{
			if (curTime < objectSprayTime[client])
				return;
			objectSprayTime[client] = curTime + cvObjectSprayInterval.FloatValue;
		}

		TE_Start("Entity Decal");
		TE_WriteVector("m_vecOrigin", endPos);
		TE_WriteVector("m_vecStart", eyePos);
		TE_WriteNum("m_nEntity", target);
		TE_WriteNum("m_nHitbox", TR_GetHitGroup());
		TE_WriteNum("m_nIndex", sprayDecal);
		if (!isNPC && cvCheapMode.BoolValue)
			TE_SendToClient(client);
		else
			TE_SendToAll();
	}
}

void DisplayFuel(int client, int amount)
{
	SetHudTextParams(
		.x = 0.9,
		.y = 0.9,
		.holdTime = 0.7,
		.r = 0xFF,
		.g = 0xFF,
		.b = 0xFF,
		.a = 255);

	ShowSyncHudText(client, hudSync, "%d", amount);
}

void OnZombieSprayed(int zombie, int attacker, int weapon)
{
	float curTime = GetGameTime();

	if (curTime > nextDmgTime[zombie])
	{
		SDKHooks_TakeDamage(zombie, weapon, attacker, cvDmgPerTick.FloatValue);
		nextDmgTime[zombie] = curTime + cvDmgInterval.FloatValue;
	}

	if (curTime > nextShovedTime[zombie])
	{
		SDKCall(shoveZombieFn, zombie, attacker);
		nextShovedTime[zombie] = curTime + cvShoveInterval.FloatValue;
	}
}

bool IsZombie(int entity)
{
	return HasEntProp(entity, Prop_Send, "_headSplit");
}

public bool TraceFilter_DontHitSelf(int entity, int contentsmask, int client)
{
	return entity != client;
}

public void OnEntityDestroyed(int entity)
{
	if (0 < entity <= MAX_ENTITTIES)
	{
		nextZedPaintTime[entity] = 0.0;
		nextDmgTime[entity] = 0.0;
		nextShovedTime[entity] = 0.0;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "tool_extinguisher"))
		OnExtinguisherSpawned(entity);
}

void OnExtinguisherSpawned(int extinguisher)
{
	fuel[extinguisher] = cvFuel.IntValue;
}
