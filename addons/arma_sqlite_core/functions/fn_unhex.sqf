// Arma SQLite addon API. Server execution only.
params ["_hex"];

private _digits = toArray (toLower _hex);

if (count _digits mod 2 != 0) then { throw "Invalid hex length"; };

private _bytes = [];
private _alphabet = toArray "0123456789abcdef";

for "_i" from 0 to ((count _digits) - 1) step 2 do {
    private _hi = _alphabet find (_digits select _i);
    private _lo = _alphabet find (_digits select (_i + 1));
    if (_hi < 0 || {_lo < 0}) then { throw "Invalid hex digit"; };
    _bytes pushBack (16 * _hi + _lo);
};

_bytes
