#include <sourcemod> 
#include <sdktools>
#include <sdkhooks>
#include <morecolors>
#include <tf2_stocks>
#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.01"

/*
(Done) - Command for admins to manually start the frog hunt
(Done) - Once the frog hunt starts, a chat message should appear in green text saying "The Hunt is on!"
(Done) - If it is possible, make another chat message appear after 2 minutes with a tip for each specific frog if it isnt found after 2 minutes.
(Done, you can configure this on data/frogpositions.txt and supports up to 64 frogs)- Each map will have 16 Frog locations.
(Done) - If a player shoots a frog with bullets, the frog will be awarded to them and it will be announced in chat via this message: "<Player> found the Frog! A new frog will appear shortly."
(Done) - Each frog spawns after 20 seconds so players can collect themselves, banter etc.
(Done) - Once all the frogs are found, a chat message should appear announcing the winner and his amount of frogs. Directly: "The Hunt is over! Top 2 Players, <Player1>: <P1 Frogs>, <Player2>: <P2 Frogs> - We will switch the map shortly!"
(Not like the plugin would self-destruct otherwise...) - Once we are on a new map, admins can just start the event again.
(Done) - Perhaps a command to end the event manually if players are too stupid.
(Done) - Once the hunt starts, Truce should be enabled. Once it ends, it should be disabled.
(Done) - I'll give you the exact coordinates of each frog for each map and a tip for each one.
(Done) - Hide frogs to spectators so people cant cheese it
*/

// Plugin convars
ConVar g_FrogOffsetPosition;
ConVar g_FrogSpawnAfterFinding;
ConVar g_FrogTipTimeOnSpawn;
ConVar g_FrogInvisOnSpec;

// Global variables
int FrogHuntMaxNumberOfFrogs = -1; // Max number of frogs loaded
bool FrogHuntCurrentFrogActive[64] = false; // Is this frog active?
float FrogHuntPosition[64][3]; // Position of the frog.
float FrogHuntRotation[64][3]; // Rotation of the frog.
char FrogHuntTip[64][255]; // Tip given for a position of each frog.
int FrogHunt_FrogEntity = -1; // Entity index that is the frog

bool FrogHuntIsEnabled = false; // Is the frog hunt event enabled?
int FrogHuntFrogProgress = -1; // Counts the current progress on finding the frogs.
int FrogHunt_PlayerScore[MAXPLAYERS+1] = 0; // Players' score when the hunt is enabled

bool IsTruceEnabled = false; // Truce boolean

// Keyvalue handles
Handle g_hKeyvaluesFrogFile = INVALID_HANDLE; // Keyvalues file containing the position and rotation of the frogs
// Timer handles
Handle Timer_FrogSpawn = INVALID_HANDLE;
Handle Timer_FrogTip = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Facepunch's Frog Hunt Event",
	author = "JugadorXEI",
	description = "People hunt for frogs. Yeah that's the gist of it.",
	version = PLUGIN_VERSION,
	url = "jugfix.me",
}

public void OnPluginStart()
{
	// We tell the admin the plugin's enabled
	PrintToServer("Frog Hunt Event (version %s) has loaded successfully.", PLUGIN_VERSION);
	
	// We hook the spawn (for truce)
	HookEvent("player_spawn", Event_PlayerSpawn);
	// We hook getting your stuff in lol
	HookEvent("post_inventory_application", Event_PlayerSpawn);
	
	// We hook the round start event
	HookEvent("teamplay_round_start", Event_RoundStart);
	
	// Convars
	g_FrogOffsetPosition = CreateConVar("sm_froghunt_enableheightoffset", "0", "Spawns all props 20 Hammer units below the ground. This is to fix a bug with prop positions.");
	g_FrogSpawnAfterFinding = CreateConVar("sm_froghunt_frogspawn_cooldown", "20.0", "On start and after a frog has been shot, spawn the next one after this many seconds.");
	g_FrogTipTimeOnSpawn = CreateConVar("sm_froghunt_frogspawn_tiptime", "90.0", "If a frog has been alive for this many seconds, display a tip on the chat (key: 'tip' with text on frogpositions.txt)");
	g_FrogInvisOnSpec = CreateConVar("sm_froghunt_invis_on_spec", "1", "If enabled, the frogs will be invisible to any players who are in spectator.");
	
	// Commands
	RegAdminCmd("sm_froghunt", FrogHunt_Toggle, ADMFLAG_CHANGEMAP, "Toggles on and off the Frog Hunt event.");
	RegAdminCmd("sm_froghunt_toggle", FrogHunt_Toggle, ADMFLAG_CHANGEMAP, "Toggles on and off the Frog Hunt event.");
	RegAdminCmd("sm_froghunt_refreshpositions", FrogHunt_RefreshPositions, ADMFLAG_CHANGEMAP,
	"Refreshes the frog positions without having to change the map. May cause a server hiccup as it reads through the file again.");
	
	RegAdminCmd("sm_froghunt_debug_spawnfrog", FrogHunt_Debug_SpawnFrog, ADMFLAG_ROOT,
	"Spawns a frog through an index in its predefined position and rotation and will behave like a normal frog, but score won't count and a tip won't appear. Type 'all' as the argument to spawn all frogs.");
}

