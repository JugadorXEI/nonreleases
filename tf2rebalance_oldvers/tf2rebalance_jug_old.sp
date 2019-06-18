#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

// MAXIMUM STUFF WE CAN ADD [NOTE: DON'T GO OVERBOARD WITH THIS OR THE PLUGIN WILL GO SLOW]
#define MAXIMUM_ADDITIONS 255
#define MAXIMUM_ATTRIBUTES 20
//////////////////

#define PLUGIN_VERSION "v1.10"

public Plugin myinfo =
{
	name = "Rebalanced Fortress 2 (for Custom Weapons 2)",
	author = "JugadorXEI",
	description = "Rebalanced weapons based on suggested CW2 changes",
	version = PLUGIN_VERSION,
}

ConVar g_bEnablePlugin; // Convar that enables plugin

// Keyvalues file for attributes
Handle g_hKeyvaluesAttributesFile = INVALID_HANDLE;

// Bool that indicates if that item has been changed.
bool Rebalance_ItemIndexChanged[MAXIMUM_ADDITIONS] = false;
// Int that indicates the ID of the changed item.
int Rebalance_ItemIndexDef[MAXIMUM_ADDITIONS] = -1;
// Int that indicates how many items have been changed.
int Rebalance_ItemIndexChangesNumber = 0;
// Int that indicates which attribute(s) to add to a weapon.
// MAXIMUM_ADDITIONS is the max items that can be edited. MAXIMUM_ATTRIBUTES is the maximum attributes you can add on a weapon. 
int Rebalance_ItemAttribute_Add[MAXIMUM_ADDITIONS][MAXIMUM_ATTRIBUTES];
// float that indicates the value of the attribute(s) to add to a weapon.
float Rebalance_ItemAttribute_AddValue[MAXIMUM_ADDITIONS][MAXIMUM_ATTRIBUTES]; 
// int that indicates how many attributes were added on a weapon.
int Rebalance_ItemAttribute_AddNumber[MAXIMUM_ADDITIONS] = 0;

public void OnPluginStart()
{
	// Typical player_spawn and post_inventory_application for when we want to change weapons on spawn.
	HookEvent("player_spawn", Event_BalanceChanges);
	HookEvent("post_inventory_application", Event_BalanceChanges);
	
	// Convars, they do what they say on the tin.
	g_bEnablePlugin = CreateConVar("sm_tfrebalance_enable", "1", "Enables/Disables the plugin. Default = 1", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	
	// Admin command that refreshses the tf2rebalance_attributes file.
	RegAdminCmd("sm_tfrebalance_refresh", Rebalance_RefreshFile, ADMFLAG_ROOT,
	"Refreshes the attributes gotten through the file without needing to change maps. Depending on file size, it might cause a lag spike, so be careful.");
}

public void OnMapStart()
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		PrintToServer("[TFRebalance] Stored %i weapons in total to replace.", Rebalance_ItemIndexChangesNumber);
	}
}

public Action Rebalance_RefreshFile(int iClient, int iArgs)
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		PrintToServer("[TFRebalance] Stored %i weapons in total to replace.", Rebalance_ItemIndexChangesNumber);
	}
	
	return Plugin_Handled;
}

