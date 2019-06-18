#include <sourcemod>
#include <tf2> 
#include <tf2_stocks>
#include <morecolors> 
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "v1.0" 

public Plugin myinfo =
{
	name = "Rocket Test For Lulz",
	author = "JugadorXEI",
	description = "none",
	version = PLUGIN_VERSION,
}

int iGlow = -1;

public void OnPluginStart()
{
	iGlow = PrecacheModel("sprites/plasmahalo.vmt");
	RegAdminCmd("sm_rocketspawn", Cvar_RocketSpawn, ADMFLAG_KICK);
}

public Action Cvar_RocketSpawn(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		CPrintToChat(iClient, "{redsunerror}Usage: sm_rocketspawn <#userid|name>");
		return Plugin_Handled;
	}
	
	char cName[32];
	GetCmdArg(1, cName, sizeof(cName));
	
	/**
	 * target_name - stores the noun identifying the target(s)
	 * target_list - array to store clients
	 * target_count - variable to store number of clients
	 * tn_is_ml - stores whether the noun must be translated
	 */
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
 
	if ((target_count = ProcessTargetString(
			cName, /* Pattern to find clients against. */ 
			iClient, /* Admin performing the action, or 0 if the server. */
			target_list, /* Array to hold the targets. */
			MAXPLAYERS, /* Max size of array. */
			COMMAND_FILTER_ALIVE, /* Only allow alive players */
			target_name, /* Buffer to store target name */
			sizeof(target_name), /* size of target nae */
			tn_is_ml)) <= 0) /* Is it translatable? */
	{
		/* This function replies to the admin with a failure message */
		CPrintToChat(iClient, "{redsunerror}No matching clients found.\nUsage: sm_rocketspawn <#userid|name>");
		return Plugin_Handled;
	}
 
	for (int i = 0; i < target_count; i++)
	{
		SpawnRocketInFrontOfPlayer(target_list[i], iClient);
	}
	
	// Sourcemod targetting forces me to.
	if (tn_is_ml) CPrintToChat(iClient, "{gold}Spawned rocket in front of %s.", target_name);
	else CPrintToChat(iClient, "{gold}Spawned rocket in front of %s.", target_name);
	
	return Plugin_Handled;
}

stock void SpawnRocketInFrontOfPlayer(int iTarget, int iClient)
{
	// Gets the class of the client
	TFClassType iClass = TF2_GetPlayerClass(iTarget);
	
	float vecTargetEyeAngles[3]; // eye angles of the target
	float vecTargetAbsOrigin[3]; // position of the target
	
	// We get where's the player and where are they looking at
	GetClientEyeAngles(iTarget, vecTargetEyeAngles); // eyes
	GetClientAbsOrigin(iTarget, vecTargetAbsOrigin); // pos
	
	// This offsets the origin based on the distance from the player's feet to the camera
	// https://developer.valvesoftware.com/wiki/TF2/Team_Fortress_2_Mapper%27s_Reference
	switch(iClass)
	{
		case TFClass_Scout: vecTargetAbsOrigin[2] += 65.0;
		case TFClass_Soldier: vecTargetAbsOrigin[2] += 68.0;
		case TFClass_Pyro: vecTargetAbsOrigin[2] += 68.0;
		case TFClass_DemoMan: vecTargetAbsOrigin[2] += 68.0;
		case TFClass_Heavy: vecTargetAbsOrigin[2] += 75.0;
		case TFClass_Engineer: vecTargetAbsOrigin[2] += 68.0;
		case TFClass_Medic: vecTargetAbsOrigin[2] += 75.0;
		case TFClass_Sniper: vecTargetAbsOrigin[2] += 75.0;
		case TFClass_Spy: vecTargetAbsOrigin[2] += 75.0;
		default: vecTargetAbsOrigin[2] += 75.0;
	}
	
	float vecForward[3];
	GetAngleVectors(vecTargetEyeAngles, vecForward, NULL_VECTOR, NULL_VECTOR); 
	
	float vecNormal[3];
	NormalizeVector(vecForward, vecNormal);
	
	ScaleVector(vecNormal, 160.0);
	
	float vecResult[3];
	AddVectors(vecTargetAbsOrigin, vecNormal, vecResult);
	
	float vecDirection[3];
	vecDirection[2] += 100.0;
	
	int RocketIndex = CreateEntityByName("tf_projectile_rocket"); // time to create the rocket

	if (RocketIndex > 0 && IsValidEntity(RocketIndex))
	{		
		// Here we spawn the entity
		DispatchSpawn(RocketIndex);
		// we change the rocket model because it has a trail that cannot be hidden.
		SetEntityModel(RocketIndex, "models/weapons/w_models/w_grenade_grenadelauncher.mdl");
		
		TE_SetupBeamFollow(RocketIndex, iGlow, iGlow, 10.0, 5.0, 5.0, 3, {255, 0, 255, 255});
		TE_SendToClient(iClient);
		
		// This puts the rocket in position
		TeleportEntity(RocketIndex, vecResult, NULL_VECTOR, vecDirection);
		
		SetEntityRenderMode(RocketIndex, RENDER_TRANSALPHA);
		SetEntityRenderColor(RocketIndex, 255, 255, 255, 0);
	}
}

public bool RayHitPlayer(int entity, int mask, any data)
{ 
    if (entity == data) return false; //did the trace hit the player?
    else return true; //nope, it did not.
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