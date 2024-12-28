/*==================================================================================================

			       |**********************************|
			       |==================================|
			       |=       xWeapon Skin System	 	 =|
			       |=     Requested by people	 	 =|
			       |==================================|
			       |**********************************|

|= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =|
 |												   													|
 |												   													|
 |			Copyright © 2024-2025, Huehue					   										|
 |			This file is provided as is (no warranties) 				   							|
 |												   													|
 |			xWeapon Skin System is free software; 				   									|
 |			you can redistribute it and/or modify it under the terms of the 	   					|
 |			GNU General Public License as published by the Free Software Foundation.   				|
 |												   													|	
 |			This program is distributed in the hope that it will be useful,            				|
 |			but WITHOUT ANY WARRANTY; without even the implied warranty of             				|
 |			MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 			   						|
 |												   													|
 |												   													|
|= = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =| 
					  |---------------|
					  |   Changelog   |
					  |---------------|
				v1.0 Official Plugin Release
											 
==================================================================================================*/

#include <amxmodx>
#include <reapi>

#define MIN_WEAPON_ID 1
#define MAX_WEAPON_ID 31

native get_user_level(id)

#define VERSION "1.0"

new const g_szFileName[] = "xWeapon_Skins_System.ini"

enum _:eInSectionData
{
	Weapon_Name[MAX_NAME_LENGTH],
	Weapon_Id[MAX_WEAPON_ID],
	Skin_Name[MAX_NAME_LENGTH],
	View_Model_Name[MAX_USER_INFO_LENGTH],
	Player_Model_Name[MAX_USER_INFO_LENGTH],
	Level_Model,
	Admin_Flag[MAX_EDICT_BITS]
}

new Array:g_aWeaponData[eInSectionData][MAX_WEAPON_ID]
new bool:g_bWeaponSkinAvailable[MAX_WEAPON_ID]

new g_iCurrentWeapon[MAX_PLAYERS + 1][MAX_WEAPON_ID]

new g_iTotalLoadedSections[MAX_WEAPON_ID]

enum eType
{
	VIEW = 0,
	PLAYER
}
new szModel[eType][MAX_USER_INFO_LENGTH]

public plugin_init()
{
	register_plugin("xWeapon Skin System [Highly Requested]", VERSION, "Huehue @ AMXX-BG.INFO")
	
	register_event("CurWeapon", "eventCurWeapon", "be", "1=1")
	
	register_clcmd("say", "Command_HookChat")
	register_clcmd("say_team", "Command_HookChat")
}