public void OnMapStart()
{
	RefreshFrogPositions(); // We get the frog positions from frogpositions.txt
	
	ResetFrogHuntScores(); // We reset player scores
	ResetFrogHuntPositionActivity(); // We reset the position activity of each frog
	
	// Precaching the frog model:
	PrecacheModel("models/props_2fort/frog.mdl", true);
	
	// We're precaching a few birthday sounds, acting as hitsounds for the frogs.
	for (int i = 11; i < 17; i++)
	{
		char cSoundPath[128];
		Format(cSoundPath, sizeof(cSoundPath), "misc/happy_birthday_tf_%i.wav", i);
		
		PrecacheSound(cSoundPath, true);
	}
	
	// Some extra sounds for when the event starts and ends.
	PrecacheSound("ui/duel_challenge.wav", true);  // start
	PrecacheSound("ui/duel_event.wav", true); // stop
	PrecacheSound("ui/item_acquired.wav", true); // frog spawn
	PrecacheSound("ui/duel_challenge_rejected_with_restriction.wav", true); // skip
	
	PrecacheSound("misc/your_team_stalemate.wav", true); // stalemate
	PrecacheSound("misc/your_team_won.wav", true); // win
	PrecacheSound("misc/your_team_lost.wav", true); // lose
}


public Handle CreatePositionsFile(Handle hFile)
{
	if (hFile == INVALID_HANDLE)
	{
		hFile = CreateKeyValues("frogpositions"); // Keyvalues bois

		char cData[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, cData, PLATFORM_MAX_PATH, "data/frogpositions.txt"); // tf/addons/sourcemod/data/frogpositions.txt

		FileToKeyValues(hFile, cData);
	}
	return hFile;
}

