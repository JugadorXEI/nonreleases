#include <sourcemod>
#include <tf2_stocks>
#include <tf2items>

// Used to add attributes on classes, optional.
#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>            
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

// MAXIMUM STUFF WE CAN ADD [NOTE: DON'T GO OVERBOARD WITH THIS OR THE PLUGIN WILL GO SLOW]
#define MAXIMUM_ADDITIONS 255
#define MAXIMUM_ATTRIBUTES 20
//////////////////

/*
For v1.20:
- Add support for class attributes - add attributes on classes through the kv file
- Multiple int index ID support for the same attribute values.
*/

#define PLUGIN_VERSION "v1.10"

public Plugin myinfo =
{
	name = "Rebalanced Fortress 2 (for Custom Weapons 2)",
	author = "JugadorXEI",
	description = "Rebalanced weapons based on suggested CW2 changes",
	version = PLUGIN_VERSION,
}

ConVar g_bEnablePlugin; // Convar that enables plugin
ConVar g_bLogMissingDependencies; // Convar that, if enabled, will log if dependencies are missing.

// Keyvalues file for attributes
Handle g_hKeyvaluesAttributesFile = INVALID_HANDLE;

// Plugin dependencies: are they enabled or not?
bool bIsTF2AttributesEnabled = false;

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

// Class things:
// Bool that indicates if that class was changed.
bool Rebalance_ClassChanged[TFClassType] = false;
// int that indicates which attributes we'll add into the class.
int Rebalance_ClassAttribute_Add[TFClassType][MAXIMUM_ATTRIBUTES]; 
// float that indicates the value of the attributes we'll add.
float Rebalance_ClassAttribute_AddValue[TFClassType][MAXIMUM_ATTRIBUTES];
// int that indicates how many attributes were added on a class.
int Rebalance_ClassAttribute_AddNumber[TFClassType] = 0;

public void OnPluginStart()
{
	// Convars, they do what they say on the tin.
	g_bEnablePlugin = CreateConVar("sm_tfrebalance_enable", "1", "Enables/Disables the plugin. Default = 1", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	g_bLogMissingDependencies = CreateConVar("sm_tfrebalance_logdependencies", "1", "If any dependencies are missing from the plugin, log them on SourceMod logs. Default = 1", FCVAR_DONTRECORD|FCVAR_PROTECTED);
	
	// Admin command that refreshses the tf2rebalance_attributes file.
	RegAdminCmd("sm_tfrebalance_refresh", Rebalance_RefreshFile, ADMFLAG_ROOT,
	"Refreshes the attributes gotten through the file without needing to change maps. Depending on file size, it might cause a lag spike, so be careful.");
	
	// Let's hook the spawns and such.
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("post_inventory_application", Event_PlayerSpawn);
}

public void OnMapStart()
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		PrintToServer("[TFRebalance] Stored %i weapons in total to replace.", Rebalance_ItemIndexChangesNumber);
	}
	
	// If any of the (optional) requirements aren't loaded, we log that in just in case.
	if (g_bLogMissingDependencies.BoolValue) // That is, if this convar is set to true.
	{
		if (!bIsTF2AttributesEnabled) LogMessage("[TFRebalance] tf2attributes is not loaded. This will prevent the plugin from adding attributes on classes.");
	}
}

// We check if tf2attributes exist or not.
public void OnLibraryAdded(const char[] cName)
{	
	if (StrEqual(cName, "tf2attributes", true))
	{
		bIsTF2AttributesEnabled = true;
	}
}

public void OnLibraryRemoved(const char[] cName)
{
	if (StrEqual(cName, "tf2attributes", true))
	{
		bIsTF2AttributesEnabled = false;
	}
}
// End of checking that.

