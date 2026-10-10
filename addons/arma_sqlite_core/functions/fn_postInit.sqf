// Arma SQLite addon API. Server execution only.
if (!isServer) exitWith {};
if (A3SQL_error != "") exitWith {};

[] spawn A3SQL_fnc_startup;
