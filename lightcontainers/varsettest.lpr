program varsettest;
{$ifdef fpc}
{$mode delphi}
{$endif}

uses genlight,variants;

Type
     TLightVariantIntMap = TLightVariantMap<Integer>;

procedure add_to_set(v:variant;ts:TLightVariantMap);
begin
 // lightmap<> is a map<key,value>, not a set. Use integer as dummy value.
 ts.putpair(v,0);
end;

function wert_in_set(wert:variant;list:TLightVariantIntMap):boolean;
var v : integer;
begin
 result:=list.locate(wert,v);
end;


var testset : TLightVariantIntMap;
  v : variant;

procedure testwert(v:variant);
begin
   writeln(wert_in_set(v,testset):5,' ',v);
end;

begin
 testset :=TLightVariantIntMap.create;  
 add_to_set('Otto',TestSet);
 add_to_set(12,TestSet);
 add_to_set(2,TestSet);
 add_to_set(3.200000000,TestSet);
 add_to_set('Text',TestSet);
 add_to_set(1,TestSet);
 add_to_set(55.8800000000,TestSet);
 add_to_set('Hallo',TestSet);

 testwert('Otto');
 testwert(12);
 testwert(2);
 testwert(3.200000000);
 testwert(3.2514);
 testwert('Text');
 testwert(1);
 testwert(-1);
 testwert(55.8800000000);
 testwert('Falsch');
 testwert('Hallo');
 testwert(true);

 for v in testset.keys do // default is iterate over values
   writeln(v);
 testset.free;
end.
