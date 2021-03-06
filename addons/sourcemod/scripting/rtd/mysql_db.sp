#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks >
#include <geoip>
#include <rtd_rollinfo>

new rankedclients = 0;
new diceRankStat[34];
new credsRankStat[34];

public saveStats(client)
{
	//bots stats don't get saved
	if(IsFakeClient(client))
		return;
	
	//save all stats to the MySql server
	new String:clsteamId[MAX_LINE_WIDTH];
	new time = GetTime();
	
	if(IsClientInGame(client) && areStatsLoaded[client] && g_BCONNECTED)
	{
		////////////////////////////
		//FORUMULA 
		//Required size = (Amount of Perks) * 5 + (Amount of Perks - 1)
		//Sample perk: a00:0
		//Perks consist of 5 characters
		///////////////////////////////////
		new String:stringDiceLvls[600]; 
		
		//PerksLevels
		for(new i = 0; i < totalShopDicePerks; i++)
		{
			if(dicePerk_Reimburse[i] == 1 && dicePerk_Enabled[i] == 0)
				continue;
			
			if(i == 0)
			{
				Format(stringDiceLvls, sizeof(stringDiceLvls), "%s:%i", dicePerk_Unique[i], RTD_PerksLevel[client][dicePerk_Index[i]]);
			}else{
				Format(stringDiceLvls, sizeof(stringDiceLvls), "%s,%s:%i", stringDiceLvls, dicePerk_Unique[i], RTD_PerksLevel[client][dicePerk_Index[i]]);
			}
		}
		
		/////////////////////////////////////
		//Formula
		//Required Size= (Amount of Trinkets) * 7 + (Amount of Trinkets - 1) + 10
		//Trinket sample: t01:0:1
		//                trinket unique:trinket tier:is equipped?
		//30 trinkets total
		/////////////////////////////////////
		
		///////////////////
		//Save trinkets  //
		///////////////////
		new sizeOfTrinketData = (MAX_TRINKETS_HELD * 7) + (MAX_TRINKETS_HELD - 1) + 10;
		
		//make it a bit bigger just in case
		sizeOfTrinketData += 10; 
		
		new String:stringTrinkets[sizeOfTrinketData];
		
		for(new j = 0; j < MAX_TRINKETS_HELD; j++)
		{
			
			if(!StrEqual(RTD_TrinketUnique[client][j], "", false))
			{
				if(StrEqual(stringTrinkets, "", false))
				{
					Format(stringTrinkets, sizeOfTrinketData, "%s:%i:%i", RTD_TrinketUnique[client][j], RTD_TrinketTier[client][j],  RTD_TrinketEquipped[client][j]);
				}else{
					Format(stringTrinkets, sizeOfTrinketData, "%s,%s:%i:%i", stringTrinkets,  RTD_TrinketUnique[client][j], RTD_TrinketTier[client][j],  RTD_TrinketEquipped[client][j]);
				}
			}
		}
		
		//////////////////////////////
		//Finally prepare SQL query //
		//////////////////////////////
		GetClientAuthString(client, clsteamId, sizeof(clsteamId));
		
		new String:query[1024 + sizeOfTrinketData];
		
		Format(query, 1024 + sizeOfTrinketData, "UPDATE `Player` SET `CREDITS` = '%i', `DICE` = '%i', `OPTION1` = '%i', `OPTION2` = '%i', `OPTION3` = '%i', `OPTION4` = '%i', `HUDXPOS` = '%i', `HUDYPOS` = '%i', `HUDXPOS2` = '%i', `HUDYPOS2` = '%i', `LASTONTIME` = '%i', `OPTION5` = '%i', `SCOREENABLED` = '%i', `VOICEOPTIONS` = '%i', `BETATESTING` = '%i', `TALENTPOINTS` = '%i', `DICEPERKS` = '%s', `TRINKETS` = '%s' WHERE `STEAMID` = '%s'", RTDCredits[client], RTDdice[client], RTDOptions[client][0], RTDOptions[client][1], RTDOptions[client][2], RTDOptions[client][3], RoundFloat(HUDxPos[client][0] * 100), RoundFloat(HUDyPos[client][0] * 100), RoundFloat(HUDxPos[client][1] * 100), RoundFloat(HUDyPos[client][1] * 100), time, RTDOptions[client][4], ScoreEnabled[client], VoiceOptions[client], isBetaUser[client], talentPoints[client], stringDiceLvls, stringTrinkets, clsteamId);
		
		//LogMessage("saveStats(client): %s", query);
		
		SQL_TQuery(db,SQLErrorCheckCallback, query);
	}
}

