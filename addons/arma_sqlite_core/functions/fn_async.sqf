// Arma SQLite addon API. Server execution only.
params ["_command", ["_arguments", []], ["_waitSeconds", 30]];

if (!canSuspend) then { throw "A3SQL_fnc_async requires scheduled SQF"; };

private _id = [_command, _arguments] call A3SQL_fnc_submit;
[_id, _waitSeconds] call A3SQL_fnc_await
