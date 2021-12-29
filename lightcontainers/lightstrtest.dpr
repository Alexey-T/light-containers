program lightstrtest;
{$ifdef fpc}
  {$mode delphi}
{$endif}
{$inline on}
{$APPTYPE CONSOLE}

{define checkagainstlist} // should be off for high values of items(> say 50000) or benchmarking.
{$define useinsequence}

{ i7-3770 is about 3-4 times faster.
Laptop Core2 2GHz on high performance settings:
 for i to n tstringlist.add(inttostr(i)); with tstringlist sorted ON.
                     DXE3:                FPC  O4
10000 items took      0.04 seconds
20000 items took      0.18 seconds
40000 items took      0.43 seconds       0.47s
100000 items took      0.88 seconds      0.99s  (both better than 2.5*40000)
200000 items took     12.40 seconds     11.73s // why ? Small to large blocks?

lightmap lists 400000 items: 0.9 - 1.0s             i7: .39

tdatetime op i7 : 0.69 voor 400000 random, 0.06 voor in order.
           1 op de tienduizend random: .43s
}

uses
{$ifndef FPC}  {Fastmm4,}{$endif}
  classes,
  contnrs,
  SysUtils,
  genlight;



// higher values for performance testing, lower values make it doable to check against tstringlist.
const items = 400000;
      cachefnfmt = 'randomnumbers%d.dat';
      seqfnfmt = 'sequencenumbers%d.dat';

var randomnumbers : array[0..items-1] of integer;
    vals  : array[0..items-1] of longint; // local causes stackoverflow
    lblocksize : integer = 256;

function transformstr(i:integer):string;
begin
  result:=IntToHex(i,10);
end;

procedure runtest1;

var m     : TLightStringMapInteger;
    iterkey  : TLightStringMapInteger.DLightMapKeyIterator;
    iterboth : TLightStringMapInteger.DLightMapBothIterator;
    itervalue  : TLightStringMapInteger.DLightMapValueIterator;
    i,j,k : Integer;
    inarr : integer;
    dt,dt2  : TDateTime;
    intvalue : Integer;
    s:string;
    {$ifdef checkagainstlist}
    orderedlist : TStringlist;
    {$endif}

