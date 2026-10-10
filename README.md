# Arma SQLite

SQLite database access for Arma 3 missions. Store player records, balances, inventory, loadouts, and mission state in a local database file.

The addon registers the `A3SQL_fnc_*` functions, loads its settings, and opens a database automatically. No mission-side compilation or external database service is required.

Version: **1.0.1**. Platform: **Windows x64**. SQLite: **3.54.0**.

## Enable the addon

1. Install `@ArmaSQLite` in your Arma installation or mod directory from Steam orGithub.
2. Ensure the installed mod contains these files:

   | Location | Purpose |
   | --- | --- |
   | `@ArmaSQLite/addons/arma_sqlite_core.pbo` | Addon functions and settings |
   | `@ArmaSQLite/arma_sqlite_x64.dll` | Native SQLite extension |
   | `@ArmaSQLite/data/` | Default database storage |

3. Load the mod on your **x64 dedicated server**:

   ```text
   "-serverMod=@ArmaSQLite"
   ```

   Add it to your existing `-serverMod` list if you already use one. For Eden, singleplayer, or a locally hosted mission, load it through the Launcher or use:

   ```text
   "-mod=@ArmaSQLite"
   ```

4. Start a mission and check the RPT for:

   ```text
   [A3SQL] Opening database: ...
   [A3SQL] Ready. Extension 1.0.1, SQLite 3.54.0
   ```
> [!NOTE]
> Database calls run on the server. Clients do not need the addon when only the dedicated server uses it. CBA is not required. Keep the DLL outside the PBO, at the mod root.

> [!CAUTION]
> For local testing, disable BattlEye in the Launcher if the DLL has not received client approval. BattlEye blocks unapproved client extensions with engine error `403`.

## Database configuration

Without an override, the addon opens connection handle `main` and stores the database at:

```text
\data\arma.sqlite
```

> [!NOTE]
> The addon resolves the actual DLL location, so the default works after moving or renaming the mod. It creates the default `data` directory and database if missing. The account running Arma needs permission to create and modify files there.

> [!TIP]
> To change settings, install `userconfig/arma_sqlite/settings.sqf` under the Arma working directory and add this launch parameter:

```text
-filePatching
```

Example settings:

```sqf
A3SQL_autoOpen = true;
A3SQL_databaseHandle = "main";
A3SQL_databasePath = "";
A3SQL_databaseMode = "rwc";
A3SQL_busyMs = 25;
A3SQL_executionMs = 5000;
A3SQL_waitSeconds = 30;
```

| Setting | Meaning |
| --- | --- |
| `A3SQL_autoOpen` | Open the configured database at mission startup. Set `false` to manage connections yourself. |
| `A3SQL_databaseHandle` | Name used to identify the default connection. Defaults to `main`. |
| `A3SQL_databasePath` | Empty string selects automatic storage beside the DLL. Otherwise use a complete filename or SQLite URI. |
| `A3SQL_databaseMode` | `rwc`: open or create. `rw`: open an existing database for writing. `ro`: open an existing database for reading. |
| `A3SQL_busyMs` | Maximum wait for a database lock, in milliseconds. Range: `0` to `30000`. |
| `A3SQL_executionMs` | Execution deadline per database operation, in milliseconds. Range: `1` to `120000`. Queue wait is separate. |
| `A3SQL_waitSeconds` | Startup and query/exec wrapper wait timeout, in seconds. |

For a custom location, include the filename:

```sqf
A3SQL_databasePath = "F:\ArmaDatabase\mission.sqlite";
```

Create `F:\ArmaDatabase` first. Automatic directory creation applies only to the default storage. Other relative paths resolve from the process working directory. The legacy `@ArmaSQLite\data\arma.sqlite` value also selects automatic storage in version 1.0.1.

Settings reload at mission startup. Restart Arma after changing launch parameters. Changing the path opens a different database; the addon does not move existing data.

