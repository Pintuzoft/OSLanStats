#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char error[255];
Handle mysql = null;

public Plugin myinfo = {
	name = "OSLanStats",
	author = "Pintuz",
	description = "OldSwedes LAN Stats plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSLanStats"
}


public void OnPluginStart() {
    HookEvent ( "player_death", Event_PlayerDeath );
}

public void OnMapStart ( ) {
    checkConnection ( );
}

public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    char weapon[32];
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int assister_id = GetEventInt(event, "assister");
    bool isAssist = ( assister_id != 0 );
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);
    int assister = GetClientOfUserId(assister_id);
    char victim_name[64];
    char attacker_name[64];
    char assister_name[64];
    char victim_steamid[32];
    char attacker_steamid[32];
    char assister_steamid[32];

    Format ( assister_name, sizeof ( assister_name ), "-" );
    Format ( assister_steamid, sizeof ( assister_steamid ), "-" );
    
    GetClientName ( victim, victim_name, sizeof ( victim_name ) );
    GetClientName ( attacker, attacker_name, sizeof ( attacker_name ) );
    
    GetClientAuthId ( victim, AuthId_Steam2, victim_steamid, sizeof ( victim_steamid ) );
    GetClientAuthId ( attacker, AuthId_Steam2, attacker_steamid, sizeof ( attacker_steamid ) );
    int victim_team = GetClientTeam (victim);
    int attacker_team = GetClientTeam (attacker);
    int assister_team = -1;

    if ( isAssist ) {
        GetClientName ( assister, assister_name, sizeof ( assister_name ) );
        GetClientAuthId ( assister, AuthId_Steam2, assister_steamid, sizeof ( assister_steamid ) );
        assister_team = GetClientTeam ( assister );
    }
    GetEventString(event, "weapon", weapon, sizeof(weapon));

    bool isSuicide = ( victim == attacker );
    bool isTeamKill = ( victim_team == attacker_team );
    bool isTeamAssist = ( victim_team == assister_team );
    bool isHeadshot = GetEventBool(event, "headshot");
    int numPenetrated = GetEventInt(event, "penetrated");
    bool isThruSmoke = GetEventBool (event, "thrusmoke");
    bool isBlinded = GetEventBool(event, "attackerblind");

    if ( ! playerIsReal ( victim ) || 
         ! playerIsReal ( attacker ) ) {
        return;
    }
 
    addEvent (  
        attacker_steamid, 
        attacker_name, 
        victim_steamid, 
        victim_name, 
        assister_steamid, 
        assister_name,
        weapon,
        isSuicide,
        isTeamKill,
        isTeamAssist,
        isHeadshot, 
        numPenetrated, 
        isThruSmoke, 
        isBlinded 
    );
}

/* METHODS */


public void addEvent ( char attacker_steamid[32], char attacker_name[64], char victim_steamid[32], char victim_name[64], char assister_steamid[32], char assister_name[64], char weapon[32], bool isSuicide, bool isTeamKill, bool isTeamAssist, bool isHeadshot, int numPenetrated, bool isThruSmoke, bool isBlinded ) {
    char query[255];
    checkConnection ( );
    DBStatement stmt;
    query = "insert into event ( attacker_steamid, attacker_name, victim_steamid, victim_name, assister_steamid, assister_name, weapon, suicide, teamkill, teamassist, headshot, penetrated, thrusmoke, blinded ) values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )";

    if ( ( stmt = SQL_PrepareQuery ( mysql, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSLanStats]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }

    SQL_BindParamString ( stmt, 1, attacker_steamid, false );
    SQL_BindParamString ( stmt, 2, attacker_name, false );
    SQL_BindParamString ( stmt, 3, victim_steamid, false );
    SQL_BindParamString ( stmt, 4, victim_name, false );
    SQL_BindParamString ( stmt, 5, assister_steamid, false );
    SQL_BindParamString ( stmt, 6, assister_name, false );
    SQL_BindParamString ( stmt, 7, weapon, false );

    SQL_BindParamInt ( stmt, 8, isSuicide );
    SQL_BindParamInt ( stmt, 9, isTeamKill );
    SQL_BindParamInt ( stmt, 10, isTeamAssist );
    SQL_BindParamInt ( stmt, 11, isHeadshot );
    SQL_BindParamInt ( stmt, 12, numPenetrated );
    SQL_BindParamInt ( stmt, 13, isThruSmoke );
    SQL_BindParamInt ( stmt, 14, view_as<int>(isBlinded) );


    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSLanStats]: Failed to execute query[0x01] (error: %s)", error);
        return;
    }
    if ( stmt != null ) {
        delete stmt;
    }
}

public bool playerIsReal ( int client ) {
    if ( client < 1 || client > MaxClients ) {
        return false;
    }
    if ( IsClientInGame ( client ) &&
         ! IsClientSourceTV ( client ) ) {
        return true;
    }
    return false;
}

public void databaseConnect ( ) {
    if ( ( mysql = SQL_Connect ( "lanstats", true, error, sizeof(error) ) ) != null ) {
        PrintToServer ( "[OSLanStats]: Connected to knivhelg database!" );
    } else {
        PrintToServer ( "[OSLanStats]: Failed to connect to knivhelg database! (error: %s)", error );
    }
}

public void checkConnection ( ) {
    if ( mysql == null || mysql == INVALID_HANDLE ) {
        databaseConnect ( );
    }
}
