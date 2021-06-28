/*
[SA-MP] Lumberjack Activity V-1.0

Lumberjack Activity FilterScript with dynamic trees using dini
Author: Palwa
*/

#include <a_samp>
#include <sscanf2>
#include <zcmd>
#include <foreach>
#include <streamer>
#include <dini>

#define MAX_TREES (100)

#define LUMBERJACK_RENT_POS 290.4481, 1139.1969, 8.9228
#define LUMBERJACK_RENT_POS_CAR 293.5457, 1149.7740, 10.9878
#define LUMBERJACK_SELL_POS -544.7388, -189.3582, 78.3852


#define HOLDING(%0) \
	((newkeys & (%0)) == (%0))

#define PRESSED(%0) \
	(((newkeys & (%0)) == (%0)) && ((oldkeys & (%0)) != (%0)))

#define RELEASED(%0) \
	(((newkeys & (%0)) != (%0)) && ((oldkeys & (%0)) == (%0)))


enum
{
	EDITING_TYPE_NONE,
	EDITING_TYPE_CREATE,
	EDITING_TYPE_EDIT
}

enum P_TREE_DATA
{
	P_EDITING_TYPE,
	P_EDITING_TREE,
	P_EDITING_OBJECT,
	//
	P_CUT,
	bool: P_HAS_WOOD
}
new g_player_tree[MAX_PLAYERS][P_TREE_DATA];

enum {OBJECT_INIT_TYPE_CREATE, OBJECT_INIT_TYPE_UPDATE}

enum E_TREE
{
	T_TIME,
	T_OBJECT,
	//
	Float: TX,
	Float: TY,
	Float: TZ,
	Float: TRX,
	Float: TRY,
	Float: TRZ,
	//
	bool: T_ON_CUT,
	bool: T_DOWN
}
new g_tree[MAX_TREES][E_TREE];
new Iterator: Trees<MAX_TREES>;

//
new V_WOOD[MAX_VEHICLES];
new V_WOOD_ATTACH[MAX_VEHICLES];
//
new SADLER_STOCK;
new WOOD_STOCK;
//
new Text3D: WOOD_LABEL;
new Text3D: SADLER_LABEL;

public OnFilterScriptInit()
{
   	print("\n");
	print("______________________________________________");
	print("[SA-MP] Lumberjack FilterScript Initialized");
	print("______________________________________________");
	
	LoadTrees();
	SetTimer("TreeUpdate", 60 * 1000, true);
	SetTimer("SecondUpdate", 1000, true);
	SetTimer("SadlerStock", 1800 * 1000, true);
	
	CreateDynamicPickup(1239, 23, LUMBERJACK_RENT_POS, -1);
	CreateDynamicPickup(1239, 23, LUMBERJACK_SELL_POS, -1);
	
	SADLER_LABEL = CreateDynamic3DTextLabel("{FF0000}Sadler Rental\n{FFFFFF}Rent a sadler for lumberjack using {FFFF00}/rentsadler\n{FFFFFF}Sadler Avaible: 0", -1, LUMBERJACK_RENT_POS, 7.5);
	WOOD_LABEL = CreateDynamic3DTextLabel("{FF0000}Lumberjack Center\n{FFFFFF}To sell your logs. type {FFFF00}/unloadlumber", -1, LUMBERJACK_SELL_POS, 10.0);
	
	GlobalStockInit();
	return 1;
}