public addCredits(creditsToAdd, award)
{
	new String:clsteamId[MAX_LINE_WIDTH];
	
	//check to see if player is in server first
	for(new i=1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsClientAuthorized(i) && areStatsLoaded[i] && g_BCONNECTED)
		{
			GetClientAuthString(i, clsteamId, sizeof(clsteamId));
			
			//we found a match!
			if(StrEqual(clsteamId, roll_OwnerSteamID[award], true))
			{
				EmitSoundToClient(i, SOUND_BOUGHTSOMETHING);
				PrintCenterText(i, "You received %i Credits from %s", creditsToAdd, roll_Text[award]);
				PrintToChat(i, "You received %i Credits from %s", creditsToAdd, roll_Text[award]);
				
				RTDCredits[i] += creditsToAdd;
				
				return;
			}
		}
	}
	
	//Player is not in game, let's try to add the credits to the database then
	new String:query[1024];
	//UPDATE `numbers` SET `number` = +1 WHERE `pageid` = '$pageid'";
	//PrintToChatAll("Attempting to add %i Credits to %s",creditsToAdd, roll_OwnerSteamID[award]);
	
	//UPDATE `rtd_gamedb`.`player` SET `CREDITS` = `CREDITS` + '30' WHERE `player`.`STEAMID` = 'STEAM_0:0:16952541';
	
	Format(query, sizeof(query), "UPDATE `Player` SET `CREDITS` = `CREDITS` + '%i' WHERE `STEAMID` = '%s'", creditsToAdd, roll_OwnerSteamID[award]);
	
	SQL_TQuery(db,SQLErrorCheckCallback, query);
}

openDatabaseConnection()
{
	if (SQL_CheckConfig("rtdbank"))
	{
		SQL_TConnect	(cDatabaseConnect, "rtdbank");
	}else{
		LogToFile(logPath,"Unable to open rtdbank: No such database configuration.");
		g_BCONNECTED 	= false;
	}
}

public cDatabaseConnect(Handle:arg_hOwner, Handle:argHQuery, const String:argsError[], any:argData) 
{
	//new String:strDB[128];
	//GetConVarString		(g_CVDB, strDB, sizeof(strDB));
	if (argHQuery == INVALID_HANDLE)
	{
		LogToFile(logPath,"Unable to connect to rtdbank: %s", argsError);
		g_BCONNECTED = false;
	}
	else
	{
		if (!SQL_FastQuery(argHQuery, "SET NAMES 'utf8'"))
		{
			LogToFile(logPath,"Unable to change to utf8 mode.");
			g_BCONNECTED = false;
		}
		else
		{
			db = argHQuery;
			g_BCONNECTED = true;
			
			//Loads awards after Database has been connected
			LoadAwards();
			
			if(lateLoaded)
			{
				initonlineplayers();
			}
		}
	}
}

public updateplayername(client)
{
	//bots stats don't get saved
	if(IsFakeClient(client))
		return;
	
	new String:steamId[MAX_LINE_WIDTH];
	new String:name[MAX_LINE_WIDTH];
	GetClientName(client, name, sizeof(name));
	
	ReplaceString(name, sizeof(name), "\\", "", true);
	SQL_EscapeString(db, name, name, sizeof(name));
	if(IsFakeClient(client))
	{
		GetClientAuthString(client, steamId, sizeof(steamId));
		Format(steamId, sizeof(steamId), "%s-%s", steamId, name);
	}
	else
	{
		GetClientAuthString(client, steamId, sizeof(steamId));
	}
	
	new String:query[100];
	Format(query, sizeof(query), "UPDATE Player SET NAME = '%s' WHERE STEAMID = '%s'",name ,steamId);
	
	//LogMessage("updateplayername(client): %s", query);
	
	SQL_TQuery(db,SQLErrorCheckCallback, query);
}

