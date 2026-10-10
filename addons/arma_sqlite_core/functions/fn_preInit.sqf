// Arma SQLite addon API. Server execution only.
if (!isServer) exitWith {};

A3SQL_available = false;
A3SQL_ready = false;
A3SQL_databaseReady = false;
A3SQL_starting = false;
A3SQL_error = "";
A3SQL_version = [];

try {
    call compile preprocessFileLineNumbers "\a3sql\core\settings_defaults.sqf";
    private _override = "userconfig\arma_sqlite\settings.sqf";
    if (fileExists _override) then { call compile preprocessFileLineNumbers _override; };
} catch {
    A3SQL_error = format ["Invalid SQLite settings: %1", _exception];
    diag_log format ["[A3SQL] %1", A3SQL_error];
};