public Action Event_BalanceChanges(Handle hEvent, const char[] name, bool dontBroadcast)
{	
	/*	We get the client and its class. (we get the class to check if we should check for cloaks/pdas or not)
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	TFClassType iClass = TF2_GetPlayerClass(iClient);
	
	// Various ints related to the client's weapons and their definition index.
	int iPrimary, iPrimaryIndex, iSecondary, iSecondaryIndex, iMelee, iMeleeIndex, iBuilding, iBuildingIndex = -1;
	
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue) // If the client's valid and the plugin's enabled...
	{
		// primary weapon and def index:
		iPrimary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Primary);
		if (iPrimary != -1) iPrimaryIndex = GetEntProp(iPrimary, Prop_Send, "m_iItemDefinitionIndex");
		
		// secondary weapon and def index:
		iSecondary = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Secondary);
		if (iSecondary != -1) iSecondaryIndex = GetEntProp(iSecondary, Prop_Send, "m_iItemDefinitionIndex");
		
		// melee weapon and def index:
		iMelee = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Melee);
		if (iMelee != -1) iMeleeIndex = GetEntProp(iMelee, Prop_Send, "m_iItemDefinitionIndex");
		
		// Debug stuff:
		// PrintToConsole(iClient, "iPrimary: %i (Index: %i)\niSecondary: %i (Index: %i)\niMelee: %i (Index: %i)", iPrimary, iPrimaryIndex, iSecondary, iSecondaryIndex, iMelee, iMeleeIndex);
		
		// building weapon and def index:
		if (iClass == TFClass_Spy)
		{
			iBuilding = GetPlayerWeaponSlot(iClient, TFWeaponSlot_Building);
			if (iBuilding != -1) iBuildingIndex = GetEntProp(iBuilding, Prop_Send, "m_iItemDefinitionIndex");
		}
		
		// Int where we'll store which slot we'll remove.
		int iWeaponSlotToRemove = -1;
		
		// We go through all the weapons we've modified to see if we can replace the player's weapon
		// with another one.
		for (int i = 0; i <= Rebalance_ItemIndexChangesNumber; i++)
		{			
			// If a weapon's definition index matches with the one stored...
			if (iPrimaryIndex == Rebalance_ItemIndexDef[i] ||
			iSecondaryIndex == Rebalance_ItemIndexDef[i] ||
			iMeleeIndex == Rebalance_ItemIndexDef[i] ||
			iBuildingIndex == Rebalance_ItemIndexDef[i])
			{
				// Here we'll store the weapon entity we'll replace.
				int iWeaponToChange = -1;
				
				if (iPrimaryIndex == Rebalance_ItemIndexDef[i]) // If primary...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Primary; // We'll remove the primary...
					iWeaponToChange = iPrimary; // And use the primary as a reference for the weapon we'll change.
				}
				else if (iSecondaryIndex == Rebalance_ItemIndexDef[i]) // If secondary...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Secondary; // We'll remove the secondary...
					iWeaponToChange = iSecondary; // And use the secondary as a reference for the weapon we'll change.
				}
				else if (iMeleeIndex == Rebalance_ItemIndexDef[i]) // If melee...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Melee; // We'll remove the melee...
					iWeaponToChange = iMelee; // And use the melee as a reference for the weapon we'll change.
				}
				else if (iBuildingIndex == Rebalance_ItemIndexDef[i]) // If watch...
				{
					iWeaponSlotToRemove = TFWeaponSlot_Building; // We'll remove the watch...
					iWeaponToChange = iBuilding; // And use the watch as a reference for the weapon we'll change.
				}
				
				// We will add as many attributes as put on the attributes file.
				int iAdded = 1;
				
				// If the weapon we want to change is valid...
				if (IsValidEntity(iWeaponToChange) && iWeaponToChange > 0)
				{				
					// We'll remove it from the player.
					TF2_RemoveWeaponSlot(iClient, iWeaponSlotToRemove);
					
					// TF2Items: we'll create a handle here that'll store the item we'll replace.
					Handle hWeaponReplacement = TF2Items_CreateItem(OVERRIDE_ALL);
					
					// We'll get the classname from the entity we're basing it from, using tf_weapon_fists as a fallback,
					// then set it as the classname we'll use.
					char cWeaponClassname[64] = "tf_weapon_fists"; // Fists as fallback.
					GetEntityClassname(iWeaponToChange, cWeaponClassname, sizeof(cWeaponClassname));
					TF2Items_SetClassname(hWeaponReplacement, cWeaponClassname);
					
					// We'll use the stored item definition index as the weapon index we'll create. 
					TF2Items_SetItemIndex(hWeaponReplacement, Rebalance_ItemIndexDef[i]);			
					
					TF2Items_SetQuality(hWeaponReplacement, 10); // Customized Quality
					TF2Items_SetLevel(hWeaponReplacement, GetRandomInt(1, 100)); // Random Level
					
					// We add as many attributes as we put on the keyvalues file.
					TF2Items_SetNumAttributes(hWeaponReplacement, Rebalance_ItemAttribute_AddNumber[i]);
					// Attribute additions:
					// As long as iAdded is less than the attributes we'll stored...
					while (iAdded <= Rebalance_ItemAttribute_AddNumber[i])
					{
						//PrintToServer("Added %i to weapon", Rebalance_ItemAttribute_Add[i][iAdded]);
						// Then we'll add one attribute in.
						TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
						Rebalance_ItemAttribute_Add[i][iAdded], view_as<float>(Rebalance_ItemAttribute_AddValue[i][iAdded]));
						
						iAdded++; // We increase one on this int.
					}
					
					// We create a int variable for the weapon we've created.
					int iNewIndex = TF2Items_GiveNamedItem(iClient, hWeaponReplacement);
					
					// Then we'll close the handle that was the weapon in question and then we'll equip it to the player.
					CloseHandle(hWeaponReplacement);
					EquipPlayerWeapon(iClient, iNewIndex);
					
					// We set the new weapon as the active one.
					SetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon", iNewIndex);
				}
			}
		}
	}
	
	return Plugin_Continue;
	*/
}

