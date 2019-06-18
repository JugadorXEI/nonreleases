#include <sourcemod>
#include <sdktools>
#include <tf2_stocks> 
#include <redsunoverparadise>
#include <dodgeball_redsun>
#include <morecolors>
#pragma semicolon 1
#pragma newdecls required

#define POINTS 					1
#define KILLS 						2
#define DEATHS 					3
#define DOMINATIONS 				4
#define REVENGES 					5
#define CHALLENGERSKILLED		6
#define CHALLENGESTAKEN			7
#define CHALLENGESWON			8

#define PLUGIN_VERSION 		"v0.75"

public Plugin myinfo =
{
	name = "Dodgeball Summer Cup 2017 Event Plugin",
	author = "JugadorXEI",
	description = "Tracks players' stats for the Summer Event Plugin",
	version = PLUGIN_VERSION,
}

Handle DBEventDatabase;
char cError[255];

// Player data.
int iEventDodgeballStats[16][MAXPLAYERS+1]; // This gets added into the players' stats later.
int iEventDodgeballFetchedStats[16][MAXPLAYERS+1]; // The stats the player already has. 
int iEventDodgeballExtraPoints[MAXPLAYERS+1]; // extra points players get on certain events.
bool bWasDataFetchSucessful[MAXPLAYERS+1] = false; // We make sure that player's data was fetched.

// Round state bool meant for when to and not to track stats.
// When rounds are over people often kill themselves to goof off, so we don't track those deaths.
bool bRoundStateEnd = true;

int iPeasantCount = 0; // for dbc coin, counts the people against the challenger

public void OnPluginStart()
{
	DogeballEvent_Connect()

	HookEvent("player_death", Event_UpdateData);
		
	HookEvent("arena_round_start", EventState_ArenaRoundStart);
	HookEvent("teamplay_round_win", EventState_UpdateData_ArenaRoundEnd, EventHookMode_Pre);
	
	PrecacheSound("ui/scored.wav");
}

public Loadout_Event_Dodgeball_Connect(Handle hOwner, Handle hDatabase, char[] sError, any anyData)
{
	if (hDatabase == INVALID_HANDLE)
    {
		PrintToServer("There was an error connecting, retrying soon...")
		CreateTimer(10.0, TimerReconnect, _, TIMER_FLAG_NO_MAPCHANGE); 
    }
	else
	{
		PrintToServer("Connected.");
		DBEventDatabase = hDatabase;
	}
}

public void OnClientPostAdminCheck(int client)
{
	char cClientSteamID64[64];
	
	if (GetClientAuthId(client, AuthId_SteamID64, cClientSteamID64, sizeof(cClientSteamID64)) && client > 0)
	{
		char cNeatQuery[255];	
		Format(cNeatQuery, sizeof(cNeatQuery), "SELECT * FROM dbstats WHERE steamid='%s'", cClientSteamID64);
		// PrintToServer(cNeatQuery);
		
		if (DBEventDatabase != null)
		{
			SQL_LockDatabase(DBEventDatabase);
			DBResultSet qPlayerExistance = SQL_Query(DBEventDatabase, cNeatQuery);
			if (qPlayerExistance == null)
			{
				SQL_GetError(DBEventDatabase, cError, sizeof(cError));
				PrintToServer("[DBEVENT.smx] Failed to query (error: %s)", cError);
			}
			else
			{	
				if (SQL_GetRowCount(qPlayerExistance) == 0)
				{
					char cNeatQuery2[255];
					Format(cNeatQuery2, sizeof(cNeatQuery2), "INSERT INTO dbstats (steamid) VALUES ('%s')", cClientSteamID64);
					// PrintToServer(cNeatQuery2);
					
					if (!SQL_FastQuery(DBEventDatabase, cNeatQuery2))
					{
						SQL_GetError(DBEventDatabase, cError, sizeof(cError));
						PrintToServer("[DBEVENT.smx] Failed to query (error: %s)", cError);	
					}
					else
					{
						// PrintToServer("%s has been added to the database...", cClientSteamID64);
						bWasDataFetchSucessful[client] = true;
					}
				}
				else
				{
					// PrintToServer("%s is on the database.", cClientSteamID64);
					if(SQL_FetchRow(qPlayerExistance))
					{
						iEventDodgeballFetchedStats[POINTS][client] = SQL_FetchInt(qPlayerExistance, 2);
						iEventDodgeballFetchedStats[KILLS][client] = SQL_FetchInt(qPlayerExistance, 3);
						iEventDodgeballFetchedStats[DEATHS][client] = SQL_FetchInt(qPlayerExistance, 4);
						iEventDodgeballFetchedStats[DOMINATIONS][client] = SQL_FetchInt(qPlayerExistance, 5);
						iEventDodgeballFetchedStats[REVENGES][client] = SQL_FetchInt(qPlayerExistance, 6);
						iEventDodgeballFetchedStats[CHALLENGERSKILLED][client] = SQL_FetchInt(qPlayerExistance, 7);
						iEventDodgeballFetchedStats[CHALLENGESTAKEN][client] = SQL_FetchInt(qPlayerExistance, 8);
						iEventDodgeballFetchedStats[CHALLENGESWON][client] = SQL_FetchInt(qPlayerExistance, 9);
						bWasDataFetchSucessful[client] = true;
					}
				}
				
				CloseHandle(qPlayerExistance);
				SQL_UnlockDatabase(DBEventDatabase);
			}
		}
	}
	/*
	else
	{
		PrintToServer("something went wrong, oops");
	}
	*/
}

