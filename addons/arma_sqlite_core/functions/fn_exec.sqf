// Arma SQLite addon API. Server execution only.
if (!isServer) then { throw "SQLite wrappers must run on the server"; };

params ["_sql", ["_parameters", []], ["_handle", A3SQL_databaseHandle], ["_wait", A3SQL_waitSeconds]];

["exec", [_handle, _sql] + _parameters, _wait] call A3SQL_fnc_async
