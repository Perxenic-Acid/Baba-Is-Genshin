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
print('PASS: original WRITE property targets, identity/NOT TEXT/NOT target vetoes and ALL multiplicity')