public OnFilterScriptExit()
{
    print("\n");
	print("______________________________________________");
	print("[SA-MP] Lumberjack FilterScript Exit");
	print("______________________________________________");
	
	SaveAllTrees();
	
	dini_IntSet("tree/SADLER_STOCK.txt", "SADLER_STOCK", SADLER_STOCK);
	dini_IntSet("tree/WOOD_STOCK.txt", "WOOD_STOCK", WOOD_STOCK);
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
    new i = GetClosestTree(playerid, 3.0);
	new t_string[129];
	if(i != -1)
	{
	    if(g_tree[i][T_TIME] < 1)
		{
		 	if(g_tree[i][T_DOWN])
		    {
			    if(HOLDING(KEY_YES) && GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_CARRY)
				{
					if(g_player_tree[playerid][P_CUT] < 100)
					{
						g_player_tree[playerid][P_CUT] += 5;
					    ApplyAnimation(playerid,"BOMBER","BOM_Plant",4.0,0,0,0,1500,0);
					}
					else
					{
					    g_tree[i][T_DOWN] = false;
						g_tree[i][T_TIME] = 60;

						TreeObjectInit(i, OBJECT_INIT_TYPE_UPDATE);

						g_player_tree[playerid][P_CUT] = 0;
						g_player_tree[playerid][P_HAS_WOOD] = true;

						ClearAnimations(playerid);

						RemovePlayerAttachedObject(playerid, 6);
						SetPlayerAttachedObject(playerid, 6, 1463, 6, 0.0, 0.2, -0.04, -116.0, 2.0, 74.0);
						SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CARRY);

						SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}You've finished to take the pile of wood. Go back to your sadler and use {FFFF00}/loadlumber");
					}
				}
				else
				{
				    format(t_string, sizeof(t_string), "TREE ~b~%d~n~~w~DOWN~n~~w~HOLD AND PRESS ~y~Y", i);
           		    GameTextForPlayer(playerid, t_string, 1100, 4);
				}
			}
        }
	}
	return 1;
}

public OnPlayerEditDynamicObject(playerid, objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
 	if(objectid == g_player_tree[playerid][P_EDITING_OBJECT])
	{
	    if(response == EDIT_RESPONSE_FINAL)
	    {
	        switch(g_player_tree[playerid][P_EDITING_TYPE])
	        {
	            case EDITING_TYPE_CREATE:
	            {
	                CreateTrees(x, y, z, rx, ry, rz);
	                
	                DestroyDynamicObject(g_player_tree[playerid][P_EDITING_OBJECT]);
	                
	                SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}You've finished to create a tree");
	                Iter_Add(Trees, Iter_Free(Trees));
	            }
	            case EDITING_TYPE_EDIT:
	            {
					new i = g_player_tree[playerid][P_EDITING_TREE];
					
					g_tree[i][TX] = x;
					g_tree[i][TY] = y;
					g_tree[i][TZ] = z;
					
					g_tree[i][TRX] = rx;
					g_tree[i][TRY] = ry;
					g_tree[i][TRZ] = rz;
	            }
	        }
	        g_player_tree[playerid][P_EDITING_OBJECT] = -1;
		}
		else if(response == EDIT_RESPONSE_CANCEL)
		{
		    switch(g_player_tree[playerid][P_EDITING_TYPE])
	        {
	            case EDITING_TYPE_CREATE:
	            {
				    g_player_tree[playerid][P_EDITING_TYPE] = -1;
				    g_player_tree[playerid][P_EDITING_TREE] = -1;
				    g_player_tree[playerid][P_EDITING_OBJECT] = -1;
					DestroyDynamicObject(g_player_tree[playerid][P_EDITING_OBJECT]);
				}
				case EDITING_TYPE_EDIT: SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}Tree editing cancelled");
			}
		}
	}
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
	    case 1325:
	    {
			if(response)
			{
			    if(GetPlayerMoney(playerid) >= 2000)
			    {
			        new tmpveh = CreateVehicle(543, LUMBERJACK_RENT_POS_CAR, 90.0, -1, -1, 3600 * 1000);
			        
			        GivePlayerMoney(playerid, -2000);
			        SendClientMessage(playerid, -1, "{FFFF00}RENTAL: {FFFFFF}You've succesfully rent a sadler for 1 hour");
			        
			        SADLER_STOCK--;
			        
			        PutPlayerInVehicle(playerid, tmpveh, 0);
			        SetTimerEx("DestroyTempVeh", 3600 * 1000, false, "i", tmpveh);
			    }
			    else SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You need at least {00FF00}$2000 {FFFFFF}To rent a sadler");
			}
		}
		case 1326:
		{
		    if(response)
		    {
		        SendClientMessage(playerid, -1, "{FFFF00}GPS: {FFFFFF}Tree Location added on your map radar. Disable it by using {FFFF00}/discp");
		        SetPlayerMapIcon(playerid, 55, g_tree[listitem][TX], g_tree[listitem][TY], g_tree[listitem][TZ], 62, -1, MAPICON_GLOBAL);
		    }
		}
	}
	return 1;
}

