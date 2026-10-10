// Arma SQLite addon API. Server execution only.
params ["_command", ["_arguments", []]];

private _reply = ["submit", [_command] + _arguments] call A3SQL_fnc_call;
private _id = _reply select 2;
private _owned = uiNamespace getVariable ["A3SQL_ownedJobs", []];

_owned pushBackUnique _id;
uiNamespace setVariable ["A3SQL_ownedJobs", _owned];

_id