public plugin_precache()
{
	for (new loopWeapon = MIN_WEAPON_ID; loopWeapon < MAX_WEAPON_ID; loopWeapon++)
	{
		g_aWeaponData[Weapon_Name][loopWeapon] = ArrayCreate(64, 64)
		g_aWeaponData[Weapon_Id][loopWeapon] = ArrayCreate(32, 32)

		g_aWeaponData[Skin_Name][loopWeapon] = ArrayCreate(32, 1)
		g_aWeaponData[View_Model_Name][loopWeapon] = ArrayCreate(128, 1)
		g_aWeaponData[Player_Model_Name][loopWeapon] = ArrayCreate(128, 1)
		g_aWeaponData[Level_Model][loopWeapon] = ArrayCreate(32, 1)
		g_aWeaponData[Admin_Flag][loopWeapon] = ArrayCreate(32, 1)
	}
	
	Load_File()
}
public Load_File()
{
	new szFile[128]
	formatex(szFile, charsmax(szFile), "addons/amxmodx/configs/%s", g_szFileName)
	
	if (file_exists(szFile))
	{
		new iLine, szData[MAX_MOTD_LENGTH], iBuffer, iSection = 0
		new szName[MAX_NAME_LENGTH], szLevel[16], szAccess[MAX_EDICT_BITS]
		
		while ((iLine = read_file(szFile, iLine, szData, charsmax(szData), iBuffer)) > 0)
		{
			if (szData[0] == EOS || !szData[0] || szData[0] == '/' && szData[1] == '/' || szData[0] == ';')
				continue
			
			if (szData[0] == '[')
			{
				iSection++

				if (iSection == 6 || iSection == 2) // Ignore weapon_glock / weapon_c4
					iSection += 1

				continue
			}
			
			if (iSection < MIN_WEAPON_ID) continue
			if (iSection > MAX_WEAPON_ID - 1) break
			
			parse(szData, szName, charsmax(szName), szModel[VIEW], charsmax(szModel[]), szModel[PLAYER], charsmax(szModel[]), szLevel, charsmax(szLevel), szAccess, charsmax(szAccess))

			if (file_exists(szModel[VIEW]))
			{
				PrecacheModel(szModel[VIEW])
					
				if (!equal(szModel[PLAYER], ""))
					PrecacheModel(szModel[PLAYER])

				new szWeaponName[MAX_NAME_LENGTH]
				rg_get_weapon_info(iSection, WI_NAME, szWeaponName, charsmax(szWeaponName))
				new iWeapon = rg_get_weapon_info(szWeaponName, WI_ID)

				ArrayPushString(g_aWeaponData[Weapon_Name][iSection], szWeaponName)
				ArrayPushCell(g_aWeaponData[Weapon_Id][iSection], iWeapon)

				ArrayPushString(g_aWeaponData[Skin_Name][iSection], szName)
				ArrayPushString(g_aWeaponData[View_Model_Name][iSection], szModel[VIEW])
				ArrayPushString(g_aWeaponData[Player_Model_Name][iSection], szModel[PLAYER])
				ArrayPushCell(g_aWeaponData[Level_Model][iSection], str_to_num(szLevel))
				ArrayPushString(g_aWeaponData[Admin_Flag][iSection], szAccess)

				g_bWeaponSkinAvailable[iSection] = true
				g_iTotalLoadedSections[iSection]++
			}
		}
	}
}
PrecacheModel(szModel[])
{
	if (file_exists(szModel))
		precache_model(szModel)
	else
		log_amx("Failed to precache: ^"%s^"! It's missing or may have a wrong name!", szModel)
}
public client_putinserver(id)
{
	for (new loopWeapon = MIN_WEAPON_ID; loopWeapon < MAX_WEAPON_ID; loopWeapon++)
	{
		g_iCurrentWeapon[id][loopWeapon] = -1
	}
}

public Toggle_MainMenu(id, iWeaponMenu)
{
	static iMenu, iMenuCallBack

	if (iWeaponMenu == 0)
	{
		iMenu = menu_create("\d[\rXWSS\d] \yChoose Skin Section", "MainMenu_Handler")
		static szLoopedWeaponSection[MAX_NAME_LENGTH]

		iMenuCallBack = menu_makecallback("MainMenu_SkinWeapon")

		for (new loopWeapon = MIN_WEAPON_ID; loopWeapon < MAX_WEAPON_ID; loopWeapon++)
		{
			for (new i = 1; i < g_iTotalLoadedSections[loopWeapon]; i++)
			{
				if (g_bWeaponSkinAvailable[loopWeapon])
				{
					ArrayGetString(g_aWeaponData[Weapon_Name][loopWeapon], i, szLoopedWeaponSection, charsmax(szLoopedWeaponSection))

					replace_all(szLoopedWeaponSection, charsmax(szLoopedWeaponSection), "weapon_", "")
					ucfirst(szLoopedWeaponSection)

					menu_additem(iMenu, szLoopedWeaponSection, "MainMenu_SkinSection", .callback = iMenuCallBack)
				}
			}
		}
	}
	else
	{
		static szWeaponName[MAX_NAME_LENGTH]
		rg_get_weapon_info(iWeaponMenu, WI_NAME, szWeaponName, charsmax(szWeaponName))

		replace_all(szWeaponName, charsmax(szWeaponName), "weapon_", "")
		ucfirst(szWeaponName)
		iMenu = menu_create(fmt("\d[\rXWSS\d] \yChoose Skin for \r%s", szWeaponName), "MainMenu_Handler")

		iMenuCallBack = menu_makecallback("MainMenu_SkinSelection")


		for (new mWeapon = -1; mWeapon < g_iTotalLoadedSections[iWeaponMenu]; mWeapon++)
		{
			if (mWeapon == -1)
				menu_additem(iMenu, "Default Skin^n", fmt("%i", iWeaponMenu))
			else
			{
				new szSkinName[MAX_NAME_LENGTH], szAdminFlag[6]
				ArrayGetString(g_aWeaponData[Skin_Name][iWeaponMenu], mWeapon, szSkinName, charsmax(szSkinName))
				ArrayGetString(g_aWeaponData[Admin_Flag][iWeaponMenu], mWeapon, szAdminFlag, charsmax(szAdminFlag))
				menu_additem(iMenu, fmt("%s", szSkinName), fmt("%i", iWeaponMenu), .paccess = read_flags(szAdminFlag), .callback = iMenuCallBack)
			}
		}
	}
	menu_display(id, iMenu, 0)
	return PLUGIN_HANDLED
}