CMD:cuttree(playerid, params[])
{
	new i = GetClosestTree(playerid, 2.5);
	
	if(i == -1) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}There're not any trees nearby");
	
	if(g_tree[i][T_ON_CUT]) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Someone is trying to cut down this tree already");
	
	if(g_tree[i][T_DOWN]) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}This tree is already cut down by someone. Press {FFFF00}Y {FFFFFF}To take");
	
	if(g_tree[i][T_TIME] > 0) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}This tree isn't ready to cut down right now");
	
	new rand = 10 + random(15);
	
	SetTimerEx("OnCutTree", 10000, false, "i", playerid);
	
    ApplyAnimation(playerid, "BASEBALL", "Bat_4", 3.1, 0, 0, 0, 0, rand * 1000, 1);
	SetPlayerAttachedObject(playerid, 6, 18634, 6, 0.07, 0.03, 0.04, 0.0, 270.0, 270.0, 1.5, 2.1, 1.8, 0);
	
	TogglePlayerControllable(playerid, false);
	
	g_tree[i][T_ON_CUT] = true;
	
	SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}You've started to cut a tree");
	GameTextForPlayer(playerid, "CUTTING", 5 * 1000, 1);
	return 1;
}

CMD:discp(playerid, params[])
{
	RemovePlayerMapIcon(playerid, 56);
	RemovePlayerMapIcon(playerid, 55);
	return 1;
}

CMD:lumhelp(playerid, params[])
{
	SendClientMessage(playerid, -1, "[ADMIN] {FFFF00}/createtree /edittree [treeid]");
	SendClientMessage(playerid, -1, "[PLAYER] {FFFF00}/cuttree /rentsadler /findtree /loadlumber /unloadlumber /droplumber /lumgps");
	return 1;
}

CMD:lumgps(playerid, params[])
{
	SetPlayerMapIcon(playerid, 56, LUMBERJACK_SELL_POS, 11, -1, MAPICON_GLOBAL);
	
	SendClientMessage(playerid, -1, "{FFFF00}GPS: {FFFFFF}Your GPS is now directed to lumberjack senter (wood sell). You can disable it using {FFFF00}/discp");
	return 1;
}

CMD:edittree(playerid, params[])
{
	if(!IsPlayerAdmin(playerid))
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Only RCON Admins authorized to use this command");
	    
	extract params -> new i; else return SendClientMessage(playerid, -1, "{FFFF00}SYNTAX: {FFFFFF}/edittree [treeid]");
	
	if(g_tree[i][T_OBJECT] == -1 || !Iter_Contains(Trees, i))
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Invalid Tree ID");

	g_player_tree[i][P_EDITING_TYPE] = EDITING_TYPE_EDIT;
	g_player_tree[i][P_EDITING_TREE] = i;
	g_player_tree[i][P_EDITING_OBJECT] = g_tree[i][T_OBJECT];
	
	EditDynamicObject(playerid, g_tree[i][T_OBJECT]);
	
	return 1;
}

CMD:createtree(playerid, params[])
{
	if(!IsPlayerAdmin(playerid))
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Only RCON Admins authorized to use this command");
	    
	new Float: x, Float: y, Float: z;
	
	GetPlayerPos(playerid, x, y, z);
	
	g_player_tree[playerid][P_EDITING_TYPE] = EDITING_TYPE_CREATE;
	g_player_tree[playerid][P_EDITING_OBJECT] = CreateDynamicObject(618, x + 3.0, y + 3.0, z, 0, 0, 0);
	
	SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}You've started to creating a tree");
	EditDynamicObject(playerid, g_player_tree[playerid][P_EDITING_OBJECT]);
	return 1;
}