public Action Event_UpdateData(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iVictim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int iAttacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));
	int iAssister = GetClientOfUserId(GetEventInt(hEvent, "assister"));
	int iDeathFlags = GetEventInt(hEvent, "death_flags");
	
	int iChallenger = Dodgeball_GetChallengerUserid();
	
	if (bRoundStateEnd == false)
	{
		if (bWasDataFetchSucessful[iAttacker] && iVictim > 0) iEventDodgeballStats[KILLS][iAttacker]++; // kills
		if (bWasDataFetchSucessful[iVictim] && iVictim != iAttacker) iEventDodgeballStats[DEATHS][iVictim]++; // deaths
		
		// points
		if (bWasDataFetchSucessful[iAttacker]) iEventDodgeballStats[POINTS][iAttacker] = GetEntProp(iAttacker, Prop_Send, "m_iPoints");
		if (bWasDataFetchSucessful[iAssister]) iEventDodgeballStats[POINTS][iAssister] = GetEntProp(iAssister, Prop_Send, "m_iPoints");
		
		if (bWasDataFetchSucessful[iAttacker] && Dodgeball_IsChallengeActive() && IsValidClient(iChallenger) && iChallenger == iVictim)
		{
			iEventDodgeballStats[CHALLENGERSKILLED][iAttacker]++; // challengers killed
			int iFormulaKill = iPeasantCount / 2 + 1;
			
			/* 			
			char strIcon[64];
			char strColor[32];
			char strName[128];
			char strTitle[128];

			Loadout_ChatIcon(iAttacker, strIcon, sizeof(strIcon));
			Loadout_ChatColor(iAttacker, strColor, sizeof(strColor));
			Loadout_DonatorTitle(iAttacker, strTitle, sizeof(strTitle));
			GetClientName2(iAttacker, strName, sizeof(strName));
			Format(strName, sizeof(strName), "%s %s%s%s", strIcon, strColor, strName, strTitle);
			
			EmitSoundToClient(iAttacker, "ui/scored.wav");
			CPrintToChatAll("%s {green}has been awarded %i extra points for killing the challenger!", strName, iFormulaKill);
			*/
			iEventDodgeballExtraPoints[iAttacker] = iEventDodgeballExtraPoints[iAttacker] + iFormulaKill;
		}
		
		// dominations
		if (iDeathFlags & TF_DEATHFLAG_KILLERDOMINATION)
		{
			if (bWasDataFetchSucessful[iAttacker]) iEventDodgeballStats[DOMINATIONS][iAttacker]++;
		}
		
		if (iDeathFlags & TF_DEATHFLAG_ASSISTERDOMINATION)
		{
			if (bWasDataFetchSucessful[iAssister]) iEventDodgeballStats[DOMINATIONS][iAssister]++;
		}
		
		// revenges
		if (iDeathFlags & TF_DEATHFLAG_KILLERREVENGE)
		{
			if (bWasDataFetchSucessful[iAttacker]) iEventDodgeballStats[REVENGES][iAttacker]++;
		}
		
		if (iDeathFlags & TF_DEATHFLAG_ASSISTERREVENGE)
		{
			if (bWasDataFetchSucessful[iAssister]) iEventDodgeballStats[REVENGES][iAssister]++;
		}
	}
}