public Handle CreateAttributeListFile(Handle hFile)
{
	if (hFile == INVALID_HANDLE) 
	{	
		// We create a keyvalues file for the kv list containing attributes
		hFile = CreateKeyValues("tf2rebalance_attributes"); // Keyvalues bois
		
		// We save the file.
		char cData[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, cData, PLATFORM_MAX_PATH, "data/tf2rebalance_attributes.txt"); // tf/addons/sourcemod/data/tf2rebalance_attributes.txt
		
		// We create the keyvalues
		FileToKeyValues(hFile, cData);
	}
	return hFile;
}

public bool GetAndStoreWeaponAttributes()
{
	// We create a kv list file.
	g_hKeyvaluesAttributesFile = CreateAttributeListFile(g_hKeyvaluesAttributesFile);
	if (g_hKeyvaluesAttributesFile == INVALID_HANDLE) return false;

	//char cDebugSectionName[32] = "123"; Debug stuff
	
	int iIDWeaponIndex = -1; // Default weapon index is -1;
	char cIDWeaponIndex[32]; // Because section names are chars even if they're numbers, we need to create a char.
	
	KvRewind(g_hKeyvaluesAttributesFile); // We go to the top node, woo.
	KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // We go to the first subkey (which should be a definition id)

	do
	{
		KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex)); // We get the section name (should be a definition id)
		iIDWeaponIndex = StringToInt(cIDWeaponIndex); // We turn the definition id string into an int for future usage.
		//PrintToServer("char: %s = int: %i", cIDWeaponIndex, iIDWeaponIndex); // Debug printing.
		
		if (iIDWeaponIndex != -1) // If a weapon ID is defined
		{
			//PrintToServer("TF2 Rebalance: there's attributes for %i, analyzing and storing...", iIDWeaponIndex);
			
			// We say that the weapon on this index was changed and we store the definition ID of such.
			Rebalance_ItemIndexChanged[Rebalance_ItemIndexChangesNumber] = true;
			Rebalance_ItemIndexDef[Rebalance_ItemIndexChangesNumber] = iIDWeaponIndex;
			
			// We setup a search int for the setup attributes
			int iSearchAttributesInFile = 1;
			
			KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // This should be an attribute[number] subkey.
			
			do
			{
				char cAttributeAddition[16];
				// The name of the section (should be attribute[number])
				KvGetSectionName(g_hKeyvaluesAttributesFile, cAttributeAddition, sizeof(cAttributeAddition));
				
				// We setup a char variable and then we fuse it with the setup int together.
				char cAttributeString[26] = "attribute";
				Format(cAttributeString, sizeof(cAttributeString), "%s%i", cAttributeString, iSearchAttributesInFile);
				
				if (StrEqual(cAttributeAddition, cAttributeString, false)) // Adding an attribute - gets the id and value inside the attribute section.
				{
					Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]++; // We add one into the attribute count int we have.
					// Here we store the attribute id.
					Rebalance_ItemAttribute_Add[Rebalance_ItemIndexChangesNumber][Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]] =
					KvGetNum(g_hKeyvaluesAttributesFile, "id", 0);
					
					// Here we store the attribute value.
					Rebalance_ItemAttribute_AddValue[Rebalance_ItemIndexChangesNumber][Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]] =
					KvGetFloat(g_hKeyvaluesAttributesFile, "value", 0.0);
					
					// We increase the search int value to look for more attributes.
					iSearchAttributesInFile++;
					
					// Debug stuff:
					//PrintToServer("Added attribute: %i with value %f",
					//Rebalance_ItemAttribute_Add[Rebalance_ItemIndexChangesNumber][Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]], 
					//Rebalance_ItemAttribute_AddValue[Rebalance_ItemIndexChangesNumber][Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]]);
					//PrintToServer("%i - %i", Rebalance_ItemIndexChangesNumber, Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]);
				}
			}
			while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between attributes.
			KvGoBack(g_hKeyvaluesAttributesFile); // We go back to process the next weapon.
				
			Rebalance_ItemIndexChangesNumber++; // We count as many weapons as we've modified
			
			// Debugging section:
			//KvGetSectionName(g_hKeyvaluesAttributesFile, cDebugSectionName, sizeof(cDebugSectionName));
			//PrintToServer("Now in: %s", cDebugSectionName);
			
			//PrintToServer("Debug:\niIDWeaponIndex = %i\nAttributes added: %i", // Debug stuff.
			//iIDWeaponIndex,
			//Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]);
		}
	}
	while (KvGotoNextKey(g_hKeyvaluesAttributesFile, true)); // Goes through weapon definition indexes.
	
	return true; // Returning true stops this.
}