public MainMenu_SkinSelection(id, iMenu, Item)
{
	static szData[32], iAccess, iCallBack, szName[MAX_NAME_LENGTH * 2]
	menu_item_getinfo(iMenu, Item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallBack)

	new iWeapon = str_to_num(szData)

	if (g_iCurrentWeapon[id][iWeapon] == Item - 1)
	{
		menu_item_setname(iMenu, Item, fmt("%s \y*", szName))
		return ITEM_ENABLED
	}

	new iWeapon_Level = ArrayGetCell(g_aWeaponData[Level_Model][iWeapon], Item - 1)
	new iPlayer_Level = get_user_level(id)

	if (iPlayer_Level < iWeapon_Level && get_user_flags(id) & iAccess)
	{
		return ITEM_ENABLED
	}
	else
	{
		if (iPlayer_Level < iWeapon_Level && ~get_user_flags(id) & iAccess)
		{
			menu_item_setname(iMenu, Item, fmt("\w%s \r*", szName))
			return ITEM_DISABLED
		}
	}
	return ITEM_ENABLED
}

public MainMenu_SkinWeapon(id, iMenu, Item)
{
	static szData[32], iAccess, iCallBack, szTempFmtItem[MAX_FMT_LENGTH], szName[MAX_NAME_LENGTH * 2]
	menu_item_getinfo(iMenu, Item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallBack)

	strtolower(szName)
	formatex(szTempFmtItem, charsmax(szTempFmtItem), "weapon_%s", szName)
	new iWeaponId = rg_get_weapon_info(szTempFmtItem, WI_ID)

	if (rg_get_user_active_weapon(id) == WeaponIdType:iWeaponId)
	{
		ucfirst(szName)
		menu_item_setname(iMenu, Item, fmt("%s \y*", szName))
	}
}

public MainMenu_Handler(id, iMenu, Item)
{
	if (!is_user_connected(id) || Item == MENU_EXIT)
		goto Destroy

	static szData[32], iAccess, iCallBack, szName[MAX_NAME_LENGTH * 2], szWeaponName[MAX_NAME_LENGTH]
	menu_item_getinfo(iMenu, Item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallBack)

	if (equali(szData, "MainMenu_SkinSection"))
	{
		replace_symbols_colors(szName)
		strtolower(szName)
		formatex(szWeaponName, charsmax(szWeaponName), "weapon_%s", szName)
		new iWeapon = rg_get_weapon_info(szWeaponName, WI_ID)

		Toggle_MainMenu(id, iWeapon)
		return PLUGIN_HANDLED
	}
	else
	{
		new iWeapon = str_to_num(szData)
		rg_get_weapon_info(iWeapon, WI_NAME, szWeaponName, charsmax(szWeaponName))

		replace_all(szWeaponName, charsmax(szWeaponName), "weapon_", "")
		ucfirst(szWeaponName)

		if (containi(szName, "Default Skin") != -1)
		{
			g_iCurrentWeapon[id][iWeapon] = -1
			client_print_color(id, print_team_default, "^4[xWSS] ^1You've ^3reset skin ^1for weapon ^3%s", szWeaponName)

			if (rg_get_user_active_weapon(id) == WeaponIdType:iWeapon)
			{
				strtolower(szWeaponName)
				rg_set_user_weapon_model_v(id, fmt("models/v_%s.mdl", szWeaponName))
				rg_set_user_weapon_model_p(id, fmt("models/p_%s.mdl", szWeaponName))
			}

			goto Destroy
		}

		g_iCurrentWeapon[id][iWeapon] = Item
		g_iCurrentWeapon[id][iWeapon]--

		if (rg_get_user_active_weapon(id) == WeaponIdType:iWeapon)
			eventCurWeapon(id)

		client_print_color(id, print_team_default, "^4[xWSS] ^1You've selected weapon ^3%s ^1with skin ^3%s", szWeaponName, szName)
	}

	Destroy:
	menu_destroy(iMenu)
	return PLUGIN_HANDLED
}