public Action EventState_UpdateData_ArenaRoundEnd(Handle hEvent, const char[] name, bool dontBroadcast)
{
	int iTeam = GetEventInt(hEvent, "team");
	int iChallenger = Dodgeball_GetChallengerUserid(); // player who's taking the challenge
	
	if (Dodgeball_IsChallengeActive() && IsValidClient(iChallenger) && IsPlayerAlive(iChallenger) && iTeam == 2) iEventDodgeballStats[CHALLENGESWON][iChallenger]++;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) != 0)
		{
			iEventDodgeballStats[POINTS][i] = GetEntProp(i, Prop_Send, "m_iPoints");
		}
	}
	
	iPeasantCount = 0;
	bRoundStateEnd = true;
	//PrintToChatAll("bRoundStateEnd = %i", bRoundStateEnd);
}

public Action EventState_ArenaRoundStart(Handle hEvent, const char[] name, bool dontBroadcast)
{
	if(Dodgeball_IsChallengeActive())
	{
		int iChallenger = Dodgeball_GetChallengerUserid(); // player who's taking the challenge
		iPeasantCount = 0; // for dbc coin, counts the people against the challenger
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i) && GetClientTeam(i) == 2 && iChallenger == i)
			{
				iEventDodgeballStats[CHALLENGESTAKEN][i]++;
			}
			else if (IsValidClient(i) && GetClientTeam(i) == 3)
			{
				iPeasantCount++;
			}
		}
		/*		
		int iFormula = iPeasantCount / 2 + 1;
		
		char strIcon[64];
		char strColor[32];
		char strName[128];
		char strTitle[128];

		Loadout_ChatIcon(iChallenger, strIcon, sizeof(strIcon));
		Loadout_ChatColor(iChallenger, strColor, sizeof(strColor));
		Loadout_DonatorTitle(iChallenger, strTitle, sizeof(strTitle));
		GetClientName2(iChallenger, strName, sizeof(strName));
		Format(strName, sizeof(strName), "%s %s%s%s", strIcon, strColor, strName, strTitle);
		
		CPrintToChatAll("{green}You are now fighting against %s{green}! Successfully killing them will award the killer %i points. Good luck!", strName, iFormula);
		*/
	}
	
	bRoundStateEnd = false;
	//PrintToChatAll("bRoundStateEnd = %i", bRoundStateEnd);
}

// If they disconnect, save their stats for later.
public void OnClientDisconnect(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client) && !Loadout_GetGameplayBan(client))
	{
		DogeballEvent_UpdateData(client);
		iEventDodgeballStats[POINTS][client] = 0;
		iEventDodgeballStats[KILLS][client] = 0;
		iEventDodgeballStats[DEATHS][client] = 0;
		iEventDodgeballStats[DOMINATIONS][client] = 0;
		iEventDodgeballStats[REVENGES][client] = 0;
		iEventDodgeballStats[CHALLENGERSKILLED][client] = 0;
		iEventDodgeballStats[CHALLENGESTAKEN][client] = 0;
		iEventDodgeballStats[CHALLENGESWON][client] = 0;
		iEventDodgeballExtraPoints[client] = 0;
		bWasDataFetchSucessful[client] = false;
	}
}

// If the plugin unloads for whatever reason, save people's stats.
public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && !Loadout_GetGameplayBan(i))
		{
			DogeballEvent_UpdateData(i);
			iEventDodgeballStats[POINTS][i] = 0;
			iEventDodgeballStats[KILLS][i] = 0;
			iEventDodgeballStats[DEATHS][i] = 0;
			iEventDodgeballStats[DOMINATIONS][i] = 0;
			iEventDodgeballStats[REVENGES][i] = 0;
			iEventDodgeballStats[CHALLENGERSKILLED][i] = 0;
			iEventDodgeballStats[CHALLENGESTAKEN][i] = 0;
			iEventDodgeballStats[CHALLENGESWON][i] = 0;
			iEventDodgeballExtraPoints[i] = 0;
			bWasDataFetchSucessful[i] = false;
		}
	}
}

