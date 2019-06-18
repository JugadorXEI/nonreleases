#include <sourcemod> 
#include <tf2_stocks>
#include <tf2items_giveweapon> 
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0"

bool bLethalDuel = false;

public Plugin myinfo =
{
	name = "Evento Weebkend (RGC)",
	author = "JugadorXEI",
	description = "Este modo bloquea armas y clases especificas para crear duelos de honor.",
	version = PLUGIN_VERSION,
	url =  "",
}

public void OnPluginStart()
{
	HookEvent("player_spawn", SpawnHandler);
	HookEvent("post_inventory_application", SpawnHandler);
	HookEvent("player_hurt", HurtHandler);
	HookEvent("player_death", DeathHandler, EventHookMode_Pre);
	PrintToServer("El Plugin 'Evento Weebkend' ha cargado sin problemas.");
}

public Action SpawnHandler(Handle hEvent, const char[] name, bool dontBroadcast)
{		
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	TFClassType iClientClass = TF2_GetPlayerClass(iClient);
	int iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
	int iMeleeIndex = -1;
	if (iMelee != -1) iMeleeIndex = GetEntProp(iMelee, Prop_Send, "m_iItemDefinitionIndex");
	
	switch (iClientClass)
	{
		case TFClass_Soldier, TFClass_DemoMan:
		{
			if (IsValidClient(iClient) && iMelee != -1 && iMeleeIndex != 357)
			{
				TF2Items_GiveWeapon(iClient, 357); // 357 = Half-Zatoichi
			}
		}
	}
	
}

public Action HurtHandler(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	
	int iMeleeAtk = GetPlayerWeaponSlot(iAttacker, TFWeaponSlot_Melee);
	int iMeleeAtkIndex = -1;
	if (iMeleeAtk != -1) iMeleeAtkIndex = GetEntProp(iMeleeAtk, Prop_Send, "m_iItemDefinitionIndex");
	int iDamageAmount = GetEventInt(hEvent, "damageamount");
	
	if (iMeleeAtk != -1 && iMeleeAtkIndex == 357 && iDamageAmount >= 400)
	{
		bLethalDuel = true;
	}
	
	//PrintToChatAll("iMeleeAttacker: %i\niMeleeAttackerIndex: %i\niDamageAmount: %i\nbLethalDuel: %i", iMeleeAtk, iMeleeAtkIndex, iDamageAmount, bLethalDuel);
}

public Action DeathHandler(Handle hEvent, const char[] name, bool dontBroadcast)
{
	if (bLethalDuel == true)
	{
		SetEventString(hEvent, "weapon", "taunt_demoman");
		SetEventString(hEvent, "weapon_logclassname", "taunt_demoman");
		//SetEventInt(hEvent, "customkill", TF_CUSTOM_AEGIS_ROUND);
	}
	
	bLethalDuel = false;
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