begin
  dt:=now;

  m:=TLightStringMapInteger.Create;
  m.blocksize:=lblocksize;
    {$ifdef checkagainstlist}
    orderedlist :=TStringlist.create;
    orderedlist.sorted:=true;
    {$endif}

  // fill map with "items" count <random number as string, same number as pointer> mappings./
  // Keep an array with all values.
  // We do this so we don't fill the map in-order

  Write('1 creating lightstrmap with ',items,' elements containing x=random  <x as string,x as pointer> mappings');

  inarr:=0;
  repeat
    j:=randomnumbers[inarr]; // random(10000000)+1;
    vals[inarr]:=j;
    inc(inarr);
           // test heavily depends on key and pair having a relation to check integrity
    m.PutPair(transformstr(j),j);  // map string of number to number-as-pointer
    {$Ifdef checkagainstlist}
    orderedlist.AddObject(transformstr(j),pointer(j));
    {$endif}
  until inarr=items;
  dt2:=now;
  writeln('  ',(dt2-dt)*86400.0:10:4,' seconds');

  writeln('Check: items in map:',m.count);
  write('2 Testing contents of randomly filled string map');
  k:=0;
  for j:=0 to items-1 do
    begin
      if m.locate(transformstr(vals[j]),intvalue) then
        begin
           if intvalue<>vals[j] then
            begin
             inc(k);
             writeln('  Wrong mapping',vals[j]);
            end;
       end
      else
        writeln('  Can''t find ',vals[j]);
    end;

  if k<>0 then
     writeln('  Error: ',k,' mappings failed:');

  writeln(' ',(now-dt2)*86400.0:10:4,' seconds');
  dt2:=now;
  Write('3 Removing all even elements, and checking result');

  i:=0;
  while (i<items) do
    begin
      m.Remove(transformstr(vals[i]));
      inc(i,2);
    end;

  i:=0;
  while (i<items) do
    begin
      if m.Locate(transformstr(vals[i]),j) then
        begin
          if ((i mod 2) = 0)  then
            writeln('  Removed element is still here:',vals[i],' value: ',j);
        end
      else
          if ((i mod 2) = 1)  then
           writeln('  Element not here:',vals[i],' value: ',j);
      inc(i);
    end;
  writeln(' ',(now-dt2)*86400.0:10:4,' seconds');
  dt2:=now;

  writeln('Check: items in map:',m.count);
  {$Ifdef checkagainstlist}

  Writeln('4 iterating through the map and checking the values');

  i:=0;
  itervalue:=m.IteratorValue;
  while itervalue.iterate do
    begin
       j:=itervalue.getvalue;   // fast
       s:=itervalue.getkey;     // slow
       if  orderedlist.IndexOf(transformstr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;


  Writeln('5 iterating through the map and checking the keys');

  i:=0;
  iterkey:=m.Iteratorkey;
  while iterkey.iterate do
    begin
       s:=iterkey.getkey;       // fast
       j:=iterkey.getvalue;   // slow
       if  orderedlist.IndexOf(transformstr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;

  Writeln('6 iterating through the map and checking the same on both the same time');

  i:=0;
  iterboth:=m.IteratorBoth;
  while iterboth.iterate do
    begin
       s:=iterboth.getkey; j:=iterboth.getvalue; // both reasonably fast, but less potential for inline.
       if  orderedlist.IndexOf(transformstr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;
  {$endif}
  // Destroying the lightmap stresses the reference counting. If ref count is too low,
  // it comes out here. If it is too high, there are mem leaks (FPC: use -ghl, Delphi: use memproof)
  writeln('99 destroying lightmap');
 {$Ifdef checkagainstlist}
   orderedlist.free;
 {$endif}
  m.free;
  Writeln;
  {$Ifndef checkagainstlist}
  writeln('Test for ',items,' items took ',(now-dt)*86400.0:10:4,' seconds');
  {$endif}
end;


procedure runtest2;

var m     : TLightStringMapString;
    iterkey  : TLightStringMapString.DLightMapKeyIterator;
    iterboth : TLightStringMapString.DLightMapBothIterator;
    itervalue  : TLightStringMapString.DLightMapValueIterator;
    i,j,k : Integer;
    inarr : integer;

    dt    : TDateTime;
    intvalue : Integer;
    s,s2:string;
    {$ifdef checkagainstlist}
    orderedlist : TStringlist;
    {$endif}

begin
  dt:=now;

  m:=TLightStringMapString.Create;
  m.blocksize:=lblocksize;
    {$ifdef checkagainstlist}
    orderedlist :=TStringlist.create;
    orderedlist.sorted:=true;
    {$endif}

  // fill map with "items" count <random number as string, same number as pointer> mappings./
  // Keep an array with all values.
  // We do this so we don't fill the map in-order

  Writeln('1 creating lightstrmap with ',items,' elements containing x=random  <x as string,x as string> mappings');

  inarr:=0;
  repeat
       j:=randomnumbers[inarr];//(10000000)+1;
           vals[inarr]:=j;
           inc(inarr);
           // test heavily depends on key and pair having a relation to check integrity
           m.PutPair(inttostr(j),inttostr(j));  // map string of number to number-as-pointer
           {$Ifdef checkagainstlist}
           orderedlist.Add(inttostr(j));
           {$endif}
  until inarr=items;

  writeln('2 Testing contents of randomly filled string map');
  k:=0;
  for j:=0 to items-1 do
    begin
      if m.locate(inttostr(vals[j]),s) then
        begin
           if s<>inttostr(vals[j]) then
            begin
             inc(k);
             writeln('  Wrong mapping',vals[j]);
            end;
       end
      else
        writeln('  Can''t find ',vals[j]);
    end;

  if k<>0 then
     writeln('  Error: ',k,' mappings failed:');

  Writeln('3 Removing all even elements, and checking result');

  i:=0;
  while (i<items) do
    begin
      m.Remove(inttostr(vals[i]));
      inc(i,2);
    end;

  i:=0;
  while (i<items) do
    begin
      if m.Locate(inttostr(vals[i]),s) then
        begin
          if ((i mod 2) = 0)  then
            writeln('  Removed element is still here:',vals[i],' value: ',s);
        end
      else
          if ((i mod 2) = 1)  then
           writeln('  Element not here:',vals[i],' value: ',s);
      inc(i);
    end;

  {$Ifdef checkagainstlist}

  Writeln('4 iterating through the map and checking the values');

  i:=0;
  itervalue:=m.IteratorValue;
  while itervalue.iterate do
    begin
       s2:=itervalue.getvalue;   // fast
       s:=itervalue.getkey;     // slow
       if  orderedlist.IndexOf(s2)=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;


  Writeln('5 iterating through the map and checking the keys');

  i:=0;
  iterkey:=m.Iteratorkey;
  while iterkey.iterate do
    begin
       s:=iterkey.getkey;       // fast
       s2:=iterkey.getvalue;   // slow
       if  orderedlist.IndexOf(s2)=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;

  Writeln('6 iterating through the map and checking the same on both the same time');

  i:=0;
  iterboth:=m.IteratorBoth;
  while iterboth.iterate do
    begin
       s:=iterboth.getkey;
       s2:=iterboth.getvalue; // both reasonably fast, but less potential for inline.
       if  orderedlist.IndexOf(s2)=-1 then
         Writeln(' object obtained through iteration not found: ',j);
       if  orderedlist.IndexOf(s)=-1 then
         Writeln(' key obtained through iteration not found: ',s);
    end;
  {$endif}
  // Destroying the lightmap stresses the reference counting. If ref count is too low,
  // it comes out here. If it is too high, there are mem leaks (FPC: use -ghl, Delphi: use memproof)
  writeln('99 destroying lightmap');
 {$Ifdef checkagainstlist}
   orderedlist.free;
 {$endif}
  m.free;
  Writeln;
  {$Ifndef checkagainstlist}
  writeln('Test for ',items,' items took ',(now-dt)*86400.0:10:4,' seconds');
  {$endif}
end;

function transformdt(const n:integer):TDatetime; inline;
// used to "transform" random integer input to datetime.
begin
 result:=n/10;
end;

procedure runtest3;

type TRun3Type = TLightDateTimeMap<Integer>;

var m     : TRun3Type;
    iterkey  : TRun3Type.DLightMapKeyIterator;
    iterboth : TRun3Type.DLightMapBothIterator;
    itervalue  : TRun3Type.DLightMapValueIterator;
    i,j,k : Integer;
    inarr : integer;
    dt,dt2  : TDateTime;
    intvalue : Integer;
    s:tdatetime;
    {$ifdef checkagainstlist}
    orderedlist : TStringlist;
    {$endif}

begin
  dt:=now;

  m:=TRun3Type.Create;
  m.blocksize:=lblocksize;
  m.Capacity:=10000;

    {$ifdef checkagainstlist}
    orderedlist :=TStringlist.create;
    orderedlist.sorted:=true;
    {$endif}

  // fill map with "items" count <random number as string, same number as pointer> mappings./
  // Keep an array with all values.
  // We do this so we don't fill the map in-order

  Write('1 creating lightdatetimemap with ',items,' elements containing x=random  <x as datetime,x as pointer> mappings');

  inarr:=0;
  repeat
    j:=randomnumbers[inarr]; // random(10000000)+1;
    vals[inarr]:=j;
    inc(inarr);
           // test heavily depends on key and pair having a relation to check integrity
    m.PutPair(transformdt(j),j);  // map TDatetime of number to number-as-pointer
    {$Ifdef checkagainstlist}
    orderedlist.AddObject(inttostr(j),pointer(j));
    {$endif}
  until inarr=items;
  dt2:=now;
  writeln('  ',(dt2-dt)*86400.0:10:4,' seconds');

  writeln('Check: items in map:',m.count);
  write('2 Testing contents of randomly filled string map');
  k:=0;
  for j:=0 to items-1 do
    begin
      if m.locate(transformdt(vals[j]),intvalue) then
        begin
           if intvalue<>vals[j] then
            begin
             inc(k);
             writeln('  Wrong mapping',vals[j]);
            end;
       end
      else
        writeln('  Can''t find ',vals[j]);
    end;

  if k<>0 then
     writeln('  Error: ',k,' mappings failed:');

  writeln(' ',(now-dt2)*86400.0:10:4,' seconds');
  dt2:=now;
  Write('3 Removing all even elements, and checking result');

  i:=0;
  while (i<items) do
    begin
      m.Remove(transformdt(vals[i]));
      inc(i,2);
    end;

  i:=0;
  while (i<items) do
    begin
      if m.Locate(transformdt(vals[i]),j) then
        begin
          if ((i mod 2) = 0)  then
            writeln('  Removed element is still here:',vals[i],' value: ',j);
        end
      else
          if ((i mod 2) = 1)  then
           writeln('  Element not here:',vals[i],' value: ',j);
      inc(i);
    end;
  writeln(' ',(now-dt2)*86400.0:10:4,' seconds');
  dt2:=now;

  writeln('Check: items in map:',m.count);
  {$Ifdef checkagainstlist}

  Writeln('4 iterating through the map and checking the values');

  i:=0;
  itervalue:=m.IteratorValue;
  while itervalue.iterate do
    begin
       j:=itervalue.getvalue;   // fast
       s:=itervalue.getkey;     // slow
       if transformdt(j)<>s then
         Writeln(' key and object don''t match during iteration: ',j,' ',s);
       if  orderedlist.IndexOf(inttostr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
//       if  orderedlist.IndexOf(inttostr(j))=-1 then
//         Writeln(' key obtained through iteration not found: ',s);
    end;


  Writeln('5 iterating through the map and checking the keys');

  i:=0;
  iterkey:=m.Iteratorkey;
  while iterkey.iterate do
    begin
       s:=iterkey.getkey;       // fast
       j:=iterkey.getvalue;   // slow
       if transformdt(j)<>s then
         Writeln(' key and object don''t match during iteration: ',j,' ',s);
       if  orderedlist.IndexOf(inttostr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
//       if  orderedlist.IndexOf(s)=-1 then
//         Writeln(' key obtained through iteration not found: ',s);
    end;

  Writeln('6 iterating through the map and checking the same on both the same time');

  i:=0;
  iterboth:=m.IteratorBoth;
  while iterboth.iterate do
    begin
       s:=iterboth.getkey; j:=iterboth.getvalue; // both reasonably fast, but less potential for inline.
       if transformdt(j)<>s then
         Writeln(' key and object don''t match during iteration: ',j,' ',s);
       if  orderedlist.IndexOf(inttostr(j))=-1 then
         Writeln(' object obtained through iteration not found: ',j);
//       if  orderedlist.IndexOf()=-1 then
//         Writeln(' key obtained through iteration not found: ',s);
    end;
  {$endif}
  // Destroying the lightmap stresses the reference counting. If ref count is too low,
  // it comes out here. If it is too high, there are mem leaks (FPC: use -ghl, Delphi: use memproof)
  writeln('99 destroying lightmap');
 {$Ifdef checkagainstlist}
   orderedlist.free;
 {$endif}
  m.free;
  Writeln;
  {$Ifndef checkagainstlist}
  writeln('Test for ',items,' items took ',(now-dt)*86400.0:10:4,' seconds');
  {$endif}
end;


var i,v : integer;
    tst :Tstringlist;
    dt : tdatetime;
    f : File;
    cachefn : string;

begin
  if paramcount>0 then
    if TryStrToInt(paramstr(1),i) then
      lblocksize:=i;

  writeln('using blocksize: ',lblocksize);
  randomize;
  {$ifdef useinsequence}
  cachefn:=Format(seqfnfmt,[items]);
  {$else}
  cachefn:=Format(cachefnfmt,[items]);
  {$endif}
  dt:=now;
  // since random is more expensive in FPC than in Delphi, we use it outside
  // timing loops.
  // If you think this step is slow, keep in mind that this is exactly the
  // step that we try to avoid with lightmap :-)

  if fileexists(cachefn) then
    begin
      assignfile(f,cachefn);
      reset(f,1);
      blockread(f,randomnumbers[0],length(randomnumbers)*sizeof(randomnumbers[0]));
      closefile(f);
    end
  else
   begin
      Writeln('Generate ',items,' integers of unique random data');
      tst:=TStringList.Create; tst.Sorted:=true;
      i:=0;
      repeat
       {$ifdef useinsequence}
        v:=i;
        if (i mod 10000)=0 then
          v:=random(100000000)+1;
        tst.add(inttostr(v));
        randomnumbers[i]:=v;
        inc(i);
       {$else}
        v:=random(100000000)+1;
        if tst.IndexOf(inttostr(v))=-1 then
          begin
            tst.add(inttostr(v));
            randomnumbers[i]:=v;
            inc(i);
            if (i mod 100000)=0 then
              writeln(i,' items took', (now-dt)*86400.0:10:2, ' seconds');

          end;
        {$endif}
      until i=items ;
      tst.Free;
      assignfile(f,cachefn);
      rewrite(f,1);
      blockwrite(f,randomnumbers[0],length(randomnumbers)*sizeof(randomnumbers[0]));
      closefile(f);
   end;
  runtest1;
  Writeln('-----');
  runtest2;
  runtest3;
end.
