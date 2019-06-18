#include <sourcemod>
#include <sdkhooks>
#include <tf2> 
#include <tf2items> 
#include <tf2_stocks>
#include <tf2attributes> 
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Melee Only Rounds",
	author = "JugadorXEI",
	description = "none",
	version = "1.0",
	url =  "",
}

ConVar g_MeleeOnlyCoin; // Melee Only Coin.

public void OnPluginStart()
{
	HookEvent("player_spawn", MeleeOnly);
	HookEvent("post_inventory_application", MeleeOnly);

	g_MeleeOnlyCoin = CreateConVar("redsun_meleeround", "0", "Sets a round to be melee only.");
}

public Action MeleeOnly(Handle hEvent, const char[] name, bool dontBroadcast)
{		
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	bool DoesFrostySayTrue = GetConVarBool(g_MeleeOnlyCoin);

	if(DoesFrostySayTrue == true)
	{
		CreateTimer(0.1, MeleeWipe, iClient);
	}
}

// This is used for the Melee Only coin, whenever we need to wipe weapons off a player.
void MeleeWipe(any client)
{
	// Removes the wearable-kind of items like Sniper backpack secondaries, boots and such.
	int WearableItem = -1;
	while((WearableItem = FindEntityByClassname(WearableItem, "tf_wearable")) != -1)
	{
		int WearableIndex = GetEntProp(WearableItem, Prop_Send, "m_iItemDefinitionIndex");
		int WearableOwner = GetEntPropEnt(WearableItem, Prop_Send, "m_hOwnerEntity");
		if(WearableOwner == client)
		{
			switch(WearableIndex)
			{
				case 57, 133, 231, 405, 444, 608, 642: {TF2_RemoveWearable(client, WearableItem);}
			}
		}
	}
	
	// Removes BASE Jumpers.
	int ParachuteItem = -1;
	while((ParachuteItem = FindEntityByClassname(ParachuteItem, "tf_weapon_parachute")) != -1)
	{
		int ParachuteIndex = GetEntProp(ParachuteItem, Prop_Send, "m_iItemDefinitionIndex");
		int ParachuteOwner = GetEntPropEnt(ParachuteItem, Prop_Send, "m_hOwnerEntity");
		if(ParachuteOwner == client)
		{
			switch(ParachuteIndex)
			{
				case 1101: {TF2_RemoveWearable(client, ParachuteItem);}
			}
		}
	}
	
	// Removes Demoman's shields.
	int DemoshieldItem = -1;
	while((DemoshieldItem = FindEntityByClassname(DemoshieldItem, "tf_wearable_demoshield")) != -1)
	{
		int DemoshieldIndex = GetEntProp(DemoshieldItem, Prop_Send, "m_iItemDefinitionIndex");
		int DemoshieldOwner = GetEntPropEnt(DemoshieldItem, Prop_Send, "m_hOwnerEntity");
		if(DemoshieldOwner == client)
		{
			switch(DemoshieldIndex)
			{
				case 131, 406, 1099, 1144: {TF2_RemoveWearable(client, DemoshieldItem);}
			}
		}
	}

	// Removes weapons
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
	
	if(TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);			
	}
	
	int iMelee = GetPlayerWeaponSlot(client, 2);
	// Makes it so players switch to melee (aka not going as civs)
	SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iMelee);
}