The RPT reports `[A3SQL] Loaded userconfig settings` when it loads the override. Otherwise it reports that it uses addon defaults.

## Execution rules

- Execute database work on the **server**.
- Run `query`, `exec`, `async`, `await`, `waitReady`, `startup` in **scheduled SQF**, such as a `spawn` block or an `execVM` script.
- Wait for addon readiness before issuing mission database operations.
- Pass values through typed parameters and `?` placeholders.
- Keep Steam UIDs as strings.

The debug console executes code unscheduled. Wrap a query in `spawn` and select **Server Exec** on a dedicated server, or **Local Exec** in singleplayer:

```sqf
[] spawn {
    try {
        [30] call A3SQL_fnc_waitReady;
        private _rows = ["SELECT sqlite_version()"] call A3SQL_fnc_query;
        diag_log format ["[A3SQL] SQLite version: %1", _rows];
    } catch {
        diag_log format ["[A3SQL] Query failed: %1", _exception];
    };
};
```

Use returned rows inside the scheduled block. `spawn` returns a script handle, not the query result.

`waitReady` confirms addon startup. It does not create your mission's tables. Create your schema before running examples that use those tables.

## First mission example

Put this in your mission's `initServer.sqf`. It creates a player table, registers a sample player without overwriting an existing record, and reads the record back.

```sqf
[] spawn {
    try {
        [30] call A3SQL_fnc_waitReady;

        ["
            CREATE TABLE IF NOT EXISTS players (
                uid TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                money INTEGER NOT NULL DEFAULT 0 CHECK (money >= 0),
                loadout TEXT,
                updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
        "] call A3SQL_fnc_exec;

        [
            "INSERT INTO players(uid,name,money) VALUES(?,?,?) ON CONFLICT(uid) DO NOTHING",
            ["t:76561198000000001", "t:Wolf", "i:1500"]
        ] call A3SQL_fnc_exec;

        private _rows = [
            "SELECT uid,name,money FROM players WHERE uid=?",
            ["t:76561198000000001"]
        ] call A3SQL_fnc_query;

        diag_log format ["[A3SQL] Player rows: %1", _rows];
    } catch {
        diag_log format ["[A3SQL] Mission DB error: %1", _exception];
    };
};
```

## Main functions

### Query rows

```sqf
[_sql, _typedParameters, _handle, _waitSeconds] call A3SQL_fnc_query;
```

Only `_sql` is required. Parameters default to `[]`; the handle and timeout use `A3SQL_databaseHandle` and `A3SQL_waitSeconds`.

The result is an array of rows. Each row follows the order of columns in your `SELECT`. No matches returns `[]`.

```sqf
private _rows = [
    "SELECT name,money FROM players WHERE uid=?",
    ["t:76561198000000001"]
] call A3SQL_fnc_query;

if (_rows isNotEqualTo []) then {
    (_rows select 0) params ["_name", "_moneyText"];
    diag_log format ["Player %1 has %2", _name, _moneyText];
};
```

### Execute SQL

```sqf
[_sql, _typedParameters, _handle, _waitSeconds] call A3SQL_fnc_exec;
```

Arguments use the same defaults as `query`. `exec` returns the full typed reply. Use it for table creation, inserts, updates, and deletes.

Both wrappers support one SQL statement per call. Use the native `script` command for multiple statements. Both support SQL `RETURNING`; `query` decodes its returned rows directly.

### Returned value types

| SQLite value | Decoded SQF value |
| --- | --- |
| TEXT | String |
| INTEGER | Decimal string, preserving exact 64-bit values |
| REAL | Number, using SQF numeric precision |
| BLOB | Array of byte values |
| NULL | `objNull` |

`money` therefore returns as `"1500"`, not `1500`. Use `parseNumber` only when the value fits the precision your gameplay code needs. Perform large integer arithmetic in SQL and keep UIDs as text.

## Typed parameters

Bind one parameter for each positional `?` placeholder. Do not place quotes around the placeholder.

