#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <attachments>
#include <rtd_rollinfo>

public Action:SpawnAndAttachClientDynamite(client, originalEntity)
{	
	new ent = CreateEntityByName("prop_dynamic_override");
	if ( ent == -1 )
	{
		ReplyToCommand( client, "Failed to create a Dynamite!" );
		return Plugin_Handled;
	}
	
	if(!RTD_TrinketActive[client][TRINKET_EXPLOSIVEDEATH])
		return Plugin_Stop;
	
	SetEntityModel(ent, MODEL_DYNAMITE);
	
	//Set the Dynamite's owner
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	SDKHook(ent, SDKHook_SetTransmit, Hook_ClientBlizzard);  //Hook_EveryoneBlizzard - Hook_ClientBlizzard
	
	DispatchSpawn(ent);
	CAttach(ent, client, "flag");
	
	new Float:pos[3];
	
	if(TF2_GetPlayerClass(client) == TFClass_Pyro)
		pos[2] = 7.0;
	
	if(TF2_GetPlayerClass(client) == TFClass_Medic)
		pos[2] = 5.0;
	
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	
	
	decl String:dynamiteName[32];
	Format(dynamiteName, 32, "dynamiteclient_%i", ent);
	DispatchKeyValue(ent, "targetname", dynamiteName);
	
	AcceptEntityInput( ent, "DisableShadow" );
	
	AcceptEntityInput( ent, "DisableCollision" );
	
	
	//The Datapack stores all the Backpack's important values
	new Handle:dataPackHandle;
	CreateDataTimer(0.3, Client_Dynamite_Timer, dataPackHandle, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
	
	//Setup the datapack with appropriate information
	WritePackCell(dataPackHandle, EntIndexToEntRef(ent));   //PackPosition(0);  Backpack Index
	WritePackCell(dataPackHandle, GetClientUserId(client));     //PackPosition(8) ;  Amount of ammopacks
	WritePackCell(dataPackHandle, 0);     //PackPosition(8) ; unused was a particle
	WritePackCell(dataPackHandle, 1);     //PackPosition(24) ;  client only
	WritePackCell(dataPackHandle, EntIndexToEntRef(originalEntity));     //PackPosition(24) ;  client only
	
	return Plugin_Handled;
}

public Action:SpawnAndAttachDynamite(client)
{	
	new ent = CreateEntityByName("prop_dynamic_override");
	if ( ent == -1 )
	{
		ReplyToCommand( client, "Failed to create a Dynamite!" );
		return Plugin_Handled;
	}
	
	if(!RTD_TrinketActive[client][TRINKET_EXPLOSIVEDEATH])
		return Plugin_Stop;
	
	SetEntityModel(ent, MODEL_DYNAMITE);
	
	decl String:dynamiteName[32];
	Format(dynamiteName, 32, "dynamite_%i", ent);
	DispatchKeyValue(ent, "targetname", dynamiteName);
	
	//Set the Dynamite's owner
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	
	SDKHook(ent, SDKHook_SetTransmit, Hook_EveryoneBlizzard ); //Hook_ClientBlizzard - Hook_EveryoneBlizzard
	
	DispatchSpawn(ent);
	CAttach(ent, client, "flag");
	
	new Float:pos[3];
	
	if(TF2_GetPlayerClass(client) == TFClass_Pyro)
		pos[2] = 7.0;
	
	if(TF2_GetPlayerClass(client) == TFClass_Medic)
		pos[2] = 5.0;
	
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	
	
	AcceptEntityInput( ent, "DisableShadow" );
	
	//new particle = AttachFastParticle3(ent, client, 0, "candle_light1", 0.0, "CENTER");
	
	
	
	AcceptEntityInput( ent, "DisableCollision" );
	
	RTD_TrinketMisc[client][TRINKET_EXPLOSIVEDEATH] = EntIndexToEntRef(ent);
	
	//The Datapack stores all the Backpack's important values
	new Handle:dataPackHandle;
	CreateDataTimer(0.3, Dynamite_Timer, dataPackHandle, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
	
	//Setup the datapack with appropriate information
	WritePackCell(dataPackHandle, EntIndexToEntRef(ent));   //PackPosition(0);  Backpack Index
	WritePackCell(dataPackHandle, GetClientUserId(client));     //PackPosition(8) ;  Amount of ammopacks
	WritePackCell(dataPackHandle, 0);     //PackPosition(16) ; unsused was a particle
	WritePackCell(dataPackHandle, 0);     //PackPosition(24) ;  client only
	WritePackCell(dataPackHandle, 0);     //PackPosition(32) ;  original entity
	
	SpawnAndAttachClientDynamite(client, ent);
	
	return Plugin_Handled;
}

public Action:Client_Dynamite_Timer(Handle:timer, Handle:dataPackHandle)
{
	////////////////////////////////
	//Should we stop this timer?  //
	////////////////////////////////
	if(stopDynamiteTimer(dataPackHandle))
		return Plugin_Stop;
	
	//////////////////////////////////////////
	//Retrieve the values from the dataPack //
	// Set to the beginning and unpack it   //
	//////////////////////////////////////////
	ResetPack(dataPackHandle);
	new dynamite = EntRefToEntIndex(ReadPackCell(dataPackHandle));
	new client = GetClientOfUserId(ReadPackCell(dataPackHandle));
	
	
	/////////////////
	//Update Alpha //
	/////////////////
	new alpha = GetEntData(client, m_clrRender + 3, 1);
	
	if(!(TF2_IsPlayerInCondition(client, TFCond_Taunting) || TF2_IsPlayerInCondition(client, TFCond_Bonked) || GetEntData(client, m_iStunFlags) & TF_STUNFLAG_THIRDPERSON))
	{
		alpha = 0;
	}
	
	
	if(TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		{
			SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
			SetEntityRenderColor(dynamite, 255, 255,255, 0);
			
		}else{
			SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
			SetEntityRenderColor(dynamite, 255, 255,255, alpha);
		}
	}else{
		SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
		SetEntityRenderColor(dynamite, 255, 255,255, alpha);
	}
	
	////////////////////
	// Determine skin //
	////////////////////
	new skin = GetEntProp(dynamite, Prop_Data, "m_nSkin");
	
	if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
	{	
		if(skin == 0 || skin == 2)
		{
			if(GetClientTeam(client) == RED_TEAM)
			{
				DispatchKeyValue(dynamite, "skin","1"); 
			}else{
				DispatchKeyValue(dynamite, "skin","3"); 
			}
		}
	}else{
		if(GetClientTeam(client) == RED_TEAM)
		{
			if(skin != 0)
				DispatchKeyValue(dynamite, "skin","0"); 
		}else{
			if(skin != 2)
				DispatchKeyValue(dynamite, "skin","2");
		}
	}
	
	return Plugin_Continue;
}

public Action:Dynamite_Timer(Handle:timer, Handle:dataPackHandle)
{
	////////////////////////////////
	//Should we stop this timer?  //
	////////////////////////////////
	if(stopDynamiteTimer(dataPackHandle))
		return Plugin_Stop;
	
	//////////////////////////////////////////
	//Retrieve the values from the dataPack //
	// Set to the beginning and unpack it   //
	//////////////////////////////////////////
	ResetPack(dataPackHandle);
	new dynamite = EntRefToEntIndex(ReadPackCell(dataPackHandle));
	new client = GetClientOfUserId(ReadPackCell(dataPackHandle));
	
	
	/////////////////
	//Update Alpha //
	/////////////////
	new alpha = GetEntData(client, m_clrRender + 3, 1);
	
	if(TF2_GetPlayerClass(client) == TFClass_Spy)
	{
		if(TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		{
			SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
			SetEntityRenderColor(dynamite, 255, 255,255, 0);
		}else{
			SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
			SetEntityRenderColor(dynamite, 255, 255,255, alpha);
		}
	}else{
		SetEntityRenderMode(dynamite, RENDER_TRANSCOLOR);	
		SetEntityRenderColor(dynamite, 255, 255,255, alpha);
	}
	
	////////////////////
	// Determine skin //
	////////////////////
	new skin = GetEntProp(dynamite, Prop_Data, "m_nSkin");
	
	if(TF2_IsPlayerInCondition(client, TFCond_Ubercharged))
	{	
		if(skin == 0 || skin == 2)
		{
			if(GetClientTeam(client) == RED_TEAM)
			{
				DispatchKeyValue(dynamite, "skin","1"); 
			}else{
				DispatchKeyValue(dynamite, "skin","3"); 
			}
		}
	}else{
		if(GetClientTeam(client) == RED_TEAM)
		{
			if(skin != 0)
				DispatchKeyValue(dynamite, "skin","0"); 
		}else{
			if(skin != 2)
				DispatchKeyValue(dynamite, "skin","2");
		}
	}
	
	return Plugin_Continue;
}

public stopDynamiteTimer(Handle:dataPackHandle)
{	
	ResetPack(dataPackHandle);
	new dynamite = EntRefToEntIndex(ReadPackCell(dataPackHandle));
	new client = GetClientOfUserId(ReadPackCell(dataPackHandle));
	
	SetPackPosition(dataPackHandle, 24);
	new clientOnly = ReadPackCell(dataPackHandle);
	new originalEntity = EntRefToEntIndex(ReadPackCell(dataPackHandle));
	
	if(!IsValidEntity(dynamite))
		return true;
	
	if(client == 0)
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	if(RTD_TrinketActive[client][TRINKET_EXPLOSIVEDEATH] == 0)
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	if(!IsPlayerAlive(client))
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	if(RTD_TrinketMisc[client][TRINKET_EXPLOSIVEDEATH] == 0)
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	new savedEntity;
	
	if(clientOnly)
	{
		savedEntity = originalEntity;
	}else{
		savedEntity = EntRefToEntIndex(RTD_TrinketMisc[client][TRINKET_EXPLOSIVEDEATH]);
	}
	
	if(!IsValidEntity(savedEntity))
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	if(clientOnly == 0 && savedEntity != dynamite)
	{
		CDetach(dynamite);
		killEntityIn(dynamite, 0.1);
		return true;
	}
	
	return false;
}