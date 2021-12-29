unit genlight;
{
    Portions copyright (c) 2004 by Essent/Milieu Diftar
    Original author: Marco van de Voort (Essent/Milieu Diftar)
    Generic version rewritten on the basis of the old sources (c) 2012-2016 Marco van de Voort.

    Container type that is still an ordered list (for iteration) but scales better than
    TStringList by making the array an array of array.

    Later tests with Micha Nelissen show that this principle postpones the inevitable
    till about 5M-6M objects. (the problems of happen tstringlist * blocksize*4/tlightmapblock
    probably, then one needs a third array level). Some dynamic resizing of subblocks might help,
    but I haven't needed such magnitudes yet

    The license for this file is a slightly more liberal form of the
    Library General Public License by GNU.
    See the files COPYING (GNU GPL)
         and      COPYING.FPC (static linking exception)
    included in this distribution, for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    Warning:
    Contrary to Delphi types, the default iterator is values, not keys. This is done because
    quite often the value is  an object that contains the key at least partially.

}

interface
{$ifdef FPC}
 {$Mode Delphi}
{$endif}
{$pointermath on} // Be more objfpc like in overindexing and removing of ^.
                  // this means we can kill old ^array[0..0] of integer like workarounds
                  // that generate compiletime rangecheck errors in both FPC and Delphi
{$inline on}

type
  {$ifndef FPC} // needs fix for XE2
  {$ifdef win64}
     PtrInt  = nativeint;
     ptruint = nativeuint;
  {$else}
     PtrInt  = integer;
     ptruint = cardinal;
  {$endif}
  {$endif}
  TResultType = Integer;
     { TLightMap }

     TLightMap<tkey,tvalue> = class
                       Type
                         TPair = record
                                   key :TKey;
                                   Value :TValue;
                         end;
                         PKey  = ^TKey;
                         PValue= ^TValue;
                         TKeyCompareFunc  = function(const Key1, Key2: TKey): TResultType ; // returns ptrint in FPC, don't know about XE2
                         TFinalizeKeyFunc = Procedure(var Key1:TKey) of object;
                         TFinalizeValueFunc = Procedure(var AValue:TValue) of object;
                         TSelectFunc      = function (const Key:TKey;const value:TValue):Boolean;
                         TRemoveFunc      = procedure (const Key:TKey;const value:TValue);
                         TLightMapBlock = Record
                                           AllocSize : integer;
                                           Entries   : integer;
                                           firstkey  : TKey;   // cached;
                                           Keys      : array of TKey;
                                           values    : Array of TValue;
                                         end;
                         PLightMapBlock = ^TLightMapBlock;

                         { DLightMapValueIterator }

                         DLightMapValueIterator=record
                                            private
                                             next : pvalue;
                                             cnt  : Integer;
                                             blk  : integer;
                                             p    : TLightMap<tkey,tvalue>;
                                             procedure advance;
                                            public
                                             function iterate:boolean; inline;
                                             function getvalue:TValue; inline;
                                             function getpvalue:PValue; Inline;
                                             function getpkey :PKey; Inline;
                                             function getkey  :TKey; inline;
                                             function atend:boolean; inline;
                                             function getenumerator :DLightMapValueIterator;
                                             function MoveNext:Boolean; // This is where filtering happens
                                             property Current:TValue read getvalue;
                                            end;
                         DLightMapKeyIterator=record
                                            private
                                             next : pkey;
                                             cnt  : Integer;
                                             blk  : integer;
                                             p    : TLightMap<tkey,tvalue>;
                                             procedure advance;
                                            public
                                             function iterate:boolean; inline;
                                             function getvalue:TValue; inline;
                                             function getkey  :TKey; inline;
                                             function getpkey :PKey; Inline;
                                             function atend:boolean; inline;
                                             function MoveNext:Boolean; // This is where filtering happens
                                             function getenumerator :DLightMapKeyIterator;
                                             property Current:TKey read getkey;
                                            end;
                         DLightMapBothIterator=record
                                            private
                                             next : pkey;
                                             nextv: pvalue;
                                             cnt  : Integer;
                                             blk  : integer;
                                             p    : TLightMap<tkey,tvalue>;
                                             procedure advance;
                                            public
                                             function iterate:boolean; inline;
                                             function getvalue:TValue; inline;
                                             function getkey  :TKey; inline;
                                             function getpvalue:PValue; Inline;
                                             function getpkey :PKey; Inline;
                                             function getpair : TPair;
                                             function atend:boolean; inline;
                                             function getenumerator : DLightMapBothIterator;
                                             function MoveNext:Boolean; // This is where filtering happens
                                             property Current:TPair read getPair;
                                            end;