| Prefix | Example | SQL value |
| --- | --- | --- |
| `t:` | `"t:Wolf O'Brien"` | Text |
| `i:` | `"i:1500"` | Signed 64-bit integer |
| `r:` | `"r:12.5"` | Real number |
| `n:` | `"n:"` | NULL |
| `b:` | `"b:00ff10"` | Binary bytes |
| `x:` | `"x:610062"` | Text bytes, useful for embedded NUL characters |

Dynamic parameters:

```sqf
private _uid = "76561198000000001";
private _name = "Wolf O'Brien";
private _initialMoney = 1500;

[
    "INSERT INTO players(uid,name,money) VALUES(?,?,?) ON CONFLICT(uid) DO NOTHING",
    ["t:" + _uid, "t:" + _name, "i:" + (_initialMoney toFixed 0)]
] call A3SQL_fnc_exec;
```

Validate and round numeric input before using `toFixed 0`. Avoid `str` for integer parameters because it can produce scientific notation. Represent booleans as `i:0` or `i:1`.

Values can be bound; table and column names cannot. Use fixed SQL identifiers. Empty text is `t:`, empty binary data is `b:`, and the literal text `NULL` is `t:NULL`.

## Database operation examples

The following snippets belong inside scheduled server code, after the `players` table exists.

### Insert a record

```sqf
[
    "INSERT INTO players(uid,name,money) VALUES(?,?,?)",
    ["t:76561198000000002", "t:Raven", "i:2500"]
] call A3SQL_fnc_exec;
```

A duplicate primary key throws a database error. Use `ON CONFLICT` when you want an idempotent registration or an update.

### Register or refresh a player with UPSERT

```sqf
[
    "INSERT INTO players(uid,name,money) VALUES(?,?,?) ON CONFLICT(uid) DO UPDATE SET name=excluded.name,updated_at=CURRENT_TIMESTAMP",
    ["t:76561198000000001", "t:Wolf", "i:1500"]
] call A3SQL_fnc_exec;
```

New players receive `1500`. Existing players keep their balance; only their name and timestamp change.

### Read several records

```sqf
private _rows = [
    "SELECT uid,name,money FROM players WHERE money>=? ORDER BY money DESC,uid LIMIT ?",
    ["i:1000", "i:50"]
] call A3SQL_fnc_query;

{
    _x params ["_uid", "_name", "_moneyText"];
    diag_log format ["%1: %2, balance %3", _uid, _name, _moneyText];
} forEach _rows;
```

### Update a name

```sqf
[
    "UPDATE players SET name=?,updated_at=CURRENT_TIMESTAMP WHERE uid=?",
    ["t:Wolf Two", "t:76561198000000001"]
] call A3SQL_fnc_exec;
```

### Add money and return the new balance

```sqf
private _rows = [
    "UPDATE players SET money=money+?,updated_at=CURRENT_TIMESTAMP WHERE uid=? RETURNING money",
    ["i:250", "t:76561198000000001"]
] call A3SQL_fnc_query;

if (_rows isNotEqualTo []) then {
    private _newBalance = (_rows select 0) select 0;
    diag_log format ["[A3SQL] New balance: %1", _newBalance];
};
```

SQL performs the addition atomically. A missing player returns `[]`.

### Spend money only when the balance is sufficient

```sqf
private _rows = [
    "UPDATE players SET money=money-?,updated_at=CURRENT_TIMESTAMP WHERE uid=? AND money>=? RETURNING money",
    ["i:500", "t:76561198000000001", "i:500"]
] call A3SQL_fnc_query;

if (_rows isEqualTo []) then {
    diag_log "[A3SQL] Purchase rejected: missing player or insufficient balance";
} else {
    diag_log format ["[A3SQL] Purchase accepted. Balance: %1", (_rows select 0) select 0];
};
```

Validate the price on the server and require a positive amount. Keep the balance check and debit in one statement. Separate SELECT and UPDATE calls allow concurrent requests to spend the same balance.