public initonlineplayers()
{
	if(g_BCONNECTED && lateLoaded)
	{
		for (new i=1; i<=MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(!IsFakeClient(i))
				{
					SetHudTextParams(0.42, 0.22, 20.0, 250, 250, 210, 255);
					ShowHudText(i, HudMsg3, "Connecting to Database...");
					areStatsLoaded[i] = false;
					//updateplayername(i);
					//InitializeClientonDB(i);
				}
			}
		}
	}
}

/* New Code Full Threaded SQL Clean Code ---------------------------------------*/
public SQLErrorCheckCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(!StrEqual("", error))
	{
	LogToFile(logPath,"SQL Error: %s | Data %s", error, data);
	}
	
}

public InitializeClientonDB(client)
{
	//bots stats don't get saved
	if(IsFakeClient(client))
		return;
	
	CleanPlayer(client);
	
	new String:ConUsrSteamID[MAX_LINE_WIDTH];
	new String:buffer[255];
	
	if(IsFakeClient(client))
	{
		new String:ClientName[MAX_LINE_WIDTH];
		GetClientName(client, ClientName, sizeof(ClientName));
		GetClientAuthString(client, ConUsrSteamID, sizeof(ConUsrSteamID));
		
		ReplaceString(ClientName, sizeof(ClientName), "\\", "", true);
		SQL_EscapeString(db, ClientName, ClientName, sizeof(ClientName));
		Format(ConUsrSteamID, sizeof(ConUsrSteamID), "%s-%s", ConUsrSteamID, ClientName);
	}
	else
	{
		GetClientAuthString(client, ConUsrSteamID, sizeof(ConUsrSteamID));
	}
	
	SetHudTextParams(0.42, 0.22, 5.0, 250, 250, 210, 255);
	ShowHudText(client, HudMsg3, "Loading...");
	
	Format(buffer, sizeof(buffer), "SELECT * FROM Player WHERE STEAMID = '%s'", ConUsrSteamID);
	
	//LogMessage("InitializeClientonDB(client): %s", buffer);
	
	SQL_TQuery(db, LoadEverythingAtOnce, buffer, GetClientUserId(client));
}

public LoadTrinkets_Upgraded_SQL(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new foundTrinket;
	
	//Just for trinkets
	new client;
	new String:chatMessage[128];
	
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Trinkets Query failed! %s", error);
	} else 
	{
		if (!SQL_GetRowCount(hndl)) 
		{
		}
		else
		{
			while (SQL_FetchRow(hndl))
			{
				
				new String:temp_TrinketUnique[4];
				SQL_FetchString(hndl,2, temp_TrinketUnique, sizeof(temp_TrinketUnique));
				
				//Find the read unique identifier
				for(new j = 0; j < MAX_TRINKETS; j++)
				{
					
					if(StrEqual(temp_TrinketUnique, trinket_Unique[j], true))
					{
						Format(RTD_TrinketUnique[client][foundTrinket], 64, "%s", trinket_Unique[j]);
						RTD_TrinketIndex[client][foundTrinket] = trinket_Index[j];
						
						RTD_TrinketTier[client][foundTrinket] = SQL_FetchInt(hndl,3);
						RTD_TrinketEquipped[client][foundTrinket] = SQL_FetchInt(hndl,5);
						
						Format(RTD_TrinketTitle[client][foundTrinket], 32, "%s", trinket_Title[j]);
						
						//apply stats
						if(RTD_TrinketEquipped[client][foundTrinket] == 1)
						{
							RTD_TrinketActive[client][trinket_Index[j]] = 1;
							RTD_TrinketBonus[client][trinket_Index[j]] = trinket_BonusAmount[trinket_Index[j]][RTD_TrinketTier[client][foundTrinket]];
							RTD_TrinketLevel[client][trinket_Index[j]] = RTD_TrinketTier[client][foundTrinket];
							RTD_TrinketMisc[client][trinket_Index[j]] = 0;
							
							Format(chatMessage, sizeof(chatMessage), "\x03Equipped\x04 (\x03%s\x04)\x01%s \x04Trinket", trinket_TierID[RTD_TrinketIndex[client][foundTrinket]][RTD_TrinketTier[client][foundTrinket]], trinket_Title[RTD_TrinketIndex[client][foundTrinket]]);
							PrintToChat(client, chatMessage); 
						}else{
							RTD_TrinketActive[client][trinket_Index[j]] = 0;
							RTD_TrinketBonus[client][trinket_Index[j]] = 0;
							RTD_TrinketLevel[client][trinket_Index[j]] = 0;
							RTD_TrinketMisc[client][trinket_Index[j]] = 0;
						}
						
						foundTrinket ++;
						break;
					}
				}
				
				
				//---------------------------------------------------------
				
				//ehh, there no player here mate
				if ((client = GetClientOfUserId(data)) == 0)
					return;
				
				SetHudTextParams(0.42, 0.22, 5.0, 250, 250, 210, 255);
				ShowHudText(client, HudMsg3, "Trinkets loaded!");
				
				CreateTimer(0.1,  	Timer_DelayTrinketEquip, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
				
				PrintToChat(client, "Trinket upgrade: SUCCESS!");
				
				if(foundTrinket >= 20)
					return;
			}
		}
		
		return;
	}
	return;
}

