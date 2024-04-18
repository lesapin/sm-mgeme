/**
 * =============================================================================
 * MGEME
 * A rewrite of MGEMOD for MGE.ME server. Database functions.
 *
 * (C) 2024 MGE.ME.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#if defined _mgeme_database_included
        #endinput
#endif
#define _mgeme_database_included

#include <dbi>

#define MGEME_DB "mgeme"

Database gDB;

stock bool DBConnect()
{
        char error[255];

        if (SQL_CheckConfig(MGEME_DB))
        {
                gDB = SQL_Connect(MGEME_DB, true, error, sizeof(error));
        }
        else
        {
                LogMessage("DB config <%s> doesn't exist, using default config", MGEME_DB);
                gDB = SQL_DefConnect(error, sizeof(error));
        }

        if (gDB == null)
        {
                LogError("Connecting to database failed <%s>", error);
                return false;
        }

        char identifier[64];
        gDB.Driver.GetIdentifier(identifier, sizeof(identifier));

        if (strcmp(identifier, "sqlite") != 0)
        {
                LogError("Database type %s is not supported, use sqlite", identifier);
                delete gDB;
                return false;
        }

        gDB.Query(SQLQueryErrorCheck, "CREATE TABLE IF NOT EXISTS mgeme_stats (steamid TEXT, \
        first_seen INTEGER, elo INTEGER, wins INTEGER, losses INTEGER)");

        return true;
}

stock void DBInitServerStats()
{
        gDB.Query(SQLQueryErrorCheck, "CREATE TABLE IF NOT EXISTS mgeme_server (steamid TEXT, \
        date TEXT, playtime INTEGER, playtime_total INTEGER, connections INTEGER)");
}

stock void SQLQueryErrorCheck(Database db, DBResultSet result, const char[] error, any data)
{
        if (db == null || strlen(error) > 0)
        {
                LogError("SQLQueryCreateTable error: %s", error);
        }
}