CMD:unloadlumber(playerid, params[])
{
	new vehicleid = GetPlayerVehicleID(playerid);
	
	if(GetPlayerState(playerid) != PLAYER_STATE_DRIVER || GetVehicleModel(vehicleid) != 543)
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Your must be driver in a sadler to use this command");
	    
	if(!IsPlayerInRangeOfPoint(playerid, 5.0, LUMBERJACK_SELL_POS))
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You must at lumberjack center to use this command. type {FFFF00}/lumgps");

    if(V_WOOD[vehicleid] < 1) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}Your sadler didn't have any wood to sell");
    
    if(V_WOOD[vehicleid] + WOOD_STOCK >= 1000) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You can't sell more wood anymore due to maximum capacity of storage");
    
    new price;
    new string[129];
    
    switch(WOOD_STOCK)
    {
        case 0..300: price = 500;
        case 301..800: price = 300;
        case 801..900: price = 250;
        default: price = 100;
    }

	GivePlayerMoney(playerid, V_WOOD[vehicleid] * price);
	
	format(string, sizeof(string), "{FFFF00}LUMBER: {FFFFFF}You've sold all of your woods and get paid for {00FF00}$%d", V_WOOD[vehicleid] * 500);
	SendClientMessage(playerid, -1, string);
	
	WOOD_STOCK += V_WOOD[vehicleid];
	
    V_WOOD[vehicleid] = 0;
	return 1;
}

CMD:loadlumber(playerid, params[])
{
	new vehicleid = GetClosestVehicle(playerid, 4.0);
	
	if(!g_player_tree[playerid][P_HAS_WOOD] || GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_CARRY)
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You didn't have any wood to load");
	    
	if(vehicleid == INVALID_VEHICLE_ID || GetVehicleModel(vehicleid) != 543) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}There're not any vehicle nearby");
	
	if(GetVehicleModel(vehicleid) != 543) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}This vehicle must be sadler");

	if(V_WOOD[vehicleid] >= 5) return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}This vehicle unable to load more woods {FFFF00}(Max: 5)");
	
	V_WOOD[vehicleid] += 1;
	
	g_player_tree[playerid][P_HAS_WOOD] = false;

	SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
	RemovePlayerAttachedObject(playerid, 6);
	
	new string[129];
	
	format(string, sizeof(string), "{FFFF00}LUMBER: {FFFFFF}Loaded a wood to nearest vehicle. Total wood: {FFFF00}%d {FFFFFF}Woods", V_WOOD[vehicleid]);
	SendClientMessage(playerid, -1, string);
	
	return 1;
}

CMD:droplumber(playerid, params[])
{
	if(!g_player_tree[playerid][P_HAS_WOOD] || GetPlayerSpecialAction(playerid) != SPECIAL_ACTION_CARRY)
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You didn't have any wood to throw");

	g_player_tree[playerid][P_HAS_WOOD] = false;
	
	SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
	RemovePlayerAttachedObject(playerid, 6);
	
	SendClientMessage(playerid, -1, "{FFFF00}LUMBER: {FFFFFF}You've threw your wood for mile away");
	return 1;
}

CMD:findtree(playerid, params[])
{
    new Float: tempdist;
    
    new
        temp_string[50],
		dialog[15 * sizeof(temp_string)];
    
    
	foreach(new i : Trees)
	{
	    tempdist = GetPlayerDistanceFromPoint(playerid, g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ]);
		if(tempdist > 250.0) continue;
		
		if(i != -1)
		{
		    format(
			temp_string, sizeof(temp_string),
		    "Tree %d\t%s\t%.0f Mil.\n",
			i + 1, GetTreeStatus(i), GetPlayerDistanceFromPoint(playerid, g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ])
			);
			
			strcat(dialog, temp_string);
		}
	}
	
	ShowPlayerDialog(playerid, 1326, DIALOG_STYLE_TABLIST, "Tree List", dialog, "Trace", "Cancel");
	return 1;
}