public LoadEverythingAtOnce(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	//Everything is loaded all at once instead of being threaded!
	//Problems? Dunno until you try!
	new client;
	
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
		if (!SQL_GetRowCount(hndl)) 
		{
			new String:ClientSteamID[MAX_LINE_WIDTH];
			
			if(IsFakeClient(client))
			{
				new String:ClientName[MAX_LINE_WIDTH];
				GetClientName(client, ClientName, sizeof(ClientName));
				GetClientAuthString(client, ClientSteamID, sizeof(ClientSteamID));
				
				ReplaceString(ClientName, sizeof(ClientName), "\\", "", true);
				SQL_EscapeString(db, ClientName, ClientName, sizeof(ClientName));
				Format(ClientSteamID, sizeof(ClientSteamID), "%s-%s", ClientSteamID, ClientName);
			}
			else
			{
				GetClientAuthString(client, ClientSteamID, sizeof(ClientSteamID));
			}
			
			/*insert user*/
			new String:buffer[255];
			new String:clientname[MAX_LINE_WIDTH];
			
			GetClientName( client, clientname, sizeof(clientname) );
			
			ReplaceString(clientname, sizeof(clientname), "\\", "", true);
			SQL_EscapeString(db, clientname, clientname, sizeof(clientname));
			
			Format(buffer, sizeof(buffer), "INSERT INTO Player (`NAME`,`STEAMID`) VALUES ('%s','%s')", clientname, ClientSteamID);
			
			SQL_TQuery(db, SQLErrorCheckCallback, buffer);
			
			//Client has successfully retrieved all info from the database
			areStatsLoaded[client] = true;
			
			PrintToChatAll("[RTD] Welcome to RTDGaming %s", clientname);
			
			HUDxPos[client][0] = 0.70;
			HUDyPos[client][0] = 0.94;
			HUDxPos[client][1] = 0.70;
			HUDyPos[client][1] = 0.97;
			
			isNewUser[client] = true;
		}
		else
		{
			while (SQL_FetchRow(hndl))
			{
				//These should match the order in which they are in the SQL DB
				RTDCredits[client] = SQL_FetchInt(hndl,2);
				RTDdice[client] = SQL_FetchInt(hndl,3);
				RTDOptions[client][0] = SQL_FetchInt(hndl,4);
				RTDOptions[client][1] = SQL_FetchInt(hndl,5);
				RTDOptions[client][2] = SQL_FetchInt(hndl,6);
				
				RTDOptions[client][3] = SQL_FetchInt(hndl,7);
				
				if(RTDOptions[client][3] == 1)
					RTDOptions[client][3] = 0;
				
				HUDxPos[client][0] = float(SQL_FetchInt(hndl,8)) / 100;
				HUDyPos[client][0] = float(SQL_FetchInt(hndl,9)) / 100;
				
				HUDxPos[client][1] = float(SQL_FetchInt(hndl,11)) / 100;
				HUDyPos[client][1] = float(SQL_FetchInt(hndl,12)) / 100;
				
				RTDOptions[client][4] = SQL_FetchInt(hndl,13);
				ScoreEnabled[client] = SQL_FetchInt(hndl,14);
				
				VoiceOptions[client] = SQL_FetchInt(hndl,15);
				isBetaUser[client] = SQL_FetchInt(hndl,16);
				
				//admins are Beta suer's
				if(GetUserAdmin(client) != INVALID_ADMIN_ID)
					isBetaUser[client] = 1;
				
				talentPoints[client] = SQL_FetchInt(hndl,17);
				
				//------------------------------------------------------
				new String:stringDicePerks[600];
				SQL_FetchString(hndl,18, stringDicePerks, sizeof(stringDicePerks));
				
				//Handle the dice perks
				new String:partsDicePerk[maxPerks][16];
				ExplodeString(stringDicePerks, ",", partsDicePerk, 100, 16);
				
				//Split up the strings :
				for(new i = 0; i < maxPerks; i++)
				{
					new String:finalSplit[2][16];
					
					ExplodeString(partsDicePerk[i], ":", finalSplit, 2, 16); 
					
					//Find the read unique identifier
					for(new j = 0; j < maxPerks; j++)
					{
						if(StrEqual(finalSplit[0], "", true))
							continue;
						
						if(StrEqual(finalSplit[0], dicePerk_Unique[j], true))
						{
							//PrintToServer("Pass: %i || Loaded Unique: %s Saved To Index: %i", j, finalSplit[0], dicePerk_Index[j]);
							Format(RTD_Perks_Unique[client][dicePerk_Index[j]], 32, finalSplit[0]);
							RTD_PerksLevel[client][dicePerk_Index[j]] = StringToInt(finalSplit[1]);
							
							break;
						}
					}
				}
				//---------------------------------------------------------
				new sizeOfTrinketData = (MAX_TRINKETS_HELD * 7) + (MAX_TRINKETS_HELD - 1) + 10;
				
				//make it a bit bigger just in case
				sizeOfTrinketData += 10; 
				
				new String:stringTrinkets[sizeOfTrinketData];
				SQL_FetchString(hndl,19, stringTrinkets, sizeOfTrinketData);
				
				if(StrEqual(stringTrinkets, "-1", true))
				{
					//no data check old trinket db
					
					new String:buffer[255];
					new String:ClientSteamID[MAX_LINE_WIDTH];
					
					GetClientAuthString(client, ClientSteamID, sizeof(ClientSteamID));
					Format(buffer, sizeof(buffer), "SELECT * FROM trinkets_v2 WHERE STEAMID = '%s'", ClientSteamID);
					
					SQL_TQuery(db, LoadTrinkets_Upgraded_SQL, buffer, GetClientUserId(client));
				}else{
					//Handle the trinkets
					new String:partsTrinkets[MAX_TRINKETS_HELD][16];
					ExplodeString(stringTrinkets, ",", partsTrinkets, MAX_TRINKETS_HELD + 1, 16);
					
					new clientTotalTrinkets;
					
					//Split up the strings ...
					for(new trinketParser = 0; trinketParser < MAX_TRINKETS_HELD; trinketParser++)
					{
						new String:finalTSplit[3][16];
						
						ExplodeString(partsTrinkets[trinketParser], ":", finalTSplit, 3, 16); 
						
						//Find the read unique identifier
						for(new j = 0; j < MAX_TRINKETS; j++)
						{
							if(StrEqual(finalTSplit[0], "", true))
								continue;
							
							if(StrEqual(finalTSplit[0], trinket_Unique[j], true))
							{
								//PrintToChatAll("Incr: %i | %s | %s | Index: %i", j, trinket_Title[j], trinket_Unique[j], trinket_Index[j]);
								
								Format(RTD_TrinketUnique[client][clientTotalTrinkets], 64, "%s", trinket_Unique[j]);
								RTD_TrinketIndex[client][clientTotalTrinkets] = trinket_Index[j];
								
								RTD_TrinketTier[client][clientTotalTrinkets] = StringToInt(finalTSplit[1]);
								RTD_TrinketEquipped[client][clientTotalTrinkets] = StringToInt(finalTSplit[2]);
								
								Format(RTD_TrinketTitle[client][clientTotalTrinkets], 32, "%s", trinket_Title[j]);
								
								//apply stats
								if(RTD_TrinketEquipped[client][clientTotalTrinkets] == 1)
								{
									RTD_TrinketActive[client][trinket_Index[j]] = 1;
									RTD_TrinketBonus[client][trinket_Index[j]] = trinket_BonusAmount[trinket_Index[j]][RTD_TrinketTier[client][clientTotalTrinkets]];
									RTD_TrinketLevel[client][trinket_Index[j]] = RTD_TrinketTier[client][clientTotalTrinkets];
									RTD_TrinketMisc[client][trinket_Index[j]] = 0;
									
									new String:chatMessage[128];
									Format(chatMessage, sizeof(chatMessage), "\x03Equipped\x04 (\x03%s\x04)\x01%s \x04Trinket", trinket_TierID[RTD_TrinketIndex[client][clientTotalTrinkets]][RTD_TrinketTier[client][clientTotalTrinkets]], trinket_Title[RTD_TrinketIndex[client][clientTotalTrinkets]]);
									PrintToChat(client, chatMessage); 
								}else{
									RTD_TrinketActive[client][trinket_Index[j]] = 0;
									RTD_TrinketBonus[client][trinket_Index[j]] = 0;
									RTD_TrinketLevel[client][trinket_Index[j]] = 0;
									RTD_TrinketMisc[client][trinket_Index[j]] = 0;
								}
								
								clientTotalTrinkets ++;
								break;
							}
						}
					}
				}
				//---------------------------------------------------------
				if(HUDxPos[client][0] == 0)
					HUDxPos[client][0] = 0.70;
				
				if(HUDyPos[client][0] == 0)
					HUDyPos[client][0] = 0.94;
				
				if(HUDxPos[client][1] == 0)
					HUDxPos[client][1] = 0.70;
				
				if(HUDyPos[client][1] == 0)
					HUDyPos[client][1] = 0.97;
				
				if ((client = GetClientOfUserId(data)) == 0)
				{
					return;
				}
				else
				{
					areStatsLoaded[client] = true;
					
					SetHudTextParams(0.42, 0.22, 5.0, 250, 250, 210, 255);
					ShowHudText(client, HudMsg3, "Connected to Database!");
				}
				
				if(talentPoints[client] < 0)
				{
					//Do a full reset
					for(new ii = 0; ii < maxPerks; ii++)
					{
						RTD_Perks[client][ii] = 0;
						RTD_PerksLevel[client][ii] = 0; //important to clear out when it's a "new" user
					}
					
					ClearOutAllPerksOnUser(client);
					
					new TFClassType:class = TF2_GetPlayerClass(client);
					
					if(class != TFClass_Unknown)
						show_newUser_TalentPoints_msg(client);
					
				}else
				{
					new TFClassType:class = TF2_GetPlayerClass(client);
					
					if(class != TFClass_Unknown)
						showWelcomeBackPanel(client);
				}
				
				SetHudTextParams(0.42, 0.22, 5.0, 250, 250, 210, 255);
				ShowHudText(client, HudMsg3, "Trinkets loaded!");
				
				CreateTimer(0.1,  	Timer_DelayTrinketEquip, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		
		return;
	}
	return;
}

public Action:DiceRankPanel(client)
{
	new Handle:rnkpanel = CreatePanel();
	new String:value[MAX_LINE_WIDTH];
	
	new String: name[32];
	GetClientName(client, name, sizeof(name));
	
	DrawPanelItem(rnkpanel, "Credits Rank:");
	
	Format(value, sizeof(value), "    Position %i of %i", credsRankStat[client],rankedclients);
	DrawPanelText(rnkpanel, value);
	
	Format(value, sizeof(value), "    %i Credits", RTDCredits[client]);
	DrawPanelText(rnkpanel, value);
	
	DrawPanelItem(rnkpanel, "Dice Rank:");
	
	Format(value, sizeof(value), "    Position %i of %i", diceRankStat[client],rankedclients);
	
	DrawPanelText(rnkpanel, value);
	Format(value, sizeof(value), "    %i Dice", RTDdice[client]);
	DrawPanelText(rnkpanel, value);
	

	DrawPanelItem(rnkpanel, "Close");
	SendPanelToClient(rnkpanel, client, SessionRankPanelHandler, 20);
	
	PrintToChatAll("\x01\x04[RTD Rank] \x03%s:\x04 Creds Pos:%i/%i (%i) | Dice Pos: %i/%i (%i)",name,credsRankStat[client],rankedclients, RTDCredits[client], diceRankStat[client],rankedclients, RTDdice[client]);

	CloseHandle(rnkpanel);
 
	return Plugin_Handled;
}

public SessionRankPanelHandler(Handle:menu, MenuAction:action, param1, param2)
{
}

public rankpanel(client)
{
	new String:buffer[255];
	Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM `Player`");
	SQL_TQuery(db, T_ShowRank1, buffer, GetClientUserId(client));
}

public T_ShowRank1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
		while (SQL_FetchRow(hndl))
		{
			rankedclients = SQL_FetchInt(hndl,0);
			
			new String:buffer[255];
			Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM `Player` WHERE `CREDITS` >=%i", RTDCredits[client]);
			SQL_TQuery(db, T_ShowRank2, buffer, data);
		}
	}
}
public T_ShowRank2(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
	while (SQL_FetchRow(hndl))
	{
		credsRankStat[client] = SQL_FetchInt(hndl,0);
		
		new String:buffer[255];
		Format(buffer, sizeof(buffer), "SELECT COUNT(*) FROM `Player` WHERE `DICE` >=%i", RTDdice[client]);
		SQL_TQuery(db, T_ShowRank3, buffer, data);
		}
	}
}
public T_ShowRank3(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
 
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
		while (SQL_FetchRow(hndl))
		{
			diceRankStat[client] = SQL_FetchInt(hndl,0);
		}
		
		DiceRankPanel(client);
	}
}

