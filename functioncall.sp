#include <sourcemod>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "v0.1"

#define FUNC_NUMBEROFPARAMS 9

public Plugin myInfo =
{
	name = "Function Call From Another Plugin",
	author = "JugadorXEI",
	description = "Allows you to call functions from other plugins",
	version = PLUGIN_VERSION,
	url = "https://github.com/JugadorXEI",
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_callfunction", Command_CallFunction, ADMFLAG_ROOT,
		"Calls a function from another plugin.");
}

public Action Command_CallFunction(int iClient, int iArgs)
{
	if (iArgs < 2)
	{
		ReplyToCommand(iClient, "Usage: sm_callfunction [Plugin Name] "
		... "[Function Name] (Optional:) [Param1] [Param2] ...");
		return Plugin_Handled;
	}
	
	char cPluginName[64], cFunctionName[128], cParams[FUNC_NUMBEROFPARAMS][64];
	any aParams[FUNC_NUMBEROFPARAMS];
	
	int iNumOfParams = 0; 
	any aResult = -1;
	
	Handle hPluginToCall = INVALID_HANDLE;
	Function fFunctionToCall = INVALID_FUNCTION;
	
	for (int i = 1; i <= iArgs; i++)
	{
		switch (i)
		{
			// Plugin Name
			// This will (or should always be) a string being
			// the plugin's name.
			case 1:
			{
				GetCmdArg(i, cPluginName, sizeof(cPluginName));
				hPluginToCall = FindPluginByFile(cPluginName);
				
				if (hPluginToCall == INVALID_HANDLE)
				{
					ReplyToCommand(iClient,
						"The plugin that is trying to be called does not exist.");
					return Plugin_Handled;
				}
			}
			// Function Name
			case 2:
			{
				GetCmdArg(i, cFunctionName, sizeof(cFunctionName));
				fFunctionToCall = GetFunctionByName(hPluginToCall, cFunctionName);
				
				if (fFunctionToCall == INVALID_FUNCTION)
				{
					ReplyToCommand(iClient,
						"The function that is being attempted to be called from the plugin "
						...	"does not exist.");
					return Plugin_Handled;
				}
			}
			// Rest of parameters.
			default:
			{
				// We make sure we're not fitting any more that we can't have.
				if (i > FUNC_NUMBEROFPARAMS)
					break;
				
				// PrintToServer("%i", i);
				// If there's nothing on a param, we assume there's no more parameters.
				if (GetCmdArg(i, cParams[i - 2], sizeof(cParams)) <= 0)
					break;
				
				// PrintToServer(cParams[i - 2]);
					
				iNumOfParams++;
			}
		}
	}
	
	// Now we'll call the function.
	Call_StartFunction(hPluginToCall, fFunctionToCall);
	
	for (int i = 0; i <= iNumOfParams; i++)
	{
		bool bFullStringIsInt = true;
		bool bFullStringIsFloat = true;
		
		// Let's check if this string is an int or float.
		
		// For some reason putting int j = 0 on the for's
		// first statement throws an error. Really cool, Sourcepawn.

		for (int j = 0; j <= strlen(cParams[j]); j++)
		{
			if (!IsCharNumeric(cParams[i][j]))
			{
				bFullStringIsInt = false;
				break;
			}
		}
		
		// If we already know it's an int, let's not check if it's a float.
		if (!bFullStringIsInt)
		{
			// Let's check if this string is a float.
			for (int j = 0; j <= strlen(cParams[i]); j++)
			{
				if (!IsCharNumeric(cParams[i][j]) ||
				!StrEqual(cParams[i][j], "."))
				{
					bFullStringIsFloat = false;
					break;
				}
			}
			
		}
		
		// If it's an int or bool.
		if (bFullStringIsInt)
		{
			aParams[i] = StringToInt(cParams[i]);
			//PrintToServer("%i", aParams[i]);
			Call_PushCell(aParams[i]);
		}
		// If it's a float.
		else if (bFullStringIsFloat)
		{
			aParams[i] = StringToFloat(cParams[i]);
			//PrintToServer("%f", aParams[i]);
			Call_PushFloat(aParams[i]);
		}
		// If it's a string.
		else
		{
			PrintToServer(cParams[i]);
			Call_PushString(cParams[i]);
		}
	}
	
	switch (Call_Finish(aResult))
	{
		case SP_ERROR_NONE:
			ShowActivity2(iClient, "[FunctionCall] ", "Function %s from plugin %s has been called",
			cFunctionName, cPluginName);
		case SP_ERROR_FILE_FORMAT:
			ReplyToCommand(iClient, "[FunctionCall] Unrecognized file format.");
		case SP_ERROR_DECOMPRESSOR:
			ReplyToCommand(iClient, "[FunctionCall] Decompressor not found.");
		case SP_ERROR_HEAPLOW:
			ReplyToCommand(iClient, "[FunctionCall] Not enough space in heap.");
		case SP_ERROR_PARAM:
			ReplyToCommand(iClient, "[FunctionCall] Invalid parameter or parameter type.");
		case SP_ERROR_INVALID_ADDRESS:
			ReplyToCommand(iClient, "[FunctionCall] Invalid memory address.");
		case SP_ERROR_NOT_FOUND:
			ReplyToCommand(iClient, "[FunctionCall] Object not found.");
		case SP_ERROR_INDEX: 
			ReplyToCommand(iClient, "[FunctionCall] Invalid index parameter.");
		case SP_ERROR_STACKLOW:
			ReplyToCommand(iClient, "[FunctionCall] Not enough space in the stack.");
		case SP_ERROR_NOTDEBUGGING:
			ReplyToCommand(iClient, "[FunctionCall] Debug section disabled or not found.");
		case SP_ERROR_INVALID_INSTRUCTION:
			ReplyToCommand(iClient, "[FunctionCall] Encountered invalid instruction.");
		case SP_ERROR_MEMACCESS:
			ReplyToCommand(iClient, "[FunctionCall] Invalid memory access.");
		case SP_ERROR_STACKMIN:
			ReplyToCommand(iClient, "[FunctionCall] Stack went beyond minimum value.");
		case SP_ERROR_HEAPMIN:
			ReplyToCommand(iClient, "[FunctionCall] Heap went beyond minimum value.");
		case SP_ERROR_DIVIDE_BY_ZERO:
			ReplyToCommand(iClient, "[FunctionCall] A division by zero was performed.");
		case SP_ERROR_ARRAY_BOUNDS:
			ReplyToCommand(iClient, "[FunctionCall] Array index is out of bounds.");
		case SP_ERROR_INSTRUCTION_PARAM:
			ReplyToCommand(iClient, "[FunctionCall] Instruction had an invalid parameter.");
		case SP_ERROR_STACKLEAK:
			ReplyToCommand(iClient, "[FunctionCall] A native leaked an item on the stack.");
		case SP_ERROR_HEAPLEAK:
			ReplyToCommand(iClient, "[FunctionCall] A native leaked an item on the heap.");
		case SP_ERROR_ARRAY_TOO_BIG:
			ReplyToCommand(iClient, "[FunctionCall] Dynamic array is too big.");
		case SP_ERROR_TRACKER_BOUNDS:
			ReplyToCommand(iClient, "[FunctionCall] Tracker stack is out of bounds.");
		case SP_ERROR_PARAMS_MAX:
			ReplyToCommand(iClient, "[FunctionCall] Maximum number of parameters reached.");
		case SP_ERROR_NATIVE:
			ReplyToCommand(iClient, "[FunctionCall] Native was pending or invalid.");
		case SP_ERROR_NOT_RUNNABLE:
			ReplyToCommand(iClient, "[FunctionCall] Function or plugin is not runnable..");
		case SP_ERROR_ABORTED:
			ReplyToCommand(iClient, "[FunctionCall] Function call was aborted.");
	}
	
	return Plugin_Handled;
}

// Helps us know if the player counts as valid of not.
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