public bool GetAndStoreFrogPositions()
{
	g_hKeyvaluesFrogFile = CreatePositionsFile(g_hKeyvaluesFrogFile);
	if (g_hKeyvaluesFrogFile == INVALID_HANDLE) return false;

	char cName[255], cMapname[32], cDisplayName[32]; // Name of section, and map(s).
	GetCurrentMap(cMapname, sizeof(cMapname));
	GetMapDisplayName(cMapname, cDisplayName, sizeof(cDisplayName));
	KvRewind(g_hKeyvaluesFrogFile); // We go to the top node, woo.
	KvGotoFirstSubKey(g_hKeyvaluesFrogFile, false); // We go to the first subkey (which should be a map name)
	
	// Let's get riiiiiiiiiiiight into the maaaaaaps.
	do
	{
		KvGetSectionName(g_hKeyvaluesFrogFile, cName, sizeof(cName));
		//PrintToServer("%s = %s", cName, cDisplayName);
		
		if (StrEqual(cDisplayName, cName, false)) // If we have positions set for the current map...
		{
			PrintToServer("Frog Hunt Event: There's frog positions set for %s, storing them...", cName);
			FrogHuntMaxNumberOfFrogs = 0;
			
			KvGotoFirstSubKey(g_hKeyvaluesFrogFile, false); // This should be the first frog position
			
			do
			{
				FrogHuntPosition[FrogHuntMaxNumberOfFrogs][0] = KvGetFloat(g_hKeyvaluesFrogFile, "x", 0.0);
				FrogHuntPosition[FrogHuntMaxNumberOfFrogs][1] = KvGetFloat(g_hKeyvaluesFrogFile, "y", 0.0);
				FrogHuntPosition[FrogHuntMaxNumberOfFrogs][2] = KvGetFloat(g_hKeyvaluesFrogFile, "z", 0.0);
				FrogHuntRotation[FrogHuntMaxNumberOfFrogs][0] = KvGetFloat(g_hKeyvaluesFrogFile, "pitch", 0.0);
				FrogHuntRotation[FrogHuntMaxNumberOfFrogs][1] = KvGetFloat(g_hKeyvaluesFrogFile, "yaw", 0.0);
				FrogHuntRotation[FrogHuntMaxNumberOfFrogs][2] = KvGetFloat(g_hKeyvaluesFrogFile, "roll", 0.0);
				char cTip[128]; KvGetString(g_hKeyvaluesFrogFile, "tip", cTip, sizeof(cTip), "");
				strcopy(FrogHuntTip[FrogHuntMaxNumberOfFrogs], sizeof(FrogHuntTip), cTip);
				
				/*
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "x", 0.0));
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "y", 0.0));
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "z", 0.0));
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "pitch", 0.0));
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "yaw", 0.0));
				PrintToServer("%f", KvGetFloat(g_hKeyvaluesFrogFile, "roll", 0.0));
				char cTipDebug[128];
				KvGetString(g_hKeyvaluesFrogFile, "tip", cTipDebug, sizeof(cTipDebug), "");
				PrintToServer("%s", cTipDebug);
				PrintToServer("%i", FrogHuntMaxNumberOfFrogs);
				*/
				
				FrogHuntMaxNumberOfFrogs++;
			}
			while (KvGotoNextKey(g_hKeyvaluesFrogFile, false));
			
			return true;
		}
	}
	while (KvGotoNextKey(g_hKeyvaluesFrogFile, false));
	
	return false;
}

public Action FrogHunt_Toggle(int iClient, int iArgs)
{
	if (FrogHuntMaxNumberOfFrogs > 0) ToggleFrogHunt();
	else ReplyToCommand(iClient, "You need to set up frog positions in data/frogpositions.txt before you can start the event!");
	
	return Plugin_Handled;
}

public Action FrogHunt_RefreshPositions(int iClient, int iArgs)
{
	RefreshFrogPositions();
	ReplyToCommand(iClient, "Refreshed all frog positions.");
	LogAction(iClient, -1, "Frog Hunt Event: %L refreshed the frog positions.", iClient);
	
	return Plugin_Handled;
}

public Action FrogHunt_Debug_SpawnFrog(int iClient, int iArgs)
{
	if (iArgs < 1)
	{
		ReplyToCommand(iClient, "Usage: sm_froghunt_debug_spawnfrog <0-63 if available | 'all' to spawn all frogs>");
		return Plugin_Handled;
	}
	
	char cIndex[32]; 
	GetCmdArg(1, cIndex, sizeof(cIndex));
	int iIndex = StringToInt(cIndex);
	
	if (FrogHuntMaxNumberOfFrogs == -1)
	{
		ReplyToCommand(iClient, "There's no frog positions set on this map. Input at least one position in data/frogpositions.txt, and refresh the list using sm_froghunt_refreshpositions or refreshing the map.");
		return Plugin_Handled;
	}
	else if (iIndex > FrogHuntMaxNumberOfFrogs-1)
	{
		ReplyToCommand(iClient, "There's no frog position set in this index. Try a lower number.");
		return Plugin_Handled;
	}
	else if (StrEqual(cIndex, "all", false))
	{
		for (int i = 0; i <= FrogHuntMaxNumberOfFrogs; i++)
		{
			SpawnFrogObjective(FrogHuntPosition[i], FrogHuntRotation[i], true);
		}
		LogAction(iClient, -1, "Frog Hunt Event: %L spawned all debug frogs in the map.", iClient);
	}
	else
	{
		SpawnFrogObjective(FrogHuntPosition[iIndex], FrogHuntRotation[iIndex], true);
		LogAction(iClient, -1, "Frog Hunt Event: %L spawned a debug frog (%i).", iClient, iIndex);
		// PrintToServer("%f %f %f", FrogHuntPosition[iIndex][0], FrogHuntPosition[iIndex][1], FrogHuntPosition[iIndex][2]);
	}

	return Plugin_Handled;
}