### Store serialized SQF data

```sqf
private _savedState = [["FirstAidKit", 3], ["SmokeShell", 2]];

[
    "UPDATE players SET loadout=?,updated_at=CURRENT_TIMESTAMP WHERE uid=?",
    ["t:" + str _savedState, "t:76561198000000001"]
] call A3SQL_fnc_exec;

private _rows = [
    "SELECT loadout FROM players WHERE uid=?",
    ["t:76561198000000001"]
] call A3SQL_fnc_query;

if (_rows isNotEqualTo []) then {
    private _stored = (_rows select 0) select 0;
    if (_stored isEqualType "") then {
        private _restoredState = parseSimpleArray _stored;
        diag_log _restoredState;
    };
};
```

Use the same approach to store `str (getUnitLoadout _unit)`. Decode with `parseSimpleArray`, validate the structure, and apply a restored loadout where the unit is local.

### Store NULL

```sqf
[
    "UPDATE players SET loadout=? WHERE uid=?",
    ["n:", "t:76561198000000001"]
] call A3SQL_fnc_exec;
```

### Create a related table and index

```sqf
[
    "CREATE TABLE IF NOT EXISTS player_items (uid TEXT NOT NULL REFERENCES players(uid) ON DELETE CASCADE,item TEXT NOT NULL,quantity INTEGER NOT NULL CHECK(quantity>=0),PRIMARY KEY(uid,item))"
] call A3SQL_fnc_exec;

[
    "CREATE INDEX IF NOT EXISTS players_money_idx ON players(money)"
] call A3SQL_fnc_exec;

[
    "INSERT INTO player_items(uid,item,quantity) VALUES(?,?,?) ON CONFLICT(uid,item) DO UPDATE SET quantity=player_items.quantity+excluded.quantity",
    ["t:76561198000000001", "t:FirstAidKit", "i:3"]
] call A3SQL_fnc_exec;
```

Foreign keys are enabled. The player must exist before you insert their items. With this schema, deleting a player also deletes their related items.

`CREATE TABLE IF NOT EXISTS` does not alter an existing table. Plan explicit migrations when your schema changes.

### Delete a record

```sqf
private _deleted = [
    "DELETE FROM players WHERE uid=? RETURNING uid",
    ["t:76561198000000002"]
] call A3SQL_fnc_query;

diag_log format ["[A3SQL] Deleted records: %1", _deleted];
```

### Drop a disposable table

```sqf
["CREATE TABLE IF NOT EXISTS scratch_demo(value TEXT)"] call A3SQL_fnc_exec;
["DROP TABLE IF EXISTS scratch_demo"] call A3SQL_fnc_exec;
```

## Native command access

Use `A3SQL_fnc_async` for commands outside the two convenience wrappers:

```sqf
[_command, _arguments, _waitSeconds] call A3SQL_fnc_async;
```

All `_arguments` must be strings. Direct `async` calls default to a **30-second** wait when you omit the third argument. SQL parameters are flattened into the native argument array:

```sqf
private _reply = [
    "query",
    [A3SQL_databaseHandle, "SELECT name FROM players WHERE uid=?", "t:76561198000000001"]
] call A3SQL_fnc_async;

private _rows = [_reply] call A3SQL_fnc_rows;
```

### Run multiple SQL statements atomically

`script` executes trusted SQL statements in one savepoint. It rolls back the script if a statement fails. It does not accept bound parameters or return result rows.

```sqf
[
    "script",
    [A3SQL_databaseHandle, "
        CREATE TABLE IF NOT EXISTS mission_state (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS mission_events (
            id INTEGER PRIMARY KEY,
            kind TEXT NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    "]
] call A3SQL_fnc_async;
```

### Insert multiple rows atomically

`batch` binds and executes the same statement for each row. The width is the number of parameters per row. A failure rolls back the whole batch.