//                         arrblk       =  TLightMapBlock; // was array[0..maxint div sizeof(lightmapblock)-1] of LightMapBlock in old Delphis.
//                         parrblk      = ^arrblk;
                       private
                         const // for Sven's peace of mind. Delphi allows these to be local constants for simple cases. More complex also IE.
                               blkexponentgrowth = 2*1024*1024; // grow blks array exponentially till this size in bytes
                               blktopincrement   = 1000;
                         var
                         fBlocksize : integer;  // max items per block
                         nrblocks  : integer;  // cur blocks in use.
                         blks      : array of TLightMapBlock;
                         keycomparefunc:TKeyCompareFunc;
                         finalizekeyfunc:TFinalizeKeyFunc;      // finalize keys. NIL if unused.
                         finalizevaluefunc:TFinalizeValueFunc;  // finalize value. NIL if not needed.
                         procedure setcapacity(const Value: integer);        // after exponentgrowth, use this value.
                         function searchblock(const key:tkey):integer;
                         function binsearch(var m:TLightmapBlock;const key:TKey):Integer;
                       public
                         fduplicates : boolean;
                         constructor Create; virtual;
                         Destructor Destroy; override;
                         procedure  Clear;
                         procedure  PutPair(const key:TKey; const value:TValue);
                         procedure  AddObject(const key:TKey; const value:TValue);
                         function   Locate(const key:TKey;var value:TValue):boolean;
                         function   Remove(const key:TKey):TValue;
                         function   RemoveIf(selfunc:TSelectFunc;remfunc:TRemoveFunc):integer;
                         function   IteratorValue:DLightMapValueIterator;
                         function   IteratorValueFrom(key:TKey):DLightMapValueIterator;
                         function   IteratorKey:DLightMapKeyIterator;
                         function   IteratorKeyFrom(key:TKey):DLightMapKeyIterator;
                         function   IteratorBoth:DLightMapBothIterator;
                         function   IteratorBothFrom(key:TKey):DLightMapBothIterator;
                         function   allocated:integer;
                         function   count : integer;
                         procedure  genfinalizekey(var key:TKey);
                         procedure  genfinalizevalue(var Value:TValue);
                         function   getEnumerator : DLightmapValueIterator;
                         // use only just after creation:
                         property   blocksize :integer read fblocksize write fblocksize;
                         property   Capacity : integer write setcapacity;
                         property   Keys  :  DLightMapKeyIterator read IteratorKey;
                         property   Values :  DLightMapValueIterator read IteratorValue;
                         property   Both :  DLightMapBothIterator read IteratorBoth;
                         property   onkeycompare : TKeycomparefunc read keycomparefunc write keycomparefunc;
                       end;



     TLightStringMap<tvalue> = class(TLightMap<string,tvalue>)
                                 constructor create; override;
                                 end;
