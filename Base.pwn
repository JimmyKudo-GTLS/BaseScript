#include <a_samp>
#include <a_mysql> // Currently its R41-4.
#include <bcrypt> //Bcrypt is the best way of encrypting passwords.

//Defining MySQL stuff here

#define DB_HOST "localhost" //IP of your host. In case of using it on same pc, use localhost or 127.0.0.1
#define DB_NAME "login" //Name of Database you are gonna use.. I have used login, but change it according to your needs.
#define DB_USER "root" //User name of your MySQL client.
#define DB_PASS "" //Password of your MySQL client.

//Default Username is root and password is blank. You still gotta define them
//Make sure to install XAMPP server. Start Apache and MySQL service when you start the server. You can manage SQL databases from PHPMyAdmin which comes in built in XAMPP.

enum DIALOG_IDs //Always use some kind of structure for Dialog IDs.
{
	DIALOG_ASK,
	DIALOG_REGISTER,
	DIALOG_LOGIN
};

enum pinfo
{
	MasterID,
	Float:PX,
	Float:PY,
	Float:PZ,
	Float:Rot,
	Skin,
	Level
};
new pInfo[MAX_PLAYERS][pinfo];

new MySQL:handle; //This connection handle of data type MySQL is required to carry out Mysql operations.

main()
{
	printf("Login Script Loaded");
}

public OnGameModeInit()
{
	handle = mysql_connect(DB_HOST, DB_USER, DB_PASS, DB_NAME);
	
	if(mysql_errno() == 0) printf("[MYSQL] Connection successful"); //returns number of errors. 0 means no errors..
	else
	{
	    new error[100];
	    mysql_error(error, sizeof(error), handle);
		printf("[MySQL] Connection Failed : %s", error);
	}
	
	return 1;
}

public OnGameModeExit()
{
	return 1;
}

public OnPlayerConnect(playerid)
{
	new query[64];
	new pname[MAX_PLAYER_NAME];
	GetPlayerName(playerid, pname, sizeof(pname));
	mysql_format(handle, query, sizeof(query), "SELECT * from `Users` where Name = '%s' ", pname);
	mysql_tquery(handle, query, "OnPlayerJoin", "d", playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	new query[128], pname[MAX_PLAYER_NAME], Float:px, Float:py, Float:pz, Float:rot;
 	GetPlayerName(playerid, pname, sizeof(pname));
	GetPlayerPos(playerid, px, py, pz);
	GetPlayerFacingAngle(playerid, rot);
	mysql_format(handle, query, sizeof(query), "UPDATE `Users` set PosX = %f, PosY = %f, PosZ = %f, Rot = %f, Skin = %d, Level = %d WHERE Master_ID = %d", px, py, pz, rot, pInfo[playerid][Skin], pInfo[playerid][Level], pInfo[playerid][MasterID]);
	mysql_query(handle, query);
	printf("Saved %s's position", pname);
	return 1;
}

public OnPlayerSpawn(playerid)
{
    //Set your spawn info here...
	SetPlayerPos(playerid, pInfo[playerid][PX], pInfo[playerid][PY], pInfo[playerid][PZ]);
	SetPlayerCameraPos(playerid, pInfo[playerid][PX], pInfo[playerid][PY], pInfo[playerid][PZ]);
	SetPlayerCameraLookAt(playerid, pInfo[playerid][PX], pInfo[playerid][PY], pInfo[playerid][PZ]);

	new name[64];
    format(name, sizeof(name), "{00FF22}Welcome to the server, {FFFFFF}%s", name);
	SendClientMessage(playerid, -1, name);
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid)
	{
		case DIALOG_REGISTER:
	    {
			if(response)
			{
			    bcrypt_hash(inputtext, 12, "OnPassHash", "d", playerid);
			}
			else Kick(playerid);
		}
		
		case DIALOG_LOGIN:
		{
			if(response)
			{
				new query[128], pname[MAX_PLAYER_NAME];
				GetPlayerName(playerid, pname, sizeof(pname));
				mysql_format(handle, query, sizeof(query), "SELECT password, Master_ID from `USERS` WHERE Name LIKE '%s'", pname);
				mysql_tquery(handle, query, "OnPlayerLogin", "ds", playerid, inputtext);
			}
			else Kick(playerid);
		}
	}

	return 1;
}

forward OnPlayerJoin(playerid);
public OnPlayerJoin(playerid)
{
	new rows;
	cache_get_row_count(rows);
	
	if(rows) ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "This account is found on your database. Please login", "Login", "Quit");


	else ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD, "Register", "This account not is found on your database. Please register", "Register", "Quit");
	return 1;
}

forward OnPlayerRegister(playerid);
public OnPlayerRegister(playerid)
{
	SendClientMessage(playerid, 0x0033FFFF /*Blue*/, "Thank you for registering! You can now Login");
    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "Thank you for registering! You can now Login with\npassword you just used to register.", "Login", "Quit");
	return 1;
}

forward OnPlayerLogin(playerid,  pass[]);
public OnPlayerLogin(playerid,  pass[])
{
	new pPass[255];
	if(cache_num_rows())
	{
		cache_get_value_index(0, 0, pPass);
		cache_get_value_index_int(0, 1, pInfo[playerid][MasterID]);
		bcrypt_check(pass, pPass, "OnPassCheck", "dd",playerid, pInfo[playerid][MasterID]);
  	}
    else printf("ERROR ");
	return 1;
}

forward OnPassHash(playerid);
public OnPassHash(playerid)
{
	new pass[BCRYPT_HASH_LENGTH], query[128], pname[MAX_PLAYER_NAME];
    GetPlayerName(playerid, pname, sizeof(pname));
    bcrypt_get_hash(pass);
    mysql_format(handle, query, sizeof(query), "INSERT INTO `USERS`(Name, Password) VALUES('%s', '%e')", pname, pass);
	mysql_tquery(handle, query, "OnPlayerRegister", "d", playerid);
	return 1;
}

forward OnPassCheck(playerid, DBID);
public OnPassCheck(playerid, DBID)
{
    if(bcrypt_is_equal())
	{
		SetPlayerInfo(playerid, DBID);
	}
	else ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD, "Login", "The password you just entered is wrong.\nPlease Try again!", "Login", "Quit");
	return 1;
}

SetPlayerInfo(playerid, dbid)
{
	new query[65];
	mysql_format(handle, query, sizeof(query), "SELECT  PosX, PosY, PosZ, Rot, Skin, Level FROM USERS WHERE Master_ID = %d LIMIT 1", dbid);
	new Cache:result = mysql_query(handle, query);
	
	cache_get_value_index_float(0, 1, pInfo[playerid][PX]);
	cache_get_value_index_float(0, 2, pInfo[playerid][PY]);
	cache_get_value_index_float(0, 3, pInfo[playerid][PZ]);
	cache_get_value_index_float(0, 4, pInfo[playerid][Rot]);
	cache_get_value_index_int(0, 5, pInfo[playerid][Skin]);
	cache_get_value_index_int(0, 6, pInfo[playerid][Level]);
	
	cache_delete(result);
	
	SetPlayerScore(playerid, pInfo[playerid][Level]);
	SetSpawnInfo(playerid, 0, pInfo[playerid][Skin], pInfo[playerid][PX], pInfo[playerid][PY], pInfo[playerid][PZ],pInfo[playerid][Rot], 0, 0, 0, 0, 0, 0);
	SpawnPlayer(playerid);
	return 1;
}
