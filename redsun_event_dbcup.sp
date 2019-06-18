#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> 
#include <redsunoverparadise>
#include <dodgeball_redsun>
#include <discord>
#include <steamtools>
#include <morecolors>
#pragma semicolon 1
#pragma newdecls required

#define KILLS 						1
#define CHALLENGERSKILLED		2
#define CHALLENGESTAKEN			3
#define CHALLENGESWON			4

#define PLUGIN_VERSION 		"v1.00"
			
ConVar g_bEnablePlugin;
ConVar g_bSendTourneyAnnouncement;
ConVar g_cChannelToSend;

public Plugin myinfo =
{
	name = "Dodgeball Summer Cup 2017 Event Plugin",
	author = "JugadorXEI",
	description = "Tracks players' stats for the Summer Event Plugin",
	version = PLUGIN_VERSION,
}

// Player data.
int iEventDodgeballStats[6][MAXPLAYERS+1]; // This gets added into the players' stats later.
int iEventDodgeballExtraPoints[MAXPLAYERS+1]; // extra points players get on certain events.

// Round state bool meant for when to and not to track stats.
// When rounds are over people often kill themselves to goof off, so we don't track those deaths.
bool bRoundStateEnd = true;

int iChallengerKillCount = 0; // for dbc coin, counts how many players the challenger kill
int iPlayersParticipating = 0;