//     TI1152 in XE3:
//     DLightMapObjectValueIterator = TLightStringMap<Tobject>.DLightMapValueIterator;
     TLightDateTimeMap<tvalue> = class(TLightMap<TDateTime,tvalue>)
                                 constructor create; override;
                                 end;

     TLightIntMap<TValue>   = class(TLightMap<integer,tvalue>)
                                 constructor create; override;
                                 end;

     TLightInt64Map<TValue>   = class(TLightMap<int64,tvalue>)
                                 constructor create; override;
                                 end;

     TLightStringMapInteger  = class(TLightStringMap<Integer>);
     TLightStringMapString  = class(TLightStringMap<String>)
                                   constructor Create; override;
                                  end;

      { TLightVariantMap }

      TLightVariantMap<TValue> = class(TLightMap<Variant,tvalue>)
                                  constructor create; override;
                                 end;



// all compare functions must be exported
function CompareInteger(const key1,key2:integer):TResultType;
function CompareInt64(const key1,key2:int64):TResultType;
function CompareDatetime(const Key1, Key2: TDatetime):TResultType;
function CompareReverseInteger(const key1,key2:integer):TResultType;
function Comparevariant(const key1,key2:variant):TResultType;

// the below symbols are mostly internal stuff that is exported to facilitate unit testing

const initallocsize = 16;


implementation

Uses Sysutils,dateutils,variants;

// the rules for managed (ref counted) types as parameters are simple:
// deleted fields need to be finalized.
// if you move a key or value that is a managed type, you need to zero the old one.
// since otherwise assigning a new value to that cell will decrease the old refcount
// and corrupt the refcount of that cell.

function CompareInteger(const key1,key2:integer):TResultType ;
begin
  result:=key1-key2;
end;

function CompareInt64(const key1,key2:int64):TResultType ;
begin
  result:=key1-key2;
end;

function CompareReverseInteger(const key1,key2:integer):TResultType ;
begin
  result:=key2-key1;
end;

function Comparevariant(const key1,key2:variant):TResultType;
begin
  result:=ord(vartype(key1))-ord(vartype(key2));
  if result=0 then
    begin
      if key1>key2 then
        result:=1
      else
        if key1<key2 then
         result:=-1
        else
         result:=0;
    end;
end;

{ TLightMap<tkey, tvalue> }

constructor TLightMap<tkey, tvalue>.Create;
begin
 Clear;
end;

procedure TLightMap<tkey, tvalue>.AddObject(const key:TKey; const value:TValue);
begin
  PutPair(Key,Value);
end;

procedure TLightMap<tkey, tvalue>.PutPair(const key:TKey; const value:TValue);

var i,j,k : integer;
  //  blk : PLightMapBlock;
    curentry : integer;