stock int SpawnFrogObjective(float pos[3], float ang[3], bool Debug = false)
{
	int iFrogIndex = CreateEntityByName("prop_dynamic"); // prop entity boys
	bool AdjustOffset = GetConVarBool(g_FrogOffsetPosition);
	
	if (iFrogIndex > 0 && IsValidEntity(iFrogIndex))
	{				
		// Froggy keys
		DispatchKeyValue(iFrogIndex, "model", "models/props_2fort/frog.mdl"); // We change the entity's model to be a frog
		DispatchKeyValue(iFrogIndex, "targetname", "froggy_eventplugin");
		DispatchKeyValue(iFrogIndex, "rendercolor", "255 192 203"); // Pink froggy
		DispatchKeyValue(iFrogIndex, "solid", "2"); // Using bounding box for collision (else it doesn't work at all)
		DispatchKeyValue(iFrogIndex, "health", "10"); // 10 hp
		
		if (Debug) HookSingleEntityOutput(iFrogIndex, "OnTakeDamage", FrogBreakDebug, true);
		else HookSingleEntityOutput(iFrogIndex, "OnTakeDamage", FrogBreak, true);
		
		// Here we spawn the frog
		DispatchSpawn(iFrogIndex);
		
		if (AdjustOffset) pos[2] -= 20.0;
		
		// This teleports the frog in position
		TeleportEntity(iFrogIndex, pos, ang, NULL_VECTOR);
		//PrintToServer("froggy spawned");
		
		SDKHook(iFrogIndex, SDKHook_SetTransmit, OnSetTransmit_NoSpectatorCheesing);
		
		return iFrogIndex;
	}
	
	return -1;
}

public void FrogBreak(const char[] cOutput, int iCaller, int iActivator, float fDelay)
{
	if (IsValidClient(iActivator))
	{
		// Frog's position
		float fPosition[3];
		GetEntPropVector(iCaller, Prop_Send, "m_vecOrigin", fPosition);
		
		// Confetti! :D
		TE_Particle("bday_confetti", fPosition);
		
		// Birthday sounds!
		char cSoundPath[128];
		Format(cSoundPath, sizeof(cSoundPath), "misc/happy_birthday_tf_%i.wav", GetRandomInt(11, 16));
		
		// We emit the sound here
		EmitSoundToAll(cSoundPath, iCaller);
		
		// We add score to the lucky fellow.
		FrogHunt_PlayerScore[iActivator]++;
		CPrintToChatAllEx(iActivator, "{teamcolor}%N {default}has found the frog and obtained one point!", iActivator);
		CPrintToChatEx(iActivator, iActivator, "You have found {yellow}%i {default}frogs so far!", FrogHunt_PlayerScore[iActivator]);
		
		// We set the current, destroyed frog, as inactive now.
		FrogHuntCurrentFrogActive[FrogHuntFrogProgress] = false;
		
		// We increase the progress (aka onto the next frog).
		FrogHuntFrogProgress++; 
		
		// If the game is over, we call in the winners.
		if (FrogHuntFrogProgress > FrogHuntMaxNumberOfFrogs - 1)
		{
			// - Once all the frogs are found, a chat message should appear announcing the winner and his amount of frogs. Directly: "The Hunt is over! Top 2 Players, <Player1>: <P1 Frogs>, <Player2>: <P2 Frogs> - We will switch the map shortly!"
			CPrintToChatAll("It's hunt is over!");
			DeclareWinners();

			FrogHuntIsEnabled = false; // We disable the event
			FrogHuntFrogProgress = -1; // We reset the counter
			
			ToggleTruce(false);
			
			ResetFrogHuntScores(); // We reset the scores
			ResetFrogHuntPositionActivity(); // We reset the position activity of each frog
		}
		else // Else, we spawn the next frog on a timer.
		{
			PrintToChatAll("The next frog will appear in %0.1f seconds!", GetConVarFloat(g_FrogSpawnAfterFinding));
			Timer_FrogSpawn = CreateTimer(GetConVarFloat(g_FrogSpawnAfterFinding), TimerFunc_SpawnFrog, _, TIMER_FLAG_NO_MAPCHANGE);
		}
		
		// We reset the frog tip timer
		if (Timer_FrogTip != INVALID_HANDLE)
		{
			CloseHandle(Timer_FrogTip);
			Timer_FrogTip = INVALID_HANDLE;
		}
		
		// We remove the no cheese hook (technically not necessary?)
		SDKUnhook(iCaller, SDKHook_SetTransmit, OnSetTransmit_NoSpectatorCheesing);
		
		// The marked entity shouldn't exist now
		FrogHunt_FrogEntity = -1;
		
		// We break the prop
		AcceptEntityInput(iCaller, "Break");
	}
}