public void OnPluginStart()
{
	HookEvent("player_death", Event_UpdateData);
		
	HookEvent("arena_round_start", EventState_ArenaRoundStart);
	HookEvent("teamplay_round_win", EventState_UpdateData_ArenaRoundEnd, EventHookMode_Pre);
	HookEvent("teamplay_round_stalemate", EventState_UpdateData_ArenaRoundEnd, EventHookMode_Pre);
	
	PrecacheSound("ui/scored.wav");
	
	g_bEnablePlugin = CreateConVar("redsun_dbevent_enable", "1", "Enables or disables the plugin. Default: 1", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bSendTourneyAnnouncement = CreateConVar("redsun_dbevent_announcement", "1", "Enables or disables the TFDB Summer Cup announcement. Default: 1", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_cChannelToSend = CreateConVar("redsun_dbevent_channel", "events", "Selects which channel to send the warning message to. Needs to be defined in config/discord.cfg file. Default: 'events'", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	
	bool bEnablePlugin = GetConVarBool(g_bEnablePlugin);
	bool bEnableAnnouncement = GetConVarBool(g_bSendTourneyAnnouncement);
	
	// Here we prepare the message to send to the #events channel
	if (bEnablePlugin == true && bEnableAnnouncement == true)
	{
		char cServerName[64], cMapName[64], cPort[10];
		int iIP[4];
		Handle hServerName = FindConVar("redsun_server");
		Handle hPort = FindConVar("hostport");

		GetConVarString(hServerName, cServerName, sizeof(cServerName));
		Steam_GetPublicIP(iIP);
		GetCurrentMap(cMapName, sizeof(cMapName));
		IntToString(GetConVarInt(hPort), cPort, sizeof(cPort));
		
		char cMessageToDiscord[255];
		Format(cMessageToDiscord, sizeof(cMessageToDiscord), "Dodgeball is now active on **%s** on the map **%s**! Join by clicking here: steam://connect/%i.%i.%i.%i:%s", cServerName, cMapName, iIP[0], iIP[1], iIP[2], iIP[3], cPort);
		
		char cChannel[64]; GetConVarString(g_cChannelToSend, cChannel, sizeof(cChannel));
		SendMessageToDiscord(cChannel, cMessageToDiscord);
	}
}

public Action Event_UpdateData(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iCustomKill = GetEventInt(hEvent, "customkill");
	int iDeathFlags = GetEventInt(hEvent, "death_flags");
	
	int iChallenger = Dodgeball_GetChallengerUserid();
	
	bool bEnablePlugin = GetConVarBool(g_bEnablePlugin);
	
	if (bEnablePlugin == true && bRoundStateEnd == false && iPlayersParticipating >= 10)
	{
		if (IsValidClient(iVictim) && IsValidClient(iAttacker) && iVictim != iAttacker) iEventDodgeballStats[KILLS][iAttacker]++; // kills
		
		if (Dodgeball_IsChallengeActive() && IsValidClient(iChallenger))
		{
			if (iChallenger == iVictim && iAttacker == 0 && iDeathFlags >= 128)
			{
				int iRandomPlayer = GetRandomAliveBLUClient();
				
				if (IsValidClient(iRandomPlayer) && GetClientTeam(iRandomPlayer) == 3 && IsPlayerAlive(iRandomPlayer))
				{
					char strName[128];
					GetRedSunName(iRandomPlayer, strName, sizeof(strName));					

					EmitSoundToClient(iRandomPlayer, "ui/scored.wav");
					
					if (iChallengerKillCount > 0) CPrintToChatAll("{green}The challenger has died due to environmental damage, so the kills will be awarded randomly.\n%s {green}has been awarded {gold}%i {green}extra %s!", strName, iChallengerKillCount, (iChallengerKillCount == 1) ? "kill" : "kills");
					
					iEventDodgeballExtraPoints[iRandomPlayer] = iEventDodgeballExtraPoints[iRandomPlayer] + iChallengerKillCount;
					iChallengerKillCount = 0;
				}
			}
			else if (iChallenger == iVictim && iAttacker == iVictim && iCustomKill >= 6)
			{
				int iRandomPlayer = GetRandomAliveBLUClient();
				
				if (IsValidClient(iRandomPlayer) && GetClientTeam(iRandomPlayer) == 3 && IsPlayerAlive(iRandomPlayer))
				{
					char strName[128];
					GetRedSunName(iRandomPlayer, strName, sizeof(strName));					

					EmitSoundToClient(iRandomPlayer, "ui/scored.wav");
					
					if (iChallengerKillCount > 0) CPrintToChatAll("{green}The challenger has killed themself, so the kills will be awarded randomly.\n%s {green}has been awarded {gold}%i {green}extra %s!", strName, iChallengerKillCount, (iChallengerKillCount == 1) ? "kill" : "kills");
					
					iEventDodgeballExtraPoints[iRandomPlayer] = iEventDodgeballExtraPoints[iRandomPlayer] + iChallengerKillCount;
					iChallengerKillCount = 0;
				}
			}
			else if(iChallenger == iVictim && iChallenger != iAttacker && IsValidClient(iAttacker))
			{
				iEventDodgeballStats[CHALLENGERSKILLED][iAttacker]++; // challengers killed
				
				char strName[128];
				GetRedSunName(iAttacker, strName, sizeof(strName));			
	
				EmitSoundToClient(iAttacker, "ui/scored.wav");
				if (iChallengerKillCount > 0) CPrintToChatAll("%s {green}has been awarded {gold}%i {green}extra %s for killing the challenger!", strName, iChallengerKillCount, (iChallengerKillCount == 1) ? "kill" : "kills");
				else CPrintToChatAll("%s {green}has successfully killed the challenger!", strName);
				
				iEventDodgeballExtraPoints[iAttacker] = iEventDodgeballExtraPoints[iAttacker] + iChallengerKillCount;
				iChallengerKillCount = 0;
			}
			else if (GetClientTeam(iVictim) == 3) iChallengerKillCount++;
		}
	}
}

public Action EventState_UpdateData_ArenaRoundEnd(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iTeam = GetEventInt(hEvent, "team");
	int iChallenger = Dodgeball_GetChallengerUserid(); // player who's taking the challenge
	
	bool bEnablePlugin = GetConVarBool(g_bEnablePlugin);
	
	if (bEnablePlugin == true && Dodgeball_IsChallengeActive() && IsValidClient(iChallenger) &&
	IsPlayerAlive(iChallenger) && iTeam == 2 && iPlayersParticipating >= 10) iEventDodgeballStats[CHALLENGESWON][iChallenger]++;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (bEnablePlugin == true && IsValidClient(i) && !IsFakeClient(i) &&
		!Loadout_GetGameplayBan(i) && iPlayersParticipating >= 10)
		{
			if (iEventDodgeballStats[KILLS][i] > 0)
			{
				Loadout_AddToGeneric(i, iEventDodgeballStats[KILLS][i] + iEventDodgeballExtraPoints[i], "dbcKills"); // kills
				
				iEventDodgeballStats[KILLS][i] = 0;
				iEventDodgeballExtraPoints[i] = 0;
			}
			
			if (iEventDodgeballStats[CHALLENGERSKILLED][i] > 0)
			{
				Loadout_AddToGeneric(i, iEventDodgeballStats[CHALLENGERSKILLED][i], "dbcChallengersKilled"); // challenges killed
				iEventDodgeballStats[CHALLENGERSKILLED][i] = 0;
			}
			
			if (iEventDodgeballStats[CHALLENGESTAKEN][i] > 0)
			{
				Loadout_AddToGeneric(i, iEventDodgeballStats[CHALLENGESTAKEN][i], "dbcChallengesTaken"); // challenges taken
				iEventDodgeballStats[CHALLENGESTAKEN][i] = 0;
			}
			
			if (iEventDodgeballStats[CHALLENGESWON][i] > 0)
			{
				Loadout_AddToGeneric(i, iEventDodgeballStats[CHALLENGESWON][i], "dbcChallengesWon"); // challenges won
				iEventDodgeballStats[CHALLENGESWON][i] = 0;
			}
		}
	}

	bRoundStateEnd = true;
}

public Action EventState_ArenaRoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
	iPlayersParticipating = 0;
	for (int i = 1; i <= MaxClients; i++) // counts players participating this round
	{
		if (IsValidClient(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) >= TFTeam_Red) iPlayersParticipating++;
	}
	
	bool bEnablePlugin = GetConVarBool(g_bEnablePlugin);
	
	if(bEnablePlugin == true && Dodgeball_IsChallengeActive() && iPlayersParticipating >= 10)
	{
		int iChallenger = Dodgeball_GetChallengerUserid(); // player who's taking the challenge
		iChallengerKillCount = 0;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == 2 && iChallenger == i) iEventDodgeballStats[CHALLENGESTAKEN][i]++;
		}
		
		char strName[255];
		GetRedSunName(iChallenger, strName, sizeof(strName));
		CPrintToChatAll("{green}You are now fighting against %s{green}!\nSuccessfully killing them will award the killer as many kills as the challenger did. Good luck!", strName);
	}
	
	bRoundStateEnd = false;
	//PrintToChatAll("bRoundStateEnd = %i", bRoundStateEnd);
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

public int GetRandomAliveBLUClient()
{  
    int iClients[MAXPLAYERS];
    int iClientsNum, i;
    for (i = 1; i <= MaxClients; ++i)  
    {  
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3) 
        { 
            iClients[iClientsNum++] = i;  
        } 
    }  
    if (iClientsNum > 0) 
    { 
        return iClients[GetRandomInt(0, iClientsNum-1)];  
    } 
    return 0;
}