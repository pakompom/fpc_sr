unit upc24inline;
{$ifdef PC24_TEST_DELPHI}
{$mode delphi}{$EXCESSPRECISION ON}
{$else}
{$mode objfpc}
{$endif}
{$inline on}
interface
function PCAdd(a,b: Double): Double; inline;
function PCSingleAdd(a,b: Single): Single; inline;
function PCIntAdd(a: Single; b: LongInt): Double; inline;
function NativeAdd(a,b: Double): Double; inline;
implementation
{$LEGACYPC24 ON}
function PCAdd(a,b: Double): Double; inline;
begin Result:=a+b; end;
function PCSingleAdd(a,b: Single): Single; inline;
begin Result:=a+b; end;
function PCIntAdd(a: Single; b: LongInt): Double; inline;
begin Result:=a+b; end;
{$LEGACYPC24 OFF}
function NativeAdd(a,b: Double): Double; inline;
begin Result:=a+b; end;
end.