// Copy of FrogBreak without scoring.
public void FrogBreakDebug(const char[] cOutput, int iCaller, int iActivator, float fDelay)
{
	if (IsValidClient(iActivator))
	{
		// Name of entities
		/*
		char cTriggerName[64];
		GetEntPropString(iCaller, Prop_Data, "m_iName", cTriggerName, sizeof(cTriggerName));
		*/

		float fPosition[3];
		GetEntPropVector(iCaller, Prop_Send, "m_vecOrigin", fPosition);
		
		TE_Particle("bday_confetti", fPosition);
		
		char cSoundPath[128];
		Format(cSoundPath, sizeof(cSoundPath), "misc/happy_birthday_tf_%i.wav", GetRandomInt(11, 16));
		
		EmitSoundToAll(cSoundPath, iCaller);
		SDKUnhook(iCaller, SDKHook_SetTransmit, OnSetTransmit_NoSpectatorCheesing);
		
		AcceptEntityInput(iCaller, "Break");
		
		//PrintToServer("cTriggername: %s\ncOutput: %s\niCaller: %i\niActivator: %N", cTriggerName, cOutput, iCaller, iActivator);
	}
}

// If the player disconnects, we reset their points
public void OnClientDisconnect(int iClient)
{
	if (IsValidClient(iClient))
	{
		FrogHunt_PlayerScore[iClient] = 0;
	}
}

public void ToggleFrogHunt()
{
	if (!FrogHuntIsEnabled) // If the frog hunt isn't enabled
	{
		FrogHuntIsEnabled = true; // Is the frog hunt event enabled?
		FrogHuntFrogProgress = 0; // Counts the current progress on finding the frogs.
		
		// We tell the players the event started
		CPrintToChatAll("{green}The hunt is on!\n{default}Find and shoot as many frogs as you can to increase your score. Get the highest score to win!\nThe first frog will spawn in %0.1f seconds. Good luck!",
		GetConVarFloat(g_FrogSpawnAfterFinding));
		EmitSoundToAll("ui/duel_challenge.wav");
		
		// We remove every pyro's primaries so they don't airblast around
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i)) RemovePyroPrimary(i);
		}
		
		// We set truce on:
		ToggleTruce(true);
		
		// We spawn the first frog:
		Timer_FrogSpawn = CreateTimer(GetConVarFloat(g_FrogSpawnAfterFinding), TimerFunc_SpawnFrog, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else // if the frog hunt is enabled and we want to disable it
	{
		// We tell the players about it
		CPrintToChatAll("{red}The frog hunt has been stopped by an admin!");
		DeclareWinners();
		
		FrogHuntIsEnabled = false; // We disable the event
		FrogHuntFrogProgress = -1; // We reset the counter
		
		ClearCurrentFrog(); // We clear the current active frog
		
		ResetFrogHuntScores(); // We reset the scores
		ResetFrogHuntPositionActivity(); // We reset the position activity of each frog
		
		// We reset the frog spawn timer
		if (Timer_FrogSpawn != INVALID_HANDLE)
		{
			CloseHandle(Timer_FrogSpawn);
			Timer_FrogSpawn = INVALID_HANDLE;
		}
		
		// We reset the frog tip timer
		if (Timer_FrogTip != INVALID_HANDLE)
		{
			CloseHandle(Timer_FrogTip);
			Timer_FrogTip = INVALID_HANDLE;
		}
		
		// We set truce off:
		ToggleTruce(false);
		EmitSoundToAll("ui/duel_event.wav");
	}
}

