#include <sourcemod>
#include <sdktools>
#include <sdktools_gamerules>
#include <cstrike>

char error[255];
Database db = Database("oslanstats", error, sizeof(error));

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


public void Event_PlayerDeath ( Event event, const char[] name, bool dontBroadcast ) {
    int victim_id = GetEventInt(event, "userid");
    int attacker_id = GetEventInt(event, "attacker");
    int assister_id = GetEventInt(event, "assister");
    int victim = GetClientOfUserId(victim_id);
    int attacker = GetClientOfUserId(attacker_id);
    int assister = GetClientOfUserId(assister_id);
    int victim_team = GetClientTeam (victim);
    int attacker_team = GetClientTeam ( attacker );
    int assister_team = GetClientTeam ( assister );
    char weapon[32];
    GetEventString(event, "weapon", weapon, sizeof(weapon));







    if ( ! playerIsReal ( victim ) || 
         ! playerIsReal ( attacker ) ) {
        return;
    }


    if ( victim_team == attacker_team ) {
        // TeamKill
        addTeamKill ( attacker, victim );
    } else {
        // Kill
        addKill ( attacker, victim );
    }

    if ( victim_team == assister_team ) {
        // TeamAssist
        addTeamAssist ( assister, victim );
    } else {
        // Assist
        addAssist ( assister, victim );
    }




}

/* METHODS */

public void addTeamKill ( int attacker, int victim ) {
    char query[255];
    DBStatement stmt;
    char steamid[32];
    char attacker_name[64];
    GetClientAuthId ( attacker, AuthId_Steam2, steamid, sizeof ( steamid ) );
    GetClientName ( attacker, attacker_name, sizeof ( attacker_name ) );
    query = "insert into player  ( steamid, name, kills, deaths, assists, teamkills, teamdeaths, teamassists ) values ( ?, ?, 1, 0, 0, 1, 0, 0 ) on duplicate key update teamkills = teamkills + 1, kills = kills + 1";
    if ( ( stmt = SQL_PrepareQuery ( db, query, error, sizeof(error) ) ) == null ) {
        SQL_GetError ( db, error, sizeof(error));
        PrintToServer("[OSLanStats]: Failed to prepare query[0x01] (error: %s)", error);
        return;
    }
    SQL_BindParamString ( stmt, 1, steamid, false );
    SQL_BindParamString ( stmt, 2, attacker_name, false );
    if ( ! SQL_Execute ( stmt ) ) {
        SQL_GetError ( db, error, sizeof(error));
        PrintToServer("[OSLanStats]: Failed to query[0x02] (error: %s)", error);
        return;
    }
    stmt.Close();
}

public void addKill ( int attacker, int victim ) {
    char query[255];
    DBStatement stmt;
    query = "insert into player  ( steamid, name, kills, deaths, assists, teamkills, teamdeaths, teamassists ) values ( ?, ?, 1, 0, 0, 0, 0, 0 ) on duplicate key update kills = kills + 1";
    stmt = db.Prepare(query, error, sizeof(error));
    stmt.BindString(1, GetClientAuthId(attacker));
    stmt.BindString(2, GetClientName(attacker));
    stmt.Execute();
    stmt.Close();
}

public void addTeamAssist ( int assister, int victim ) {
    char query[255];
    DBStatement stmt;
    query = "insert into player  ( steamid, name, kills, deaths, assists, teamkills, teamdeaths, teamassists ) values ( ?, ?, 0, 0, 1, 0, 0, 1 ) on duplicate key update teamassists = teamassists + 1, assists = assists + 1";
    stmt = db.Prepare(query, error, sizeof(error));
    stmt.BindString(1, GetClientAuthId(assister));
    stmt.BindString(2, GetClientName(assister));
    stmt.Execute();
    stmt.Close();
}

public void addAssist ( int assister, int victim ) {
    char query[255];
    DBStatement stmt;
    query = "insert into player  ( steamid, name, kills, deaths, assists, teamkills, teamdeaths, teamassists ) values ( ?, ?, 0, 0, 1, 0, 0, 0 ) on duplicate key update assists = assists + 1";
    stmt = db.Prepare(query, error, sizeof(error));
    stmt.BindString(1, GetClientAuthId(assister));
    stmt.BindString(2, GetClientName(assister));
    stmt.Execute();
    stmt.Close();
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