CMD:rentsadler(playerid, params[])
{
	if(!IsPlayerInRangeOfPoint(playerid, 3.0, LUMBERJACK_RENT_POS))
	    return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}You must be at sadler rental to use this command");

    if(SADLER_STOCK < 1)
        return SendClientMessage(playerid, -1, "{FF0000}ERROR: {FFFFFF}This rental has been run out of sadler to rent. Comeback later...");
        
	ShowPlayerDialog(playerid, 1325, DIALOG_STYLE_MSGBOX, "Sadler Rental", "Are you sure to rent a sadler for 1 hour?\nIt will cost you {00FF00}$2000", "Rent", "Close");
	
	return 1;
}

stock GetTreeStatus(i)
{
	new status[24];
	
	switch(g_tree[i][T_TIME])
	{
	    case 1..60: status = "{FF0000}Not Ready";
	    case 0: status = "{00FF00}Ready";
	}
	
	return status;
}

stock CreateTrees(Float: x, Float: y, Float: z, Float: rx, Float: ry, Float: rz)
{
    new file[24];
	new i = Iter_Free(Trees);
	
	if(i != -1)
	{
		format(file, sizeof(file), "tree/tree-%d.txt", i);
		if(!dini_Exists(file))
		{
		    dini_Create(file);
		    
		    dini_FloatSet(file, "TX", x);
		    dini_FloatSet(file, "TY", y);
		    dini_FloatSet(file, "TZ", z);

		    dini_FloatSet(file, "TRX", rx);
		    dini_FloatSet(file, "TRY", ry);
		    dini_FloatSet(file, "TRZ", rz);

		    g_tree[i][TX] = x, g_tree[i][TY] = y, g_tree[i][TZ] = z;
		    g_tree[i][TRX] = rx, g_tree[i][TRY] = ry, g_tree[i][TRZ] = rz;
		    g_tree[i][T_TIME] = 0;
		    
		    TreeObjectInit(i, OBJECT_INIT_TYPE_CREATE);
			Iter_Add(Trees, Iter_Free(Trees));
		}
	}
	else print("[WARNING] Couldn't to create more tree due to max trees reached");
	return 1;
}

stock LoadTrees()
{
	new file[24];
	
	for(new i; i < MAX_TREES; i++)
	{
	    format(file, sizeof(file), "tree/tree-%d.txt", i);
		if(dini_Exists(file))
		{
		    g_tree[i][TX] = dini_Float(file, "TX");
		    g_tree[i][TY] = dini_Float(file, "TY");
		    g_tree[i][TZ] = dini_Float(file, "TZ");
		    
		    g_tree[i][TRX] = dini_Float(file, "TRX");
		    g_tree[i][TRY] = dini_Float(file, "TRY");
	    	g_tree[i][TRZ] = dini_Float(file, "TRZ");
	    	
	    	g_tree[i][T_TIME] = 0;

	    	CreateDynamicCP(g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ], 2.5, -1, -1, _, 3.0);
	    	
			TreeObjectInit(i, OBJECT_INIT_TYPE_CREATE);
			Iter_Add(Trees, Iter_Free(Trees));
		}
	}
	
	print("\n");
	print("______________________________________________");
	print("[SA-MP] Lumberjack Trees Initialized");
	print("______________________________________________");
	return 1;
}

stock SaveAllTrees()
{
    new file[24];

	for(new i; i < MAX_TREES; i++)
	{
		format(file, sizeof(file), "tree/tree-%d.txt", i);
		if(dini_Exists(file))
		{
		    GetDynamicObjectPos(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ]);
		    
		    dini_FloatSet(file, "TX", g_tree[i][TX]);
		    dini_FloatSet(file, "TY", g_tree[i][TY]);
		    dini_FloatSet(file, "TZ", g_tree[i][TZ]);
		    
		    if(!g_tree[i][T_DOWN]){
		    dini_FloatSet(file, "TRX", g_tree[i][TRX]);
		    }
		    dini_FloatSet(file, "TRY", g_tree[i][TRY]);
		    dini_FloatSet(file, "TRZ", g_tree[i][TRZ]);
		}
	}
	return 1;
}