public Action TimerFunc_SpawnFrog(Handle timer, any data)
{
	if (FrogHuntIsEnabled)
	{
		FrogHuntCurrentFrogActive[FrogHuntFrogProgress] = true;
		
		PrintToChatAll("A new frog has spawned! Find it before anybody else does!\nFrog progress: %i/%i.", FrogHuntFrogProgress + 1, FrogHuntMaxNumberOfFrogs);
		FrogHunt_FrogEntity = SpawnFrogObjective(FrogHuntPosition[FrogHuntFrogProgress], FrogHuntRotation[FrogHuntFrogProgress]);
		
		EmitSoundToAll("ui/item_acquired.wav");
		
		Timer_FrogTip = CreateTimer(GetConVarFloat(g_FrogTipTimeOnSpawn), TimerFunc_FrogTip, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	
	Timer_FrogSpawn = INVALID_HANDLE;
}

public Action TimerFunc_FrogTip(Handle timer, any data)
{
	if (FrogHuntIsEnabled)
	{
		if (FrogHuntCurrentFrogActive[FrogHuntFrogProgress] == true)
		{
			char cTipMessage[255];
			
			switch (GetRandomInt(1, 3))
			{
				case 1: Format(cTipMessage, sizeof(cTipMessage), "You overhear something: {lightyellow}%s",  FrogHuntTip[FrogHuntFrogProgress]);
				case 2: Format(cTipMessage, sizeof(cTipMessage), "Here's a tip for you: {lightyellow}%s",  FrogHuntTip[FrogHuntFrogProgress]);
				case 3: Format(cTipMessage, sizeof(cTipMessage), "I hope this helps you: {lightyellow}%s",  FrogHuntTip[FrogHuntFrogProgress]);
			}
		
			CPrintToChatAll(cTipMessage);
			EmitSoundToAll("ui/item_acquired.wav");
		}
	}
	
	Timer_FrogTip = INVALID_HANDLE;
}

// Refreshes the positions of the frogs.
public void RefreshFrogPositions()
{
	FrogHuntFrogProgress = -1;
	FrogHuntMaxNumberOfFrogs = -1;
	FrogHuntIsEnabled = false;
	
	IsTruceEnabled = false;
	
	// We close the keyvalues handle so it refreshes when we get for the positions again.
	if (g_hKeyvaluesFrogFile != INVALID_HANDLE)
	{
		CloseHandle(g_hKeyvaluesFrogFile);
		g_hKeyvaluesFrogFile = INVALID_HANDLE;
	}

	GetAndStoreFrogPositions(); // We get the current froggy positions.
}

// Prevents the frog from being drawn if the player is in spectator
public Action OnSetTransmit_NoSpectatorCheesing(int iEntity, int iClient)
{
	// Is the client valid? Is the entity valid?
	if (!IsValidClient(iClient) || !IsValidEntity(iEntity)) return Plugin_Continue; 
	
	// Is the player on spectator? Is the convar enabled?
	if (GetEntProp(iClient, Prop_Send, "m_iObserverMode") > 0 && GetConVarInt(g_FrogInvisOnSpec) > 0)
	{
		//PrintToServer("%N can't see me", iClient);
		return Plugin_Handled; // Can't be seen
	}

	return Plugin_Continue; // Can be seen
}

public void DeclareWinners()
{
	if (FrogHuntIsEnabled)
	{
		// First place: score and id on the server
		int iFirstPlace = -1;
		int iFirstPlaceID = -1;
		
		// Second place: score and id on the server
		int iSecondPlace = -1;
		int iSecondPlaceID = -1;
		
		int iNumberBuffer = -1;
		
		// We get the first place guy.
		for (int i = 1; i <= MaxClients; i++)
		{
			if (FrogHunt_PlayerScore[i] > iNumberBuffer)
			{
				iNumberBuffer = FrogHunt_PlayerScore[i];
				
				iFirstPlace = FrogHunt_PlayerScore[i];
				iFirstPlaceID = i;
			}
		}
		
		iNumberBuffer = -1;
		
		// Then we get the second place guy.
		for (int i = 1; i <= MaxClients; i++)
		{
			if (FrogHunt_PlayerScore[i] <= iFirstPlace && iFirstPlaceID != i)
			{	
				iSecondPlace = FrogHunt_PlayerScore[i];
				iSecondPlaceID = i;
			}
		}
		
		if (iFirstPlace == 0 && iSecondPlace == 0)
		{
			CPrintToChatAll("{red}Nobody {default}wins! ...Really?");
			EmitSoundToAll("misc/your_team_lost.wav");
		}
		else if (iFirstPlace == iSecondPlace && iFirstPlaceID != iSecondPlaceID)
		{
			if (IsValidClient(iFirstPlaceID) && IsValidClient(iSecondPlaceID))
			{
				CPrintToChatAll("It's a {red}tie {default}between {yellow}%N{default} and {yellow}%N{default} with {yellow}%i{default} points!", iFirstPlaceID, iSecondPlaceID, iFirstPlace);
				EmitSoundToAll("misc/your_team_stalemate.wav");
			}
		}
		else
		{
			if (IsValidClient(iFirstPlaceID))
			{
				CPrintToChatAllEx(iFirstPlaceID, "Your {yellow}winner {default}is {teamcolor}%N {default}with {yellow}%i {default}frogs!", iFirstPlaceID, iFirstPlace);
			}
			
			if (IsValidClient(iSecondPlaceID) && iSecondPlaceID != iFirstPlaceID)
			{
				CPrintToChatAllEx(iSecondPlaceID, "The follow-up is {teamcolor}%N {default}with {yellow}%i {default}frogs!", iSecondPlaceID, iSecondPlace);
			}
			
			EmitSoundToAll("misc/your_team_won.wav");
		}
		
		PrintToChatAll("The map will be changed shortly!");
		//PrintToChatAll("%i %i - %i %i", iFirstPlaceID, iFirstPlace, iSecondPlaceID, iSecondPlace);
	}
}

public void ResetFrogHuntScores() // Resets the scores of everyone.
{
	for (int i = 1; i <= MaxClients; i++)
	{
		FrogHunt_PlayerScore[i] = 0;
	}
}

public void ResetFrogHuntPositionActivity() // Resets the scores of everyone.
{
	for (int i = 0; i <= 63; i++)
	{
		FrogHuntCurrentFrogActive[i] = false;
	}
}

stock void ToggleTruce(bool Toggle)
{
	int iTimerEntity = -1;
	int iTriggerAreaEntity = -1;
	
	if (Toggle)
	{
		IsTruceEnabled = true;
		
		// We pause the timer if there's any
		while ((iTimerEntity = FindEntityByClassname(iTimerEntity, "team_round_timer")) != -1)
		{
			AcceptEntityInput(iTimerEntity, "Pause");
		}
		
		// We disable all capture points and payload
		while ((iTriggerAreaEntity = FindEntityByClassname(iTriggerAreaEntity, "trigger_capture_area")) != -1)
		{
			AcceptEntityInput(iTriggerAreaEntity, "Disable");
		}
		
		// We give the players damage hooks so they can't damage other people but themselves (for rocketjumping and what not).
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				SDKHook(i, SDKHook_OnTakeDamage, Truce_NoDamage);
			}
		}
	}
	else
	{
		IsTruceEnabled = false;
	
		// We resume the timer
		while ((iTimerEntity = FindEntityByClassname(iTimerEntity, "team_round_timer")) != -1)
		{
			AcceptEntityInput(iTimerEntity, "Resume");
		}
		
		// We enable the CPs again
		while ((iTriggerAreaEntity = FindEntityByClassname(iTriggerAreaEntity, "trigger_capture_area")) != -1)
		{
			AcceptEntityInput(iTriggerAreaEntity, "Enable");
		}
		
		// We remove the hooks;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				SDKUnhook(i, SDKHook_OnTakeDamage, Truce_NoDamage);
			}
		}
	}

}

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (IsValidClient(iClient))
	{	
		if (IsTruceEnabled && IsPlayerAlive(iClient))
		{
			RemovePyroPrimary(iClient);
		
			if (StrEqual(cName, "player_spawn", false)) SDKHook(iClient, SDKHook_OnTakeDamage, Truce_NoDamage);
		}
	}
}