```sqf
[
    "batch",
    [
        A3SQL_databaseHandle,
        "INSERT INTO players(uid,name,money) VALUES(?,?,?) ON CONFLICT(uid) DO NOTHING",
        "3",
        "t:76561198000000003", "t:Hawk", "i:1000",
        "t:76561198000000004", "t:Viper", "i:2000"
    ]
] call A3SQL_fnc_async;
```

Do not use `RETURNING` or other row-producing SQL with `batch`.

### Reuse a prepared statement

```sqf
private _db = A3SQL_databaseHandle;

[
    "prepare",
    [_db, "add_money", "UPDATE players SET money=money+? WHERE uid=? RETURNING money"]
] call A3SQL_fnc_async;

try {
    private _reply = [
        "run",
        [_db, "add_money", "i:100", "t:76561198000000001"]
    ] call A3SQL_fnc_async;

    diag_log ([_reply] call A3SQL_fnc_rows);
} catch {
    ["finalize", [_db, "add_money"]] call A3SQL_fnc_async;
    throw _exception;
};

["finalize", [_db, "add_money"]] call A3SQL_fnc_async;
```

Statement names must be unique within a connection. Prepared statements reset after each run; supply every parameter each time. Keep frequently used statements open for reuse and finalize them when no longer needed.

### Submit now and collect later

```sqf
private _jobId = [
    "query",
    [A3SQL_databaseHandle, "SELECT uid,name FROM players ORDER BY uid LIMIT 100"]
] call A3SQL_fnc_submit;

// Other scheduled mission work can run here.
private _reply = [_jobId, 30] call A3SQL_fnc_await;
private _rows = [_reply] call A3SQL_fnc_rows;
diag_log _rows;
```

`await` collects the reply and releases its job storage. If you manage jobs manually, release completed results yourself. A timed-out job that remains pending after cancellation needs later polling and release; its ID is included in the exception.

### Open an additional database

```sqf
["open", ["events", "C:\ArmaDB\events.sqlite", "rwc", "25", "5000"]] call A3SQL_fnc_async;

["CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY,message TEXT NOT NULL)", [], "events"] call A3SQL_fnc_exec;
["INSERT INTO events(message) VALUES(?)", ["t:Mission started"], "events"] call A3SQL_fnc_exec;

private _rows = ["SELECT id,message FROM events ORDER BY id", [], "events"] call A3SQL_fnc_query;
diag_log _rows;

["close", ["events"]] call A3SQL_fnc_async;
```

Create `C:\ArmaDB` first. SQLite uses files, not database usernames or passwords. You can also open `:memory:` or a URI such as `file:C:/ArmaDB/reference.sqlite?mode=ro` with mode `ro`.

When `A3SQL_autoOpen` is `false`, `waitReady` confirms the extension is available, but no default connection exists. Open your connection before querying it.

### Backup and maintenance

```sqf
// C:\ArmaDB\backups must already exist.
["backup", [A3SQL_databaseHandle, "C:\ArmaDB\backups\mission.sqlite"]] call A3SQL_fnc_async;

private _reply = ["integrity", [A3SQL_databaseHandle, "quick"]] call A3SQL_fnc_async;
diag_log ([_reply] call A3SQL_fnc_rows);
// [["ok"]] when the database passes the check.

["checkpoint", [A3SQL_databaseHandle, "passive"]] call A3SQL_fnc_async;
["optimize", [A3SQL_databaseHandle]] call A3SQL_fnc_async;
```

Use the backup command for a running database instead of copying only its `.sqlite` file while WAL writes are active. `restore` copies a backup into an open database and invalidates its prepared statements. Stop gameplay database users before restoring.

## Full function list

Square brackets around an argument below mean it is optional. Functions exist automatically once the addon loads.