public Action TF2Items_OnGiveNamedItem(int iClient, char[] cClassname, int iItemDefinitionIndex, Handle &hWeaponReplacement)
{	
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue) // If the client's valid and the plugin's enabled...
	{		
		// We go through all the weapons we've modified to see if we can replace the player's weapon
		// with another one.
		for (int i = 0; i <= Rebalance_ItemIndexChangesNumber; i++)
		{			
			// If a weapon's definition index matches with the one stored...
			if (iItemDefinitionIndex == Rebalance_ItemIndexDef[i])
			{				
				// We will add as many attributes as put on the attributes file.
				int iAdded = 1;
					
				// TF2Items: we'll create a handle here that'll store the item we'll replace.
				hWeaponReplacement = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);
				
				// We add as many attributes as we put on the keyvalues file.
				TF2Items_SetNumAttributes(hWeaponReplacement, Rebalance_ItemAttribute_AddNumber[i]);
				// Attribute additions:
				// As long as iAdded is less than the attributes we'll stored...
				while (iAdded <= Rebalance_ItemAttribute_AddNumber[i])
				{
					//PrintToServer("Added %i to weapon", Rebalance_ItemAttribute_Add[i][iAdded]);
					// Then we'll add one attribute in.
					TF2Items_SetAttribute(hWeaponReplacement, iAdded - 1,
					Rebalance_ItemAttribute_Add[i][iAdded], view_as<float>(Rebalance_ItemAttribute_AddValue[i][iAdded]));
					
					iAdded++; // We increase one on this int.
				}
				
				return Plugin_Changed;
			}
		}
	}
	
	
	return Plugin_Continue;
}

stock bool WipeStoredAttributes()
{
	// We close the keyvalues file handle.
	CloseHandle(g_hKeyvaluesAttributesFile);
	g_hKeyvaluesAttributesFile = INVALID_HANDLE;
	
	// We'll now set it to 0 items changed.
	Rebalance_ItemIndexChangesNumber = 0;
	
	// We set ourselves some ints to help wipe off what the variables stored.
	int i = 0, j = 0;
	
	while (i <= MAXIMUM_ADDITIONS - 1)
	{
		Rebalance_ItemIndexChanged[i] = false; // Everything to false.
		Rebalance_ItemIndexDef[i] = -1; // Everything to -1
		
		while (j <= MAXIMUM_ATTRIBUTES - 1)
		{
			Rebalance_ItemAttribute_Add[i][j] = 0; // We set the attribute ids to 0 alongside the weapon correspondant to it
			Rebalance_ItemAttribute_AddValue[i][j] = 0.0; // We set the attribute values to 0 alongside the weapon correspondant to it
			
			j++;
		}
		
		// We set all the attributes added number to zero.
		Rebalance_ItemAttribute_AddNumber[i] = 0;
		
		i++;
	}
}

// Helps us get a wearable entity from a player.
stock int GetPlayerWearableEntityIndex(int iClient, const char[] cClassname, int iWearable)
{
	int WearableItem = -1;
	
	while((WearableItem = FindEntityByClassname(WearableItem, cClassname)) != -1)
	{
		int WearableIndex = GetEntProp(WearableItem, Prop_Send, "m_iItemDefinitionIndex");
		int WearableOwner = GetEntPropEnt(WearableItem, Prop_Send, "m_hOwnerEntity");
		if(WearableOwner == iClient && WearableIndex == iWearable) return WearableItem;
	}
	
	return WearableItem;
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