stock TreeObjectInit(i, type)
{
	switch(type)
	{
	    case OBJECT_INIT_TYPE_CREATE:
	    {
	        switch(g_tree[i][T_TIME])
	        {
	            case 40..60: g_tree[i][T_OBJECT] = CreateDynamicObject(618, g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ] - 10.0, g_tree[i][TRX], g_tree[i][TRY], g_tree[i][TRZ]);
	            case 20..39: g_tree[i][T_OBJECT] = CreateDynamicObject(618, g_tree[i][TX], g_tree[i][TY] - 7.5, g_tree[i][TZ], g_tree[i][TRX], g_tree[i][TRY], g_tree[i][TRZ]);
	            case 5..19: g_tree[i][T_OBJECT] = CreateDynamicObject(618, g_tree[i][TX], g_tree[i][TY] - 5.0, g_tree[i][TZ], g_tree[i][TRX], g_tree[i][TRY], g_tree[i][TRZ]);
				default: g_tree[i][T_OBJECT] = CreateDynamicObject(618, g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ], g_tree[i][TRX], g_tree[i][TRY], g_tree[i][TRZ]);
			}
		}
		case OBJECT_INIT_TYPE_UPDATE:
	    {
	        switch(g_tree[i][T_TIME])
	        {
	           case 40..60: SetDynamicObjectPos(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ] - 10.0);
	           case 20..39: SetDynamicObjectPos(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ] - 7.5);
	           case 5..19: SetDynamicObjectPos(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ] - 5.0);
	           default: SetDynamicObjectPos(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ]);
			}
		}
	}
	return 1;
}

stock GlobalStockInit()
{
	new file[24];
	
	SADLER_STOCK++;
	
	format(file, sizeof(file), "tree/SADLER_STOCK.txt");
	if(dini_Exists(file))
	{
	    SADLER_STOCK = dini_Int(file, "SADLER_STOCK");
	}
	else dini_Create(file), dini_IntSet(file, "SADLER_STOCK", SADLER_STOCK);
	
	format(file, sizeof(file), "tree/WOOD_STOCK.txt");
	if(dini_Exists(file))
	{
	    WOOD_STOCK = dini_Int(file, "WOOD_STOCK");
	}
	else dini_Create(file), dini_IntSet(file, "WOOD_STOCK", WOOD_STOCK);
	
	return 1;
}

stock Float: SetPlayerFacingObject(playerid, objectid)
{
    new Float:pX, Float:pY, Float:pZ, Float:X, Float:Y, Float:Z,Float:ang, Float: result;
    GetDynamicObjectPos(objectid, X, Y, Z),GetPlayerPos(playerid, pX, pY, pZ);
    if( Y > pY ) ang = (-acos((X - pX) / floatsqroot((X - pX)*(X - pX) + (Y - pY)*(Y - pY))) - 90.0);
    else if( Y < pY && X < pX ) ang = (acos((X - pX) / floatsqroot((X - pX)*(X - pX) + (Y - pY)*(Y - pY))) - 450.0);
    else if( Y < pY ) ang = (acos((X - pX) / floatsqroot((X - pX)*(X - pX) + (Y - pY)*(Y - pY))) - 90.0);
    if(X > pX) ang = (floatabs(floatabs(ang) + 180.0));
    else ang = (floatabs(ang) - 180.0);
	return SetPlayerFacingAngle(playerid, ang + 270.0);
}

stock GetClosestTree(playerid, Float: range = 2.5)
{
	new id = -1, Float: dist = range, Float: tempdist;
	foreach(new i : Trees)
	{
	    tempdist = GetPlayerDistanceFromPoint(playerid, g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ]);
		if(tempdist > range) continue;
		if(tempdist <= dist)
		{
			dist = tempdist;
			id = i;
			break;
		}
	}

	return id;
}