| Function | Arguments | Result and purpose |
| --- | --- | --- |
| `A3SQL_fnc_waitReady` | `[seconds=30]` | Scheduled. Returns `true` when startup completes; throws on failure or timeout. |
| `A3SQL_fnc_query` | `sql, [params=[]], [handle=default], [seconds=configured]` | Scheduled. Returns decoded rows. |
| `A3SQL_fnc_exec` | `sql, [params=[]], [handle=default], [seconds=configured]` | Scheduled. Returns the full typed reply. |
| `A3SQL_fnc_async` | `command, [arguments=[]], [seconds=30]` | Scheduled. Submits, waits, collects, and releases; returns a checked reply. |
| `A3SQL_fnc_submit` | `command, [arguments=[]]` | Returns a job ID string without waiting for database execution. |
| `A3SQL_fnc_await` | `jobId, [seconds=30]` | Scheduled. Waits for a submitted job, collects and releases it, and returns a checked reply. |
| `A3SQL_fnc_call` | `command, [arguments=[]]` | Synchronous call with chunk collection and database error checking. |
| `A3SQL_fnc_raw` | `command, [arguments=[]]` | Parses the native reply. Throws for engine/transport errors, but returns database error replies for manual handling. |
| `A3SQL_fnc_collect` | `reply, [releaseChunk=true]` | Reassembles a multipart reply. Normal callers use `call` or `await` instead. |
| `A3SQL_fnc_check` | `reply` | Returns the reply on success; throws for a nonzero database/extension status. |
| `A3SQL_fnc_rows` | `reply` | Checks a row-producing reply and returns decoded rows. |
| `A3SQL_fnc_cell` | `typedCell, [nullValue=objNull]` | Decodes one cell. |
| `A3SQL_fnc_unhex` | `hexString` | Returns a byte array. |
| `A3SQL_fnc_startup` | none | Scheduled. Runs startup or retries it after a failure. Returns success state. |
| `A3SQL_fnc_preInit` | none | Internal. Loads defaults and optional userconfig automatically. |
| `A3SQL_fnc_postInit` | none | Internal. Starts scheduled setup automatically. |

`default` means `A3SQL_databaseHandle`; `configured` means `A3SQL_waitSeconds`. Database-calling helpers enforce server execution. Pure decoding/check helpers do not access the database.

## Native command reference

Use `A3SQL_fnc_async` for database commands. Use `A3SQL_fnc_raw` or `A3SQL_fnc_call` for immediate job-control commands.

| Command | Arguments | Operation |
| --- | --- | --- |
| `version` | none | Extension and SQLite versions. |
| `default_path` | none | Create/use the default data directory and return its absolute database filename. |
| `open` | handle, path, `[mode]`, `[busyMs]`, `[executionMs]` | Open a connection. |
| `close` | handle | Close a connection and finalize its statements. |
| `close_all` | none | Close all connections. |
| `info` | handle | Path, transaction state, counters, and timeouts. |
| `timeout` | handle, busyMs, executionMs | Change connection timeouts. |
| `query`, `exec` | handle, SQL, typed parameters... | Execute one bound statement. |
| `prepare` | handle, statementName, SQL | Compile a reusable statement. |
| `run` | handle, statementName, typed parameters... | Execute a prepared statement. |
| `finalize` | handle, statementName | Free a prepared statement. |
| `script` | handle, SQL | Execute multiple trusted statements atomically. |
| `batch` | handle, SQL, width, flattened typed parameters... | Execute several parameter sets atomically. |
| `begin` | handle, `[deferred/immediate/exclusive]` | Begin a connection-wide transaction; default `immediate`. |
| `commit`, `rollback` | handle | Finish a transaction. |
| `savepoint`, `release_savepoint`, `rollback_to` | handle, savepointName | Manage a savepoint. |
| `checkpoint` | handle, `[passive/full/restart/truncate]` | Checkpoint WAL; default `passive`. |
| `backup` | handle, destination filename/URI | Copy the open database using SQLite's backup API. |
| `restore` | handle, source filename/URI | Restore into the open database. |
| `integrity` | handle, `[quick/full]` | Return integrity-check rows; default `quick`. |
| `vacuum` | handle | Rebuild the database to reclaim space. |
| `optimize` | handle | Run SQLite optimization maintenance. |
| `submit` | command, command arguments... | Queue database work and return a job ID. |
| `poll` | jobId | Return pending status or the completed reply. |
| `read` | resultId, byteOffset, `[maxBytes]` | Read multipart response data. |
| `release` | resultId | Free a completed result. |
| `cancel` | jobId | Request cancellation. |
| `stats` | none | Queue depth, retained results, and retained bytes. |
| `shutdown` | none | Stop the native worker permanently for this process. |

