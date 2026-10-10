// Arma SQLite addon API. Server execution only.
if (!isServer) exitWith { false };
if (!canSuspend) then { throw "A3SQL startup requires scheduled SQF"; };
if (A3SQL_starting || {A3SQL_ready}) exitWith { A3SQL_ready };

A3SQL_starting = true;
A3SQL_error = "";
A3SQL_databaseReady = false;

try {
    private _version = ["version", []] call A3SQL_fnc_call;
    A3SQL_version = _version select 2;
    A3SQL_available = true;

    // The DLL persists across mission changes. Resolve only jobs submitted by
    // this addon, then close only its previous managed default connection.
    private _stale = +(uiNamespace getVariable ["A3SQL_ownedJobs", []]);
    {
        ["cancel", [_x]] call A3SQL_fnc_raw;
    } forEach _stale;
    {
        private _id = _x;
        private _state = ["poll", [_id]] call A3SQL_fnc_raw;
        if ((_state select 0) == -1 && {(_state select 2) isEqualTo "Unknown result/job ID"}) then {
            uiNamespace setVariable ["A3SQL_ownedJobs", (uiNamespace getVariable ["A3SQL_ownedJobs", []]) - [_id]];
        } else {
            try { [_id, 10] call A3SQL_fnc_await; } catch {
                // Cancelled results are released by await before it throws.
                diag_log format ["[A3SQL] Previous mission job %1: %2", _id, _exception];
            };
        };
    } forEach _stale;
    if (count (uiNamespace getVariable ["A3SQL_ownedJobs", []]) > 0) then {
        throw "Previous mission jobs are still pending. Retry startup when they finish.";
    };
    private _oldHandle = uiNamespace getVariable ["A3SQL_managedHandle", ""];
    if (_oldHandle != "") then {
        private _id = ["close", [_oldHandle]] call A3SQL_fnc_submit;
        try { [_id, A3SQL_waitSeconds] call A3SQL_fnc_await; } catch {
            diag_log format ["[A3SQL] Previous managed connection cleanup: %1", _exception];
        };
        uiNamespace setVariable ["A3SQL_managedHandle", ""];
    };

    if (A3SQL_autoOpen) then {
        private _r = ["open", [A3SQL_databaseHandle, A3SQL_databasePath, A3SQL_databaseMode,
            A3SQL_busyMs toFixed 0, A3SQL_executionMs toFixed 0], A3SQL_waitSeconds] call A3SQL_fnc_async;
        uiNamespace setVariable ["A3SQL_managedHandle", A3SQL_databaseHandle];
        A3SQL_databaseReady = true;
        diag_log format ["[A3SQL] Database %1 open: %2", A3SQL_databaseHandle, (_r select 2) select 1];
    };
    A3SQL_ready = true;
    A3SQL_starting = false;
    diag_log format ["[A3SQL] Ready. Extension %1, SQLite %2", A3SQL_version select 0, A3SQL_version select 1];
    true
} catch {
    A3SQL_ready = false;
    A3SQL_starting = false;
    A3SQL_error = str _exception;
    diag_log format ["[A3SQL] Startup failed: %1", A3SQL_error];
    false
};