// Stock used to update players' stats.
stock void DogeballEvent_UpdateData(int client)
{
	char cClientSteamID64[64];
	
	if (GetClientAuthId(client, AuthId_SteamID64, cClientSteamID64, sizeof(cClientSteamID64)) && client > 0 && bWasDataFetchSucessful[client] == true)
	{
		char cNeatQuery[1000];
		
		Format(cNeatQuery, sizeof(cNeatQuery), "SELECT * FROM dbstats WHERE steamid='%s'", cClientSteamID64);
		PrintToServer(cNeatQuery);
		
		if (DBEventDatabase != null)
		{
			SQL_LockDatabase(DBEventDatabase);
			DBResultSet qPlayerUpdateData = SQL_Query(DBEventDatabase, cNeatQuery);
			if (qPlayerUpdateData == null)
			{
				SQL_GetError(DBEventDatabase, cError, sizeof(cError));
				PrintToServer("Failed to query (error: %s)", cError);
			}
			else
			{
				if (SQL_GetRowCount(qPlayerUpdateData) != 0)
				{
					// PrintToServer("%s is on the database. Updating data...", cClientSteamID64);
					// Fetching ints from the scoreboard always reduces them to minus one the current number, so I add one in to prevent this.
					if(iEventDodgeballStats[POINTS][client] != 0) iEventDodgeballStats[POINTS][client]++;
					Format(cNeatQuery, sizeof(cNeatQuery), "UPDATE dbstats SET points = points + %i,kills = kills + %i,deaths = deaths + %i,dominations = dominations + %i,revenges = revenges + %i,challengerskilled = challengerskilled + %i,challengestaken = challengestaken + %i,challengeswon = challengeswon + %i WHERE steamid=%s", iEventDodgeballStats[POINTS][client] + iEventDodgeballExtraPoints[client], iEventDodgeballStats[KILLS][client], iEventDodgeballStats[DEATHS][client], iEventDodgeballStats[DOMINATIONS][client], iEventDodgeballStats[REVENGES][client], iEventDodgeballStats[CHALLENGERSKILLED][client], iEventDodgeballStats[CHALLENGESTAKEN][client], iEventDodgeballStats[CHALLENGESWON][client], cClientSteamID64);
					// PrintToServer("UPDATE dbstats SET points = points + %i,kills = kills + %i,deaths = deaths + %i,dominations = dominations + %i,revenges = revenges + %i,challengerskilled = challengerskilled + %i,challengestaken = challengestaken + %i,challengeswon = challengeswon + %i WHERE steamid=%s", iEventDodgeballStats[POINTS][client] + iEventDodgeballExtraPoints[client], iEventDodgeballStats[KILLS][client], iEventDodgeballStats[DEATHS][client], iEventDodgeballStats[DOMINATIONS][client], iEventDodgeballStats[REVENGES][client], iEventDodgeballStats[CHALLENGERSKILLED][client], iEventDodgeballStats[CHALLENGESTAKEN][client], iEventDodgeballStats[CHALLENGESWON][client], cClientSteamID64);
					if (!SQL_FastQuery(DBEventDatabase, cNeatQuery))
					{
						SQL_GetError(DBEventDatabase, cError, sizeof(cError));
						PrintToServer("[DBEVENT.smx]Failed to query (error: %s)", cError);
					}
					else
					{
						// PrintToServer("!!! Data has been added for %s: !!!\nPoints: %i\nKills: %i\nDeaths: %i\nDominations: %i\nRevenges: %i\nChallengers killed: %i\nChallenges taken: %i\nChallenges won: %i\n-----", cClientSteamID64, iEventDodgeballStats[POINTS][client] + iEventDodgeballExtraPoints[client], iEventDodgeballStats[KILLS][client], iEventDodgeballStats[DEATHS][client], iEventDodgeballStats[DOMINATIONS][client], iEventDodgeballStats[REVENGES][client], iEventDodgeballStats[CHALLENGERSKILLED][client], iEventDodgeballStats[CHALLENGESTAKEN][client], iEventDodgeballStats[CHALLENGESWON][client]);
						bWasDataFetchSucessful[client] = false;
					}
				}
			}
				
			CloseHandle(qPlayerUpdateData);
			SQL_UnlockDatabase(DBEventDatabase);
		}	
	}
	/*
	else
	{
		PrintToServer("something went wrong, oops");
	}
	*/
}

stock void DogeballEvent_Connect()
{
	if (DBEventDatabase != INVALID_HANDLE)
	{
		CloseHandle(g_hLoadout);
		g_hLoadout = INVALID_HANDLE;
	}
	
	if (DBEventDatabase == INVALID_HANDLE)
	{
		SQL_TConnect(Loadout_Event_Dodgeball_Connect, "loadout");
	}
}

public Action TimerReconnect(Handle hTimer)
{
	if (g_hLoadout == INVALID_HANDLE)
	{
		DogeballEvent_Connect();
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