public Action Rebalance_RefreshFile(int iClient, int iArgs)
{
	WipeStoredAttributes(); // Function that sets every Rebalance_* variable and the Handle to 0/INVALID_HANDLE;
	if (GetAndStoreWeaponAttributes()) // Function that stores the weapon changes on the variables.
	{
		PrintToServer("[TFRebalance] Stored %i weapons in total to replace.", Rebalance_ItemIndexChangesNumber);
	}
	
	return Plugin_Handled;
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

public Action Event_PlayerSpawn(Handle hEvent, const char[] cName, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if (IsValidClient(iClient) && g_bEnablePlugin.BoolValue)
	{	
		TF2Attrib_RemoveAll(iClient); // We remove all of the client's attributes so they don't stack or mesh together.
		TFClassType tfClassModified = TF2_GetPlayerClass(iClient); // We fet the client's class
		
		// If a weapon's definition index matches with the one stored...
		if (Rebalance_ClassChanged[tfClassModified] == true)
		{				
			int iAdded = 1;
			
			// Attribute additions:
			// As long as iAdded is less than the attributes we'll stored...
			while (iAdded <= Rebalance_ClassAttribute_AddNumber[tfClassModified])
			{
				//PrintToServer("Added %i to class", Rebalance_ClassAttribute_Add[tfClassModified][iAdded]);
				// Then we'll add one attribute in.
				TF2Attrib_SetByDefIndex(iClient, 
				Rebalance_ClassAttribute_Add[tfClassModified][iAdded],
				view_as<float>(Rebalance_ClassAttribute_AddValue[tfClassModified][iAdded]));
				
				iAdded++; // We increase one on this int.
			}
		}
	}
}

public bool GetAndStoreWeaponAttributes()
{
	// We create a kv list file.
	g_hKeyvaluesAttributesFile = CreateAttributeListFile(g_hKeyvaluesAttributesFile);
	if (g_hKeyvaluesAttributesFile == INVALID_HANDLE) return false;

	// char cDebugSectionName[32] = "123";
	
	int iIDWeaponIndex = -1; // Default weapon index is -1;
	char cIDWeaponIndex[32]; // Because section names are chars even if they're numbers, we need to create a char.
	char cIDsOfWeapons[255][5]; // The IDs of weapons if multiple are put in the same attribute set.
	
	KvRewind(g_hKeyvaluesAttributesFile); // We go to the top node, woo.
	KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // We go to the first subkey (which should be a definition id)

	do
	{
		KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex)); // We get the section name (either id or classes sect.)
		//iIDWeaponIndex = StringToInt(cIDWeaponIndex); // We turn the definition id string into an int for future usage, if possible.
		PrintToServer("char: %s", cIDWeaponIndex); // Debug printing.
		
		ExplodeString(cIDWeaponIndex, " ; ", cIDsOfWeapons, 255, 6, false);
		int iAttributeCountWithinString = 0;
		
		if (StrEqual("classes", cIDWeaponIndex, false)) // Classes section.
		{
			KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // This should be a class subkey.		
			
			do
			{
				KvGetSectionName(g_hKeyvaluesAttributesFile, cIDWeaponIndex, sizeof(cIDWeaponIndex)); // We get the class name
				// We get the class from the section name and we say that yes, it's a modified class.
				TFClassType tfClassModified = GetTFClassTypeFromName(cIDWeaponIndex);
				Rebalance_ClassChanged[tfClassModified] = true;
				
				// We setup a search int for the setup attributes
				int iSearchAttributesInFile = 1;
				
				// Debugging section: should be scout or a class name
				// KvGetSectionName(g_hKeyvaluesAttributesFile, cDebugSectionName, sizeof(cDebugSectionName));
				// PrintToServer("Now in: %s", cDebugSectionName);
			
				KvGotoFirstSubKey(g_hKeyvaluesAttributesFile, false); // This should be an attribute[number] subkey.
				
				char cAttributeAddition[16];
				// The name of the section (should be attribute[number])
				KvGetSectionName(g_hKeyvaluesAttributesFile, cAttributeAddition, sizeof(cAttributeAddition));
				
				// We setup a char variable and then we fuse it with the setup int together.
				char cAttributeString[26] = "attribute";
				Format(cAttributeString, sizeof(cAttributeString), "%s%i", cAttributeString, iSearchAttributesInFile);
				
				do // LET'S PROCESS CLASS ATTRIBUTES BOY
				{
					if (StrEqual(cAttributeAddition, cAttributeString, false)) // Adding an attribute - gets the id and value inside the attribute section.
					{
						Rebalance_ClassAttribute_AddNumber[tfClassModified]++; // We add one into the attribute count int we have.
						// Here we store the attribute id.
						Rebalance_ClassAttribute_Add[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]] =
						KvGetNum(g_hKeyvaluesAttributesFile, "id", 0);
						
						// Here we store the attribute value.
						Rebalance_ClassAttribute_AddValue[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]] =
						KvGetFloat(g_hKeyvaluesAttributesFile, "value", 0.0);
						
						// We increase the search int value to look for more attributes.
						iSearchAttributesInFile++;
						
						// Debug stuff:
						PrintToServer("Added attribute to class: %i with value %f",
						Rebalance_ClassAttribute_Add[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]], 
						Rebalance_ClassAttribute_AddValue[tfClassModified][Rebalance_ClassAttribute_AddNumber[tfClassModified]]);
						//PrintToServer("%i - %i", Rebalance_ItemIndexChangesNumber, Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]);
					}
				}
				while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between attributes.
				KvGoBack(g_hKeyvaluesAttributesFile); // Into away from attributes and into another class.
				
				// Debugging section: should be attribute[number] or something
				//KvGetSectionName(g_hKeyvaluesAttributesFile, cDebugSectionName, sizeof(cDebugSectionName));
				//PrintToServer("Now in: %s", cDebugSectionName);
			}
			while (KvGotoNextKey(g_hKeyvaluesAttributesFile, false)); // Moves between class sections.
			
			KvGoBack(g_hKeyvaluesAttributesFile); // We go back to the weapons BOI
		}
		
		for (;;)
		{
			if (!StrEqual(cIDsOfWeapons[iAttributeCountWithinString], "", false))
			{
				PrintToServer("Attribute %s in string", cIDsOfWeapons[iAttributeCountWithinString]); // debug string
				iIDWeaponIndex = StringToInt(cIDsOfWeapons[iAttributeCountWithinString]); // We turn the definition id string into an int for future usage, if possible.
				
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
					cIDsOfWeapons[iAttributeCountWithinString] = ""; // We blank out the string that has the weapon ID.
					iAttributeCountWithinString++; // Let's give it another attribute count.
					//PrintToServer("Debug:\niIDWeaponIndex = %i\nAttributes added: %i", // Debug stuff.
					//iIDWeaponIndex,
					//Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]);
				}
			
				
			}
			else break;
		}
		/*
		else if (iIDWeaponIndex != -1) // If a weapon ID is defined
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
			
			//PrintToServer("Debug:\niIDWeaponIndex = %i\nAttributes added: %i", // Debug stuff.
			//iIDWeaponIndex,
			//Rebalance_ItemAttribute_AddNumber[Rebalance_ItemIndexChangesNumber]);
		}
		*/
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

