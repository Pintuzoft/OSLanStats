#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char error[255];
Handle mysql = null;
int numRealPlayers = 0;
int round = 0;
char map[32];
ConVar osls_enabled;
ConVar osls_minplayers;

public Plugin myinfo = {
	name = "OSLanStats",
	author = "Pintuz",
	description = "OldSwedes LAN Stats plugin",
	version = "0.01",
	url = "https://github.com/Pintuzoft/OSLanStats"
}


public void OnPluginStart() {
    HookEvent ( "player_death", Event_PlayerDeath );
    HookEvent ( "round_start", Event_RoundStart );
    osls_enabled = CreateConVar ( "osls_enabled", "1", "Enable logging" );
    osls_minplayers = CreateConVar ( "osls_minplayers", "4", "Minimum number of real players to start logging" );
    AutoExecConfig ( true, "oslanstats" );

}

public void OnMapStart() {
    checkConnection ( );
}

public void Event_RoundStart ( Event event, const char[] name, bool dontBroadcast ) {
    ServerCommand("exec sourcemod/oslanstats.cfg");
    checkConnection ( );
    checkRealPlayers ( );
    round = ( GetTeamScore ( CS_TEAM_CT ) + GetTeamScore ( CS_TEAM_T ) + 1 );
    GetCurrentMap ( map, sizeof ( map ) );
}



public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    if ( ! osls_enabled.BoolValue ) {
        return;
    }
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
    bool isHeadshot = ( GetEventInt(event, "headshot") == 1 );
    int numPenetrated = GetEventInt(event, "penetrated");
    bool isThruSmoke = ( GetEventInt (event, "thrusmoke") == 1 );
    bool isBlinded = ( GetEventInt (event, "attackerblind") == 1 );

//    if ( ! playerIsReal ( victim ) || 
//         ! playerIsReal ( attacker ) ) {
//        return;
//    }

    if ( enoughRealPlayers ( ) ) {
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
}

/* METHODS */


public void addEvent ( char attacker_steamid[32], char attacker_name[64], char victim_steamid[32], char victim_name[64], char assister_steamid[32], char assister_name[64], char weapon[32], bool isSuicide, bool isTeamKill, bool isTeamAssist, bool isHeadshot, int numPenetrated, bool isThruSmoke, bool isBlinded ) {
    checkConnection ( );
    DBStatement stmt;

    if ( ( stmt = SQL_PrepareQuery ( mysql, "insert into event ( stamp, map, round, attacker_steamid, attacker_name, victim_steamid, victim_name, assister_steamid, assister_name, weapon, suicide, teamkill, teamassist, headshot, penetrated, thrusmoke, blinded ) values ( now(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )", error, sizeof(error) ) ) == null ) {
        SQL_GetError ( mysql, error, sizeof(error));
        PrintToServer("[OSLanStats]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }

    SQL_BindParamString ( stmt, 0, map, false );
    SQL_BindParamInt    ( stmt, 1, round, false );
    SQL_BindParamString ( stmt, 2, attacker_steamid, false );
    SQL_BindParamString ( stmt, 3, attacker_name, false );
    SQL_BindParamString ( stmt, 4, victim_steamid, false );
    SQL_BindParamString ( stmt, 5, victim_name, false );
    SQL_BindParamString ( stmt, 6, assister_steamid, false );
    SQL_BindParamString ( stmt, 7, assister_name, false );
    SQL_BindParamString ( stmt, 8, weapon, false );

    SQL_BindParamInt ( stmt, 9, isSuicide );
    SQL_BindParamInt ( stmt, 10, isTeamKill );
    SQL_BindParamInt ( stmt, 11, isTeamAssist );
    SQL_BindParamInt ( stmt, 12, isHeadshot );
    SQL_BindParamInt ( stmt, 13, numPenetrated );
    SQL_BindParamInt ( stmt, 14, isThruSmoke );
    SQL_BindParamInt ( stmt, 15, isBlinded );

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
         ! IsFakeClient ( client ) &&
         ! IsClientSourceTV ( client ) ) {
        return true;
    }
    return false;
}

public void checkRealPlayers ( ) {
    numRealPlayers = 0;
    for ( int i = 1; i <= MaxClients; i++ ) {
        if ( playerIsReal ( i ) ) {
            numRealPlayers++;
        }
    }
    PrintToChatAll ( "[OSLanStats]: %d real players is connected", numRealPlayers );
}

public bool enoughRealPlayers ( ) {
    if ( numRealPlayers >= osls_minplayers.IntValue ) {
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
 