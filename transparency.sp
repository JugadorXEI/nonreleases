#include <sourcemod>
#include <sdktools>
#include <morecolors> 
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION 		"v0.10a"

public Plugin myinfo =
{
	name = "Viewmodel transparency",
	author = "JugadorXEI",
	description = "Makes viewmodels transparent for visibility purposes (Randomizer)",
	version = PLUGIN_VERSION,
}

int iModelTransparencyEnabled[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_transparent", CommandTrans);
	
	HookEvent("player_spawn", SetTransparency);
}

public Action CommandTrans(int client, int args)
{
	if (args < 1 && IsValidClient(client))
	{
		CPrintToChat(client, "{redsunerror}sm_transparent/sm_transparency 0/1. (Current state is %i)", iModelTransparencyEnabled[client]);
		return Plugin_Handled;
	}

	if(!IsValidClient(client) || GetClientTeam(client) <= 1)
	{
		CPrintToChat(client, "{redsunerror}You aren't a valid client to put viewmodel transparency into.");
		return Plugin_Handled;
	}
	else
	{
		char arg[255];
		GetCmdArg(1, arg, sizeof(arg));
		int iArgument = StringToInt(arg);
		
		if (iArgument == 0)
		{
			iModelTransparencyEnabled[client] = 0;
			CPrintToChat(client, "{redsunerror}Viewmodel transparency has been disabled.", iModelTransparencyEnabled[client]);
			
			int TransparencyItem = -1;
			while((TransparencyItem = FindEntityByClassname(TransparencyItem, "tf_viewmodel")) != -1)
			{
				int TransparencyOwner = GetEntPropEnt(TransparencyItem, Prop_Send, "m_hOwner");
				if(TransparencyOwner == client)
				{
					SetEntProp(TransparencyItem, Prop_Data, "m_nRenderMode", 0);
					SetEntProp(TransparencyItem, Prop_Data, "m_nRenderFX", 255);
				}
			}
		}
		else if (iArgument == 1)
		{
			iModelTransparencyEnabled[client] = 1;
			CPrintToChat(client, "{redsunerror}Viewmodel transparency has been enabled.");
			
			int TransparencyItem = -1;
			while((TransparencyItem = FindEntityByClassname(TransparencyItem, "tf_viewmodel")) != -1)
			{
				int TransparencyOwner = GetEntPropEnt(TransparencyItem, Prop_Send, "m_hOwner");
				if(TransparencyOwner == client)
				{
					SetEntProp(TransparencyItem, Prop_Data, "m_nRenderMode", 1);
					SetEntProp(TransparencyItem, Prop_Data, "m_nRenderFX", 100);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action SetTransparency(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(iClient) && iModelTransparencyEnabled[iClient] == 1)
	{
		int TransparencyItem = -1;
		while((TransparencyItem = FindEntityByClassname(TransparencyItem, "tf_viewmodel")) != -1)
		{
			int TransparencyOwner = GetEntPropEnt(TransparencyItem, Prop_Send, "m_hOwner");
			if(TransparencyOwner == iClient)
			{
				SetEntProp(TransparencyItem, Prop_Data, "m_nRenderMode", 1);
				SetEntProp(TransparencyItem, Prop_Data, "m_nRenderFX", 100);
			}
		}
		
		CPrintToChat(iClient, "{redsunerror}Viewmodel transparency is enabled."); 
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