begin
{      if value=nil then         // seems to be not needed. Either bad fix for something that got fixed later, *if j=1 then j=0) or debug point
        blk:=blks[0];}
      curentry:=searchblock(key);
      if curentry=-1 then curentry:=0;
      if blks[curentry].Entries=0 then
        begin
          with blks[curentry] do
            begin
              allocsize:=initallocsize;
              setlength(values,initallocsize);
              setlength(keys,initallocsize);
              values[0]:=value;
              keys[0]:=key;
              firstkey:=key;
              entries:=1;
            end;
        end
       else
         begin
           //blk:=@blks[j];
           i:=binsearch(blks[curentry],key);
           if i=-1 then i:=0;

           if not fduplicates and (i<blks[curentry].Entries) and (keycomparefunc(key,blks[curentry].keys[i])=0) then
             begin
                // if duplicates allow iterate entries here?
                // blk.values[i]:=value;
                exit;           // key already exists
             end;
           if (blks[curentry].entries+1)=blks[curentry].allocsize then
              begin
                blks[curentry].allocsize:=blks[curentry].allocsize*2;  // shouldn't this be more graceful (probably bounded by blocksize, so no problem)
                setlength(blks[curentry].values,blks[curentry].allocsize);
                setlength(blks[curentry].keys,blks[curentry].allocsize);
              end;
           if i=(blks[curentry].entries) then
              begin
                blks[curentry].keys[i]:=key;
                blks[curentry].values[i]:=value;
                if blks[curentry].entries=0 then
                  blks[curentry].firstkey:=key;
                inc(blks[curentry].entries);
              end
           else
           if i=0 then
             begin
               move (blks[curentry].keys[0],blks[curentry].keys[1],blks[curentry].Entries*sizeof(TKey));
               move (blks[curentry].values[0],blks[curentry].values[1],blks[curentry].Entries*sizeof(TValue));
               fillchar(blks[curentry].Keys[0],sizeof(tkey),#0);
               fillchar(blks[curentry].values[0],sizeof(tvalue),#0);
               blks[curentry].keys[0]:=key;
               blks[curentry].values[0]:=value;
               inc(blks[curentry].Entries);
               blks[curentry].firstkey:=key;
             end
           else
              begin
                move (blks[curentry].keys[i],blks[curentry].keys[i+1],(blks[curentry].Entries-i)*sizeof(TKey));
                move (blks[curentry].values[i],blks[curentry].values[i+1],(blks[curentry].Entries-i)*sizeof(TValue));
                fillchar(blks[curentry].Keys[i],sizeof(tkey),#0);
                fillchar(blks[curentry].values[i],sizeof(tvalue),#0);
                blks[curentry].keys[i]:=key;
                blks[curentry].values[i]:=value;
                inc(blks[curentry].Entries);
              end;
            if blks[curentry].entries>=fblocksize then  // we have done an insertion and the block is too big.
              begin
                inc(nrblocks);
                if length(blks)<nrblocks then
                  begin
                    if nrblocks*sizeof(blks[0])<blkexponentgrowth then
                      setlength(blks,5*nrblocks div 4)
                    else
                      setlength(blks,nrblocks+blktopincrement)
                  end;
                j:=curentry;
                move (blks[j],blks[j+1],sizeof(TLightMapBlock)*(nrblocks-j-1));
                fillchar(blks[j+1],sizeof(TLightMapBlock),#0);
                k:=blks[j].Entries div 4;
                i:=blks[j].Entries-k;
                blks[j].Entries:=i;
                blks[j+1].Entries:=k;
                blks[j+1].allocsize:=blks[j].Entries;
                setlength(blks[j+1].values,blks[j].Entries);
                setlength(blks[j+1].keys,blks[j].Entries);
                move(blks[j].values[i],blks[j+1].values[0],k*sizeof(TValue));
                move(blks[j].keys[i],blks[j+1].keys[0],k*sizeof(TKey));
                fillchar(blks[j].values[i],k*sizeof(tvalue),#0);
                fillchar(blks[j].keys[i],k*sizeof(tkey),#0);
                blks[j+1].firstkey:=blks[j+1].keys[0];
              end;
         end;
end;

function TLightMap<tkey, tvalue>.searchblock(const key:tkey):integer;

var i,lo,hi : integer;

begin
  i:=nrblocks-1;
  if i<0 then
    begin
      Result:=-1;
      exit;
    end;
  if keycomparefunc(key,blks[i].firstkey)>0 then
    begin
      result:=i;
      exit;
    end;

  lo:=-1; hi:=i+1;
  while (hi-lo)>1 do
    begin
      i:=(hi+lo) div 2;
  {    if (i>=nrblocks) or (i<0) then
          halt;}
      if keycomparefunc(key,blks[i].firstkey)<0 then
        hi:=i
      else
        lo:=i;
    end;
  result:=lo;
end;

procedure TLightMap<tkey, tvalue>.setcapacity(const Value: integer);
begin
 if value>length(blks) then
    setlength(blks,value);
end;

function TLightMap<tkey, tvalue>.allocated: integer;
var  i,j,k : integer;
begin
 result:=0;
 i:=0;
 k:=0;
 j:=nrblocks;
 while (i<j) do
   begin
     inc(k,blks[i].allocsize+1);
     inc(i);
   end;
 result:=k;
end;


function TLightMap<tkey, tvalue>.BinSearch(var m:TLightmapBlock;const key:TKey):Integer;

var hi,lo,i,j : integer;
//    keys: PKey;
    entries : integer;

begin
  result:=-1;
  entries:=m.entries;

  if assigned(m.keys) and (entries>0) then
   begin
    // keys:=@m.keys[0];
  if keycomparefunc(key,m.keys[entries-1])>0 then
    begin
      result:=entries;
      exit;
    end;
     lo:=-1; hi:=entries;
     while (hi-lo)>1 do
       begin
         i:=(hi+lo) div 2;
         if (i>=entries) or (i<0) then
           halt;
         if keycomparefunc(key,m.keys[i])=0 then
            begin result:=i; exit; end;
         if keycomparefunc(key,m.keys[i])<0 then
          hi:=i
         else
          lo:=i;
       end;
       result:=hi;
   end;
end;

procedure TLightMap<tkey, tvalue>.Clear;
begin
  fblocksize:=256;
  setlength(blks,0); // release all objects.

  nrblocks:=1;
  setlength(blks,1);
  fillchar(blks[0],sizeof(blks[0]),#0);
end;

function TLightMap<tkey, tvalue>.count: integer;
var  i,j,k : integer;
begin
 result:=0;
 i:=0;
 k:=0;
 j:=nrblocks;
 while (i<j) do
   begin
     inc(k,blks[i].Entries);
     inc(i);
   end;
 result:=k;
end;


function TLightMap<tkey, tvalue>.Locate(const key:TKey;var value:TValue):boolean;
var i,j : integer;

begin
 result:=false;
 if nrblocks>0 then
   begin
    j:=searchblock(key);
    if j=-1 then exit;                  // no blocks yet.
    i:=binsearch(blks[j],key);
    if (i=-1) or (i=blks[j].Entries) then exit;
    if keycomparefunc(key, blks[j].keys[i])=0 then
      begin
        result:=true;
        value:=blks[j].values[i];
      end;
   end;
end;

function TLightMap<tkey, tvalue>.Remove(const key:TKey):TValue;

var i,j : integer;
    blk : PLightmapBlock;
    entries : integer;

begin
 if  nrblocks>0 then
   begin
    j:=searchblock(key);
    if j=-1 then exit;                  // no blocks yet.
    i:=binsearch(blks[j],key);
    entries:=blks[j].Entries;
    if (i=-1) or (i=entries) then exit;
    blk:=@blks[j];
    if keycomparefunc(key, blk.keys[i])=0 then
      begin
        if i<>Entries then
          begin
            if assigned(finalizekeyfunc) then
              finalize(blk.keys[i]);
            result:=blk.values[i];
            if assigned(finalizevaluefunc) then
              finalize(blk.values[i]);
            move (blk.values[i+1],blk.values[i],(Entries-i)*sizeof(TValue));
            move (blk.keys[i+1],blk.keys[i],(Entries-i)*sizeof(TKey));
            // if this is not done, finalizing the dyn arrays on destroy will end in crashes.
            if assigned(finalizekeyfunc) then
              fillchar(blk.keys[blk.entries-1],sizeof(tkey),#0);
            if assigned(finalizevaluefunc) then
              fillchar(blk.values[blk.entries-1],sizeof(tvalue),#0);
          end;
        dec(blks[j].Entries);
      end;
   end;
end;

function TLightMap<tkey, tvalue>.RemoveIf(selfunc: TSelectFunc;
  remfunc: TRemoveFunc): integer;
var Entries,
    i,
    blkindx,
    blknr   : integer;
    keys    : PKey;
    values  : PValue;
begin

     blkindx:=0;
     blknr:=nrblocks;
     if assigned(blks) then
       begin
         while (blkindx<blknr) do
           begin
             // we are going to iterate linearly. Cache as much as possible in locals:
             Entries:=blks[blkindx].entries;
             keys:=@blks[blkindx].keys[0];
             values:=@blks[blkindx].values[0];
             i:=0;
             while (i<Entries) do
               begin
                 if selfunc(keys[0],values[0]) then
                   begin
                     if assigned(remfunc) then
                      remfunc(keys[0],values[0]);
                     if assigned(finalizekeyfunc) then
                       finalizekeyfunc(keys[0]);
                     if assigned(finalizevaluefunc) then
                       finalizevaluefunc(values[0]);
                     if i<>(Entries-1) then
                       begin
                         move (values[1],values[0],(Entries-i)*sizeof(tvalue));
                         move (keys[1],keys[0],(Entries-i)*sizeof(tkey));
                       end;
                     fillchar(keys[entries-i],sizeof(tkey),#0);
                     fillchar(values[entries-i],sizeof(tvalue),#0);
                     dec(entries);
                   end
                 else
                  begin
                    inc(i);
                    inc(pbyte(values),sizeof(tvalue));
                    inc(pbyte(keys),sizeof(tkey));
                  end;
               end;
             blks[blkindx].entries:=Entries; // was cached, restore.
             inc(blkindx);
           end;
       end;
 result:=i;
end;

Destructor TLightMap<tkey, tvalue>.Destroy;

begin
  // in the generics version we can leave that to Delphi, since we mess less with pointers.
  // in future add ways to own keys and or values in case they are ref types.
  {if assigned(m) then
    begin
     i:=0;
     j:=m.nrblocks;
     if assigned(m.blks) then
       begin
         while (i<j) do
           begin
             if assigned(m.blks[i].keys) then
               begin
                 if m.blks[i].entries>0 then
                   begin
                     string(m.blks[i].firstkey):='';
                     for k:=0 to m.blks[i].entries-1 do
                       string(m.blks[i].keys[k]):='';
                   end;
                 freemem(m.blks[i].keys);
               end;
             if assigned(m.blks[i].values) then
               freemem(m.blks[i].values);
             inc(i);
           end;
         freemem(m.blks);
       end;
     freemem(m);
      m:=nil;
    end;  }

end;

procedure TLightMap<tkey, tvalue>.genfinalizekey(var key: TKey);
begin
  finalize(key);
end;

procedure TLightMap<tkey, tvalue>.genfinalizevalue(var value: TValue);
begin
  finalize(value);
end;

function TLightMap<tkey, tvalue>.getEnumerator: DLightmapValueIterator;
begin
 result:=iteratorvalue;
end;

function TLightMap<tkey, tvalue>.IteratorValueFrom(key:TKey): DLightMapValueIterator;
var i,j : integer;

begin
 result.p:=self;
 result.blk:=0;
 result.cnt:=-1;
 result.next:=nil;
 if ( nrblocks>0) and assigned(keycomparefunc) then
   begin
    j:=searchblock(key);
    if j=-1 then exit;                          // no blocks yet.
    i:=binsearch(blks[j],key);
    if (i=-1) or (i=blks[j].Entries) then exit;  // not found.
    if keycomparefunc(key,blks[j].keys[i])<>0 then
      exit;
    result.cnt:=blks[j].Entries-i;
    if result.cnt>0 then
      begin
        result.next:=pointer(@blks[j].values[i]);
        dec(result.next);
      end
   end;
end;

function TLightMap<tkey, tvalue>.IteratorBoth: DLightMapBothIterator;
begin
  result.p:=self;
  result.blk:=0;
  if nrblocks>0 then
    result.cnt:=blks[0].Entries
  else
    result.cnt:=-1;
  result.next:=nil;
  result.nextv:=nil;

  if result.cnt>0 then
    begin
     result.next:=pointer(blks[0].keys);
     result.nextv:=pointer(blks[0].values);
     dec(result.next);
     dec(result.nextv);
    end
  else
     result.next:=nil;
end;

function TLightMap<tkey, tvalue>.IteratorBothFrom(
  key: TKey): DLightMapBothIterator;
var i,j : integer;
begin
 result.p:=self;
 result.blk:=0;
 result.cnt:=-1;
 result.next:=nil;
 if ( nrblocks>0) and assigned(keycomparefunc) then
   begin
    j:=searchblock(key);
    if j=-1 then exit;                          // no blocks yet.
    i:=binsearch(blks[j],key);
    if (i=-1) or (i=blks[j].Entries) then exit;  // not found.
    if keycomparefunc(key,blks[j].keys[i])<>0 then
      exit;
    result.cnt:=blks[j].Entries-i;
    if result.cnt>0 then
      begin
        result.next:=pointer(@blks[j].keys[i]);
        result.nextv:=pointer(@blks[j].values[i]);
        dec(result.next);
        dec(result.nextv);
      end
   end;
end;

function TLightMap<tkey, tvalue>.IteratorKey: DLightMapKeyIterator;
begin
  result.p:=self;
  result.blk:=0;
  if nrblocks>0 then
    result.cnt:=blks[0].Entries
  else
    result.cnt:=-1;
  result.next:=nil;

  if result.cnt>0 then
    begin
     result.next:=pointer(blks[0].keys);
     dec(result.next);
    end
  else
     result.next:=nil;
end;

function TLightMap<tkey, tvalue>.IteratorKeyFrom(
  key: TKey): DLightMapKeyIterator;
var i,j : integer;
begin
 result.p:=self;
 result.blk:=0;
 result.cnt:=-1;
 result.next:=nil;
 if ( nrblocks>0) and assigned(keycomparefunc) then
   begin
    j:=searchblock(key);
    if j=-1 then exit;                          // no blocks yet.
    i:=binsearch(blks[j],key);
    if (i=-1) or (i=blks[j].Entries) then exit;  // not found.
    if keycomparefunc(key,blks[j].keys[i])<>0 then
      exit;
    result.cnt:=blks[j].Entries-i;
    if result.cnt>0 then
      begin
        result.next:=pointer(@blks[j].keys[i]);
        dec(result.next);
      end
   end;
end;

function TLightMap<tkey, tvalue>.IteratorValue: DLightMapValueIterator;
begin
  result.p:=self;
  result.blk:=0;
  if nrblocks>0 then
    result.cnt:=blks[0].Entries
  else
    result.cnt:=-1;
  result.next:=nil;
  if result.cnt>0 then
    begin
     result.next:=pointer(blks[0].values);
     dec(result.next);
    end
  else
     result.next:=nil;
end;

{ TLightMap<tkey, tvalue>.DLightMapValueIterator }

procedure TLightMap<tkey, tvalue>.DLightMapValueIterator.advance;
begin
  cnt:=0; //dummy
  while (p.nrblocks>(blk+1)) and ((cnt=0) or (cnt=-1)) do
    begin
      inc(blk);
      cnt:=p.blks[blk].Entries-1;
      next:=pointer(p.blks[blk].values);
    end;
  if (blk>=p.nrblocks) then
    cnt:=-1;
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.atend: boolean;
begin
  result:=(cnt<0);
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.getenumerator: DLightMapValueIterator;
begin
 result:=self;
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.getkey: TKey;
begin
  result:=pkey(pbyte(p.blks[blk].keys)+(sizeof(tkey)*(pbyte(next)-pbyte(p.blks[blk].values)) div sizeof(tvalue)))[0];
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.getvalue: TValue;
begin
  result:=next^;
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.getpkey: PKey;
begin
  result:=pkey(pbyte(p.blks[blk].keys)+(sizeof(tkey)*(pbyte(next)-pbyte(p.blks[blk].values)) div sizeof(tvalue)));
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.getpvalue: pValue;
begin
  result:=next;
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.iterate: boolean;
begin
 if not assigned (p) then
   exit(false);
  inc(next);
  dec(cnt);
  if (cnt=-1) and (p.nrblocks>(blk+1))  then
    advance;
  result:=cnt>=0;
end;

function TLightMap<tkey, tvalue>.DLightMapValueIterator.MoveNext: Boolean;
begin
 result:=iterate;
end;

{ TLightStringMap<tvalue> }

constructor TLightStringMap<tvalue>.create;
begin
  inherited;
  keycomparefunc:=comparestr;
  finalizekeyfunc:=genfinalizekey;
end;

{ TLightMap<tkey, tvalue>.DLightMapKeyIterator }

procedure TLightMap<tkey, tvalue>.DLightMapKeyIterator.advance;
begin
  cnt:=0; //dummy
  while (p.nrblocks>(blk+1)) and ((cnt=0) or (cnt=-1)) do
    begin
      inc(blk);
      cnt:=p.blks[blk].Entries-1;
      next:=pointer(p.blks[blk].keys);
    end;
  if (blk>=p.nrblocks) then
    cnt:=-1;
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.atend: boolean;
begin
  result:=(cnt<0);
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.getenumerator: DLightMapKeyIterator;
begin
  result:=self;
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.getkey: TKey;
begin
  result:=next^;
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.getpkey: PKey;
begin
  result:=next;
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.getvalue: TValue;
begin
 result:=pvalue(pbyte(p.blks[blk].values)+(sizeof(tvalue)*(pbyte(next)-pbyte(p.blks[blk].keys)) div sizeof(tkey)))[0];
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.iterate: boolean;
begin
 if not assigned (p) then
   exit(false);
  inc(next);
  dec(cnt);
  if (cnt=-1) and (p.nrblocks>(blk+1))  then
    advance;
  result:=cnt>=0;
end;

function TLightMap<tkey, tvalue>.DLightMapKeyIterator.MoveNext: Boolean;
begin
 result:=iterate;
end;

{ TLightMap<tkey, tvalue>.DLightMapBothIterator }

procedure TLightMap<tkey, tvalue>.DLightMapBothIterator.advance;
begin
  cnt:=0; //dummy
  while (p.nrblocks>(blk+1)) and ((cnt=0) or (cnt=-1)) do
    begin
      inc(blk);
      cnt:=p.blks[blk].Entries-1;
      next:=pointer(p.blks[blk].keys);
      nextv:=pointer(p.blks[blk].values);
    end;
  if (blk>=p.nrblocks) then
    cnt:=-1;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.atend: boolean;
begin
  result:=(cnt<0);
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getenumerator: DLightMapBothIterator;
begin
 result:=self;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getkey: TKey;
begin
  result:=next^;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getpair: TPair;
begin
  result.key:=next^; result.Value:=nextv^;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getpkey: PKey;
begin
  result:=next;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getpvalue: PValue;
begin
  result:=nextv;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.getvalue: TValue;
begin
    result:=nextv^;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.iterate: boolean;
begin
  if not assigned (p) then
   exit(false);
  inc(next);
  inc(nextv);
  dec(cnt);
  if (cnt=-1) and (p.nrblocks>(blk+1))  then
    advance;
  result:=cnt>=0;
end;

function TLightMap<tkey, tvalue>.DLightMapBothIterator.MoveNext: Boolean;
begin
  result:=iterate;
end;

{ TLightVariantMap }

constructor TLightVariantMap<TValue>.create;
begin
  inherited create;
   keycomparefunc:=comparevariant;
end;

constructor TLightStringMapString.Create;
begin
  inherited;
  finalizevaluefunc:=genfinalizevalue;
end;

function comparedatetime(const Key1, Key2: TDatetime): TResultType;
begin
  result:=ptrint(dateutils.CompareDateTime(key1,key2))
end;

{ TLightDateTimeMap<tvalue> }


constructor TLightDateTimeMap<tvalue>.create;
begin
  inherited;
  keycomparefunc:=comparedatetime;
//  finalizekeyfunc:=genfinalizekey; // value type.
end;

{ TLightInt64Map<TValue> }

constructor TLightInt64Map<TValue>.create;
begin
  inherited;
  keycomparefunc:=compareint64;
end;

{ TLightIntMap<TValue> }

constructor TLightIntMap<TValue>.create;
begin
  inherited;
  keycomparefunc:=compareinteger;
end;

end.