Do not pass `BEGIN`, `COMMIT`, or savepoint SQL through the query wrappers. Use the dedicated commands. Multiple SQF scripts sharing a handle can interleave operations inside a transaction, even though the native worker executes jobs in order. Use `script`, `batch`, or a single conditional statement for atomic work, or serialize all access to a transaction-owned handle yourself.

Do not call `shutdown` at mission end. The DLL persists across missions and cannot restart its worker after shutdown. The addon handles its managed connection and tracked jobs at the next mission startup. It does not automatically close extra connections you opened manually.

## Inspect a full reply

A successful row-producing command returns:

```sqf
[0, "ok", [columnNames, typedRows, changes, lastInsertRowId]]
```

```sqf
private _reply = [
    "INSERT INTO mission_events(kind) VALUES(?) RETURNING id",
    ["t:mission_started"]
] call A3SQL_fnc_exec;

(_reply select 2) params ["_columns", "_typedRows", "_changes", "_lastInsertRowId"];
private _rows = [_reply] call A3SQL_fnc_rows;
diag_log format ["Columns: %1, rows: %2, changes: %3", _columns, _rows, _changes];
```

This example requires the `mission_events` table from the script example. `changes` and `lastInsertRowId` are decimal strings. The insert-row ID is connection-scoped and can retain an earlier value after SELECT or UPDATE. Prefer `RETURNING` to identify the records affected by the current statement.

## Startup state and troubleshooting

| Variable | Meaning |
| --- | --- |
| `A3SQL_available` | The extension version probe succeeded. |
| `A3SQL_ready` | Addon startup completed. |
| `A3SQL_databaseReady` | The managed default database opened. |
| `A3SQL_databasePath` | Configured or resolved default filename. |
| `A3SQL_error` | Startup error text, or an empty string. |
| `A3SQL_version` | `[extensionVersion, sqliteVersion, sqliteSourceId]`. |

| Error | Action |
| --- | --- |
| Engine `403` | BattlEye blocked the DLL. Use an approved DLL, or disable BattlEye for local testing. |
| SQLite `14`, unable to open database file | Check the logged absolute filename, parent directory, and runtime account permissions. Include a filename, not just a directory. |
| Requires scheduled SQF | Put the database call inside `spawn` or `execVM`. |
| Unknown database handle | Wait for startup or open the named connection. |
| No such table | Initialize your mission schema before querying it. |
| Invalid typed parameter | Check the prefix, decimal/hex format, and placeholder count. |
| Userconfig changes have no effect | Check its location, enable `-filePatching`, restart Arma, and check the settings-source RPT line. |

## Efficient mission usage

- Select the columns and rows you need. Use `WHERE`, `LIMIT`, and indexes for frequent lookups.
- Reuse prepared statements for repeated saves.
- Use batches for groups of writes and save on meaningful events or a reasonable interval.
- Keep values bound to placeholders. Validate gameplay requests on the server.
- Keep the default database on local writable storage. It uses WAL and `synchronous=FULL`.
- Do not expose raw database helpers through client `remoteExec` access. Clients should call validated server gameplay functions.
- Let the addon manage its default connection. Close additional connections when their users finish.

> [!CAUTION]
> No player-saving loop, money system, or mission schema runs automatically. The addon provides database access; your mission decides what to save and when.