stock GetClosestVehicle(playerid, Float: range = 3.0)
{
	new id = -1, Float: dist = range, Float: tempdist, Float: x, Float: y, Float: z;
	for(new i; i < MAX_VEHICLES; ++i)
	{
	    GetVehiclePos(i, x, y, z);
	    tempdist = GetPlayerDistanceFromPoint(playerid, x, y, z);
		if(tempdist > range) continue;
		if(tempdist <= dist)
		{
			dist = tempdist;
			id = i;
			break;
		}
	}

	return id;
}

//
forward TreeUpdate();
public TreeUpdate(){
    new t_string[129];
	foreach(new i : Trees)
	{
	    if(g_tree[i][T_TIME] > 0)
	    {
	        g_tree[i][T_TIME]--;
	        
			TreeObjectInit(i, OBJECT_INIT_TYPE_UPDATE);
	    }
	}
	
	SaveAllTrees();
	return 1;
}

forward SecondUpdate();
public SecondUpdate()
{
	foreach(new vehicleid : Vehicle)
	{
	    if(GetVehicleModel(vehicleid) == 543)
	    {
		    if(V_WOOD[vehicleid] > 0)
		    {
	            if(V_WOOD_ATTACH[vehicleid] == -1)
	            {
	                V_WOOD_ATTACH[vehicleid] = CreateDynamicObject(1463,0.0,0.0,-1000.0,0.0,0.0,0.0,-1,-1,-1,300.0,300.0);
	  			    AttachDynamicObjectToVehicle(V_WOOD_ATTACH[vehicleid], vehicleid, 0.054, -1.539, 0.139, 0.000, 0.000, 92.000);
	  			}
	  		}
	  		else
	  		{
	            if(V_WOOD_ATTACH[vehicleid] != -1)
	            {
	                DestroyDynamicObject(V_WOOD_ATTACH[vehicleid]);
	                V_WOOD_ATTACH[vehicleid] = -1;
	  			}
	  		}
	  	}
	}
	
    if(SADLER_STOCK > 5) SADLER_STOCK = 5;
	if(WOOD_STOCK > 1000) SADLER_STOCK = 1000;

	new l_string[229];
	format(l_string, sizeof(l_string), "{FF0000}Sadler Rental\n{FFFFFF}Rent a sadler for lumberjack using {FFFF00}/rentsadler\n{FFFFFF}Sadler Avaible: %d", SADLER_STOCK);
	UpdateDynamic3DTextLabelText(SADLER_LABEL, -1, l_string);

	format(l_string, sizeof(l_string), "{FF0000}Lumberjack Center\n{FFFFFF}To sell your logs. type {FFFF00}/unloadlumber\n{FFFFFF}Current Stock: {FFFF00}%d/1000 Logs", WOOD_STOCK);
	UpdateDynamic3DTextLabelText(WOOD_LABEL, -1, l_string);
	
	foreach(new playerid : Player)
	{
		new i = GetClosestTree(playerid);
		
		if(i == -1) g_player_tree[playerid][P_CUT] = 0;
	}
	return 1;
}

forward OnCutTree(playerid);
public OnCutTree(playerid)
{
	new i = GetClosestTree(playerid);
	
	g_tree[i][T_ON_CUT] = false;
	g_tree[i][T_DOWN] = true;
	
	MoveDynamicObject(g_tree[i][T_OBJECT], g_tree[i][TX], g_tree[i][TY], g_tree[i][TZ], 10.0, g_tree[i][TRX] + 90.0, g_tree[i][TRY], g_tree[i][TRZ]);
	ClearAnimations(playerid);
	
	RemovePlayerAttachedObject(playerid, 6);
	TogglePlayerControllable(playerid, true);
	
	SendClientMessage(playerid, -1, "{FFFF00}TREE: {FFFFFF}You've finished cut down a tree. press {FFFF00}Y {FFFFFF}multiple times To cut the tree into pieces");
	return 1;
}

forward SadlerStock();
public SadlerStock(){
	SADLER_STOCK++;
	return 1;
}

forward DestroyTempVehicle(vehicleid);
public DestroyTempVehicle(vehicleid){
	DestroyVehicle(vehicleid);
	SADLER_STOCK++;
	return 1;
}