public TFClassType GetTFClassTypeFromName(const char[] cName)
{
	// Are you ready for this long if?
	
	if (StrEqual(cName, "scout", false)) return TFClass_Scout;
	else if (StrEqual(cName, "sniper", false)) return TFClass_Sniper;
	else if (StrEqual(cName, "soldier", false)) return TFClass_Soldier;
	else if (StrEqual(cName, "demoman", false)) return TFClass_DemoMan;
	else if (StrEqual(cName, "medic", false)) return TFClass_Medic;
	else if (StrEqual(cName, "heavy", false)) return TFClass_Heavy;
	else if (StrEqual(cName, "pyro", false)) return TFClass_Pyro;
	else if (StrEqual(cName, "spy", false)) return TFClass_Spy;
	else if (StrEqual(cName, "engineer", false)) return TFClass_Engineer;

	return TFClass_Unknown;
}

// Fuction that wipes stored attributes.
stock bool WipeStoredAttributes()
{
	// We close the keyvalues file handle.
	CloseHandle(g_hKeyvaluesAttributesFile);
	g_hKeyvaluesAttributesFile = INVALID_HANDLE;
	
	// We'll now set it to 0 items changed.
	Rebalance_ItemIndexChangesNumber = 0;
	
	// We set ourselves some ints to help wipe off what the variables stored.
	int i = 0, j = 0, k = 1, l = 0;
	
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
	
	while (k <= view_as<int>(TFClass_Engineer)) // the last class
	{
		Rebalance_ClassChanged[k] = false; // Everything to false.
		Rebalance_ClassAttribute_AddNumber[k] = 0; // Everything to 0 attributes.
		
		while (l <= MAXIMUM_ATTRIBUTES - 1)
		{
			Rebalance_ClassAttribute_Add[k][l] = 0; // Everything set to zero attributes.
			Rebalance_ClassAttribute_AddValue[k][l] = 0.0; // Everything set to zero values.
			
			l++;
		}
		
		k++;
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