public Action Truce_NoDamage(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, int &iDamageType, int &iWeapon, float vDamageForce[3], float vDamagePos[3], int iDamageCustom)
{
	// We prevent players from attacking other people by setting damage to 0 and scaling knockback to zero.
	if (IsValidClient(iAttacker) && iAttacker != iVictim)
	{
		fDamage = 0.0;
		ScaleVector(vDamageForce, 0.0);
	}
	
	return Plugin_Changed;
}

public Action Event_RoundStart(Handle hEvent, const char[] cName, bool dontBroadcast)
{	
	if (FrogHuntIsEnabled)
	{
		RefreshFrogPositions(); // We get the frog positions from frogpositions.txt
	
		ResetFrogHuntScores(); // We reset player scores
		ResetFrogHuntPositionActivity(); // We reset the position activity of each frog
	}
}

public void ClearCurrentFrog()
{
	if (FrogHunt_FrogEntity != -1 && IsValidEntity(FrogHunt_FrogEntity))
	{
		// We remove the no cheese hook (technically not necessary?)
		SDKUnhook(FrogHunt_FrogEntity, SDKHook_SetTransmit, OnSetTransmit_NoSpectatorCheesing);
		
		// We break the prop
		AcceptEntityInput(FrogHunt_FrogEntity, "Break");
		
		FrogHunt_FrogEntity = -1;
	}
}

