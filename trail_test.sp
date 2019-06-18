#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks> 
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "Trail Test",
	author = "JugadorXEI",
	description = "none",
	version = PLUGIN_VERSION,
	url =  "",
}

int iClient;
float fOrigin[3];

float fDefaultTrailLife;

public void OnPluginStart()
{
	HookEvent("player_spawn", TrailTest);
	HookEvent("post_inventory_application", TrailTest);
	HookEvent("player_death", TrailDetach);

	// Here we precache trails
	PrecacheModel("trails/cartoon.vmt");
	PrecacheModel("trails/concentrated.vmt");
	PrecacheModel("trails/nofocus.vmt");
}

public Action TrailTest(Handle hEvent, const char[] name, bool dontBroadcast)
{
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	TFTeam iTeam = TF2_GetClientTeam(iClient);
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	if(IsValidClient(iClient) && GetClientTeam(iClient) >= 2 && IsPlayerAlive(iClient))
	{
		DetachTrail(iClient);
		
		char iTrail[255];

		if(iTeam == TFTeam_Red)
		{
			if(iClass == TFClass_Soldier)
			{
				Format(iTrail, sizeof(iTrail), "trails/cartoon.vmt");
				AttachTrail(iClient, iTrail, 0.5, 20.0, 0.0, "255 255 0");
			}

			if(iClass == TFClass_Pyro)
			{
				Format(iTrail, sizeof(iTrail), "trails/concentrated.vmt");
				AttachTrail(iClient, iTrail, 0.5, 30.0, 10.0, "255 255 0"); // 189 59 59
			}
			
			if(iClass == TFClass_Heavy)
			{
				Format(iTrail, sizeof(iTrail), "trails/nofocus.vmt");
				AttachTrail(iClient, iTrail, 0.5, 20.0, 10.0, "255 255 0");
			}
		}
		if(iTeam == TFTeam_Blue)
		{
			if(iClass == TFClass_Soldier)
			{
				Format(iTrail, sizeof(iTrail), "trails/cartoon.vmt");
				AttachTrail(iClient, iTrail, 0.5, 20.0, 0.0, "91 122 140");
			}
			
			if(iClass == TFClass_Pyro)
			{
				Format(iTrail, sizeof(iTrail), "trails/concentrated.vmt");
				AttachTrail(iClient, iTrail, 0.5, 30.0, 10.0, "91 122 140");
			}
			
			if(iClass == TFClass_Heavy)
			{
				Format(iTrail, sizeof(iTrail), "trails/nofocus.vmt");
				AttachTrail(iClient, iTrail, 0.5, 20.0, 10.0, "91 122 140");
			}
		}
	}
}

public Action TrailDetach(Handle hEvent, const char[] name, bool dontBroadcast)
{
	iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	DetachTrail(iClient);
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if(IsValidClient(iClient) && GetClientTeam(iClient) >= 2 && IsPlayerAlive(iClient))
	{
		if(condition == TFCond_Disguised || condition == TFCond_Cloaked
		|| condition == TFCond_Disguising && DoesClientHaveTrail(client) == true)
		{
			SetTrailLifeTime(iClient, 0.0);
		}
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if(IsValidClient(iClient) && GetClientTeam(iClient) >= 2 && IsPlayerAlive(iClient))
	{
		if(condition == TFCond_Disguised || condition == TFCond_Cloaked
		|| condition == TFCond_Disguising && DoesClientHaveTrail(client) == true)
		{
			SetTrailLifeTime(iClient, fDefaultTrailLife);
		}
	}
}

// This stock is used to attach trails to other players.
stock void AttachTrail(int client, const char[] trail, float lifeTime,
float startWidth, float endWidth, const char[] color = "255 255 255", const char[] alpha = "255",
const char[] renderMode = "5", int verticalOffset = 10)
{
	// This creates the trail entity we will use
	int TrailIndex = CreateEntityByName("env_spritetrail");
	
	if (TrailIndex > 0 && IsValidEntity(TrailIndex))
	{
		// Here we dispatch the values
		DispatchKeyValue(TrailIndex, "spritename", trail);
		DispatchKeyValueFloat(TrailIndex, "lifetime", lifeTime);
		DispatchKeyValueFloat(TrailIndex, "startwidth", startWidth);		
		DispatchKeyValueFloat(TrailIndex, "endwidth", endWidth);
		DispatchKeyValue(TrailIndex, "rendercolor", color);
		DispatchKeyValue(TrailIndex, "renderamt", alpha);
		DispatchKeyValue(TrailIndex, "rendermode", renderMode);

		// Here we get the player's position
		GetClientAbsOrigin(client, fOrigin);
		fOrigin[2] += verticalOffset; // We raise the trail a bit up so it doesn't hug the ground
		
		// Here we spawn the entity
		DispatchSpawn(TrailIndex);
		// This puts the trail in position
		TeleportEntity(TrailIndex, fOrigin, NULL_VECTOR, NULL_VECTOR);
		
		// Here we give clients targetnames. We do this because Source is retarded.
		// (in all seriousness, we need it so we can attach trails to clients)
		char Buffer[64];
		Format(Buffer, sizeof(Buffer), "client_%i", client);
		DispatchKeyValue(client, "targetname", Buffer);
        
		// We give the trail an ownername so we can remove it later.
		SetEntPropEnt(TrailIndex, Prop_Send, "m_hOwnerEntity", client);
		
		// Here we parent the trail to the client
		SetVariantString(Buffer);
		AcceptEntityInput(TrailIndex, "SetParent");
	}
}

// This stock sets the lifetime of a trail, meant to hide it,
// enlarge it (for different gamemodes), and so on.
stock void SetTrailLifeTime(int client, float lifeTime)
{
	int TrailIndex = -1;
	if(IsValidClient(client) && GetClientTeam(client) >= 2 && IsPlayerAlive(client))
	{
		while((TrailIndex = FindEntityByClassname(TrailIndex, "env_spritetrail")) != -1)
		{
			int iTrailOwner = GetEntPropEnt(TrailIndex, Prop_Send, "m_hOwnerEntity");
			if(iTrailOwner == client)
			{
				fDefaultTrailLife = GetEntPropFloat(TrailIndex, Prop_Send, "m_flLifeTime");
				if(lifeTime >= 0.0)
				{
					SetEntPropFloat(TrailIndex, Prop_Send, "m_flLifeTime", lifeTime);
				}
			}
		}
	}
}

// This stock checks if a client has a trail.
stock bool DoesClientHaveTrail(int client)
{
	int TrailIndex = -1;
	if(IsValidClient(client) && GetClientTeam(client) >= 2 && IsPlayerAlive(client))
	{
		while((TrailIndex = FindEntityByClassname(TrailIndex, "env_spritetrail")) != -1)
		{
			int iTrailOwner = GetEntPropEnt(TrailIndex, Prop_Send, "m_hOwnerEntity");
			if(iTrailOwner == client) return true;
		}
	}
	
	return false;
}

// This stock is used to detach trails (for whenever clients die).
stock void DetachTrail(int client)
{
	int TrailIndex = -1;
	if(IsValidClient(client))
	{
		while((TrailIndex = FindEntityByClassname(TrailIndex, "env_spritetrail")) != -1)
		{
			int iTrailOwner = GetEntPropEnt(TrailIndex, Prop_Send, "m_hOwnerEntity");
			if(iTrailOwner == client)
			{	
				AcceptEntityInput(TrailIndex, "Kill");
				//PrintToChatAll("delet");
			}
		}
	}
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}