public top10pnl(client)
{
	
	new String:buffer[255];
	Format(buffer, sizeof(buffer), "SELECT NAME,credits FROM `Player` ORDER BY CREDITS DESC LIMIT 0,100");
	SQL_TQuery(db, T_ShowTOP1, buffer, GetClientUserId(client));
}

public T_ShowTOP1(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
	
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
		
		new Handle:menu = CreateMenu(TopMenuHandler1);
		SetMenuTitle(menu, "Credits Ranking:");
		
		new i  = 1;
		new String:plname[32];
		new creds;
		
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl,0, plname , 32);
			creds = SQL_FetchInt(hndl,1);
			
			new String:menuline[40];
			Format(menuline, sizeof(menuline), "(%i) %s", creds, plname);
			AddMenuItem(menu, "", menuline );
			
			i++;
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 60);
		
		return;
	}
	return;
}

public TopMenuHandler1(Handle:menu, MenuAction:action, param1, param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		new String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		//rankpanel(param1);
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_Cancel)
	{
		//PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
	/* If the menu has ended, destroy it */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}




public top10Dice(client)
{
	
	new String:buffer[255];
	Format(buffer, sizeof(buffer), "SELECT NAME,dice FROM `Player` ORDER BY DICE DESC LIMIT 0,100");
	SQL_TQuery(db, T_ShowTOP1DICE, buffer, GetClientUserId(client));
}

public T_ShowTOP1DICE(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new client;
	
	/* Make sure the client didn't disconnect while the thread was running */
	if ((client = GetClientOfUserId(data)) == 0)
	{
		return;
	}
 
	if (hndl == INVALID_HANDLE)
	{
		LogToFile(logPath,"Query failed! %s", error);
	} else 
	{
		
		new Handle:menu = CreateMenu(TopMenuHandler1);
		SetMenuTitle(menu, "Dice Ranking:");
		
		new i  = 1;
		new String:plname[32];
		new creds;
		
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl,0, plname , 32);
			creds = SQL_FetchInt(hndl,1);
			
			new String:menuline[40];
			Format(menuline, sizeof(menuline), "(%i) %s", creds, plname);
			AddMenuItem(menu, "", menuline );
			
			i++;
		}
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, 60);
		
		return;
	}
	return;
}