// From https://forums.alliedmods.net/showthread.php?t=75102 by L. Duke but written to use newdecls. It creates particles.
stock void TE_Particle(char[] cName, float origin[3] = NULL_VECTOR, float start[3] = NULL_VECTOR, float angles[3] = NULL_VECTOR,
int entindex = -1, int attachtype = -1, int attachpoint = -1, bool resetParticles = true, float delay = 0.0)
{
	// find string table
	int tblidx = FindStringTable("ParticleEffectNames");
	if (tblidx == INVALID_STRING_TABLE) 
	{
		LogError("Could not find string table: ParticleEffectNames");
		return;
	}
	
	// find particle index
	char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	
	for (int i = 0; i < count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, cName, false))
		{
			stridx = i;
			break;
		}
	}
	if (stridx == INVALID_STRING_INDEX)
	{
		LogError("Could not find particle: %s", cName);
		return;
	}
	
	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", origin[0]);
	TE_WriteFloat("m_vecOrigin[1]", origin[1]);
	TE_WriteFloat("m_vecOrigin[2]", origin[2]);
	TE_WriteFloat("m_vecStart[0]", start[0]);
	TE_WriteFloat("m_vecStart[1]", start[1]);
	TE_WriteFloat("m_vecStart[2]", start[2]);
	TE_WriteVector("m_vecAngles", angles);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
   
	if (entindex != -1)
	{
		TE_WriteNum("entindex", entindex);
	}
	
	if (attachtype != -1)
	{
		TE_WriteNum("m_iAttachType", attachtype);
	}
   
	if (attachpoint != -1)
	{
		TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
	}
	
	TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);	
	TE_SendToAll(delay);
}

public void RemovePyroPrimary(int iClient)
{
	// We remove the Pyro's primary so they don't airblast around.
	if (TF2_GetPlayerClass(iClient) == TFClass_Pyro)
	{
		TF2_RemoveWeaponSlot(iClient, TFWeaponSlot_Primary);
		
		int iMelee = GetPlayerWeaponSlot(iClient, 2);
		// Makes it so players switch to melee (aka not going as civs)
		SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iMelee);
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