#include <sourcemod>
#include <sdkhooks>
#include <discord>
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "Discord Chat Logging",
	author = "JugadorXEI",
	description = "Grabs the server's chat and puts it in a Discord channel. Useful for logging.",
	version = "1.0",
	url =  "",
}

ConVar g_DiscordLogEnable; // Enable or disable the plugin?
ConVar g_DiscordLogChannel; // What channel do we wanna log the chat in?
ConVar g_DiscordLogNextMap; // Should the next map be logged?
//ConVar g_DiscordLogCurrentMap; // Should the current map be logged?
char ChatLogChannel[32];
char FullChatLog[255]; 
char MessageLogToDiscord[255];

public void OnPluginStart()
{
	HookEvent("player_say", DiscordChatLog);
	HookEvent("server_cvar", DiscordNextMapLog);
	//HookEvent("server_spawn", DiscordCurrentMapLog);
	
	g_DiscordLogEnable = CreateConVar("discord_logs_enable", "1", "Enables or disables the plugin. 0 = Disable. 1 = Enable.");
	g_DiscordLogChannel = CreateConVar("discord_logs_channel", "default", "Sets what channel to log the chat to through webhook (check configs/discord.cfg)");
	g_DiscordLogNextMap = CreateConVar("discord_logs_nextmap", "1", "Sets if the nextmap should be logged or not. 0 = Disable. 1 = Enable.");
	//g_DiscordLogCurrentMap = CreateConVar("discord_logs_currentmap", "1", "Sets if the current map should be logged or not. Handy for classification. 0 = Disable. 1 = Enable.");
}

public Action DiscordChatLog(Handle hEvent, const char[] name, bool dontBroadcast)
{	
	bool DiscordLogsEnable = GetConVarBool(g_DiscordLogEnable);

	if(DiscordLogsEnable == true)
	{
		int chatUser = GetClientOfUserId(GetEventInt(hEvent, "userid"));
		//char chatName[64]; GetClientName(chatUser, chatName, sizeof(chatName));
		GetConVarString(g_DiscordLogChannel, ChatLogChannel, sizeof(ChatLogChannel));
		char chatMessage[255]; GetEventString(hEvent, "text", chatMessage, sizeof(chatMessage));
		char strTime[64]; FormatTime(strTime, sizeof(strTime), "%d-%m-%y %H:%M", GetTime());
	
		// This is this message that gets sent to the Discord chat channel.
		Format(MessageLogToDiscord, sizeof(MessageLogToDiscord), "```[%s] %L: %s```", strTime, chatUser, chatMessage);
		StrCat(FullChatLog, sizeof(FullChatLog), MessageLogToDiscord);
		
		CreateTimer(10.0, DiscordLog, _, TIMER_REPEAT);
	}
}

public Action DiscordLog(Handle timer)
{
	int iLength = strlen(FullChatLog);
	if (iLength > 1)
	{
		SendMessageToDiscord(ChatLogChannel, FullChatLog);
	}
	
	FullChatLog = "";
	iLength = 0;
}

public Action DiscordNextMapLog(Handle hEvent, const char[] name, bool dontBroadcast)
{
	bool DiscordLogsNextMap = GetConVarBool(g_DiscordLogNextMap);
	
	if(DiscordLogsNextMap == true)
	{
		char isItNextMap[32]; GetEventString(hEvent, "cvarname", isItNextMap, sizeof(isItNextMap));
		char newNextLevel[255]; GetEventString(hEvent, "cvarvalue", newNextLevel, sizeof(newNextLevel));
		GetConVarString(g_DiscordLogChannel, ChatLogChannel, sizeof(ChatLogChannel));
		bool IsItNextLevel = StrEqual(isItNextMap, "nextlevel", false);
		bool IsNextLevelBlank = StrEqual(newNextLevel, "", false);
		
		if(IsItNextLevel == true)
		{
			if(IsNextLevelBlank == false)
			{
				char NextMapLogToDiscord[255];
				Format(NextMapLogToDiscord, sizeof(NextMapLogToDiscord), "--- **The new map has been selected and will be `%s`!** ---", newNextLevel);
				
				SendMessageToDiscord(ChatLogChannel, NextMapLogToDiscord);
			}
		}
	}
}