// Arma SQLite addon API. Server execution only.
params ["_command", ["_arguments", []]];

private _reply = [_command, _arguments] call A3SQL_fnc_raw;
_reply = [_reply] call A3SQL_fnc_collect;
[_reply] call A3SQL_fnc_check
