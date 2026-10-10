// Arma SQLite addon API. Server execution only.
params ["_reply"];

[_reply] call A3SQL_fnc_check;
(_reply select 2) params ["_columns", "_rows", "_changes", "_lastRowId"];
_rows apply { _x apply { [_x] call A3SQL_fnc_cell } }
