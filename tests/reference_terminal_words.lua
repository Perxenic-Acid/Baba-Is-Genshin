-- Standalone original-source oracle; never load into tests/run.lua's globals.
dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]])
dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/convert.lua]])
objectlist={rock=true,crate=true,avatar=true,all=true,text=true,empty=true,level=true}
function findnoun(n) return n=='all' or n=='text' or n=='empty' or n=='level' end
function getmat(n) return objectlist[n] and n end
function getmat_text(n) return n:sub(1,5)=='text_' and n end
unitreference={};VISION=1;spritedata={values={[1]=1}}
function MF_alert(s) error(s) end
local function run(input)
 features,featureindex,notfeatures,visualfeatures,condfeatureindex,groupfeatures,units,ruleids={},{},{},{},{},{},{},{}
 for _,r in ipairs(input) do addoption(r,{}, {},false) end
 subrules();postrules(true)
 local active={}
 convert=function(name,mats)
  for _,m in ipairs(mats) do
   local works=true
   for _,c in ipairs(m[2]) do if c=='never' or type(c)=='table' and c[1]=='never' then works=false end end
   if works then active[#active+1]={name,m[1],m[3]} end
  end
 end
 conversion();return active
end
local p=run({{'rock','write','push'}});assert(#p==1 and p[1][2]=='push' and p[1][3]=='write')
p=run({{'rock','write','crate'},{'rock','is','rock'}});assert(#p==0)
p=run({{'rock','write','crate'},{'rock','is','not text'}});assert(#p==0)
p=run({{'rock','write','crate'},{'rock','write','not crate'}});assert(#p==0)
p=run({{'all','write','all'}});local n=0
for _,v in ipairs(p) do if not findnoun(v[1]) and not findnoun(v[2]) then n=n+1 end end
assert(n==18)
local literal=0
for _,v in ipairs(p) do if not findnoun(v[1]) and v[2]=='all' and v[3]=='write' then literal=literal+1 end end
assert(literal==3,'ALL WRITE ALL also retains one literal text_ALL per ordinary subject')
p=run({{'rock','write','all'}})
literal=0
for _,v in ipairs(p) do if v[1]=='rock' and v[2]=='all' and v[3]=='write' then literal=literal+1 end end
assert(literal==1,'WRITE ALL must preserve the literal ALL conversion')
nlist={brief={}}
for _,case in ipairs({{'rock','rock',1},{'all','rock',2},{'not crate','rock',2}}) do
 p=run({{case[1],'become','all'}})
 local raw,concrete=0,{}
 for _,v in ipairs(p) do if v[1]==case[2] then
  if v[2]=='createall' then raw=raw+1
  elseif not findnoun(v[2]) then concrete[v[2]]=(concrete[v[2]] or 0)+1 end
 end end
 assert(raw==1,'BECOME ALL retains one literal createall per concrete source')
 for _,name in ipairs({'rock','crate','avatar'}) do
  assert(concrete[name]==case[3],'BECOME ALL concrete expansion multiplicity: '..name)
 end
end
print('PASS: original BECOME ALL literal createall plus concrete/self products and ALL/NOT source paths')
for copies=1,2 do for _,blocked in ipairs({false,true}) do
 local input={{'crate','write','rock'}}
 for i=1,copies do input[#input+1]={'all','mimic','crate'} end
 if blocked then input[#input+1]={'all','mimic','not crate'} end
 p=run(input)
 local counts={}
 for _,v in ipairs(p) do if v[2]=='rock' and v[3]=='write' then counts[v[1]]=(counts[v[1]] or 0)+1 end end
 for _,name in ipairs({'rock','crate','avatar'}) do
  local expected=(blocked and 0 or copies)+(name=='crate' and 1 or 0)
  assert((counts[name] or 0)==expected,'ALL MIMIC source expansion: '..name)
 end
 assert((counts.all or 0)==(blocked and 0 or copies),'native ALL MIMIC retains a raw ALL source record')
end end
print('PASS: original ALL MIMIC source raw/concrete declarations, duplicates, self-copy and NOT protection')
print('PASS: original WRITE property targets, identity/NOT TEXT/NOT target vetoes and ALL multiplicity')