public Command_HookChat(id)
{
	new szArgs[64], szCommand[32]
	read_args(szArgs, charsmax(szArgs))
	remove_quotes(szArgs)
	parse(szArgs, szCommand, charsmax(szCommand))
	
	if (equal(szCommand, "/skins") || equal(szCommand, "/skin"))
		Toggle_MainMenu(id, 0)
	else if (szArgs[0] == '/')
	{
		new szWeaponName[MAX_NAME_LENGTH], szTemporaryCommand[32], szWeaponId[32]

		for (new loopWeapon = MIN_WEAPON_ID; loopWeapon < MAX_WEAPON_ID; loopWeapon++)
		{
			rg_get_weapon_info(loopWeapon, WI_NAME, szWeaponName, charsmax(szWeaponName))

			copy(szWeaponId, charsmax(szWeaponId), szWeaponName)

			replace_all(szWeaponName, charsmax(szWeaponName), "weapon_", "")

			formatex(szTemporaryCommand, charsmax(szTemporaryCommand), "/%s", szWeaponName)

			if (equal(szCommand, szTemporaryCommand) && g_bWeaponSkinAvailable[loopWeapon])
			{
				new iWeapon = rg_get_weapon_info(szWeaponId, WI_ID)
				Toggle_MainMenu(id, iWeapon)
			}
		}
	}
}
public eventCurWeapon(id)
{
	new iWeaponId = get_member(get_member(id, m_pActiveItem), m_iId)

	if (g_iCurrentWeapon[id][iWeaponId] == -1)
		return

	static iCurrentWeapon
	iCurrentWeapon = g_iCurrentWeapon[id][iWeaponId]
	ArrayGetString(g_aWeaponData[View_Model_Name][iWeaponId], iCurrentWeapon, szModel[VIEW], charsmax(szModel[]))
	ArrayGetString(g_aWeaponData[Player_Model_Name][iWeaponId], iCurrentWeapon, szModel[PLAYER], charsmax(szModel[]))

	rg_set_user_weapon_model_v(id, szModel[VIEW])

	if (!equal(szModel[PLAYER], ""))
		rg_set_user_weapon_model_p(id, szModel[PLAYER])
}

stock replace_symbols_colors(string[64])
{
	if (contain(string, "(") != -1)
	{
		replace_all(string, charsmax(string), "(", "")
		replace_all(string, charsmax(string), ")", "")
	}
	if (contain(string, "[") != -1)
	{
		replace_all(string, charsmax(string), "[", "")
		replace_all(string, charsmax(string), "]", "")
	}
	if (contain(string, "<") != -1)
	{
		replace_all(string, charsmax(string), "<", "")
		replace_all(string, charsmax(string), ">", "")
	}
	if (contain(string, "*") != -1)
	{
		replace_all(string, charsmax(string), "*", "")
		replace_all(string, charsmax(string), " ", "")
	}
	if (contain(string, "\") != -1)
	{
		replace_all(string, charsmax(string), "\y", "")
		replace_all(string, charsmax(string), "\r", "")
		replace_all(string, charsmax(string), "\d", "")
		replace_all(string, charsmax(string), "\w", "")
	}
}