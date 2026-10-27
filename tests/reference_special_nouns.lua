-- Standalone oracle: original rule expansion and negation, no engine UI.
dofile([[C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data/rules.lua]])
objectlist={rock=true,crate=true,avatar=true,all=true,text=true,empty=true,level=true}
function findnoun(n) return n == 'all' or n == 'text' or n == 'empty' or n == 'level' end
function getmat(n) return objectlist[n] and n end
function MF_alert(s) error(s) end
VISION=1;spritedata={values={[1]=1}}
local function run(input)
 features,featureindex,notfeatures,visualfeatures,condfeatureindex,groupfeatures,units,ruleids={},{},{},{},{},{},{},{}
 for _,r in ipairs(input) do addoption(r,{}, {},false) end
 subrules();postrules(true)
 local counts={}
 for _,r in ipairs(features) do
  local active=true;for _,c in ipairs(r[2]) do if c[1]=='never' then active=false end end
  if active and not findnoun(r[1][1]) and r[1][2]=='has' and not findnoun(r[1][3]) and not r[1][3]:find('not ',1,true) then
   local k=table.concat(r[1],' ');counts[k]=(counts[k] or 0)+1
  end
 end
 return counts
end
local c=run({{'all','has','all'}});local n=0;for _,v in pairs(c) do n=n+v end
print('Original ALL HAS ALL products:',n)
assert(n==18)
c=run({{'rock','has','all'},{'rock','has','not rock'}})
assert(not c['rock has rock'] and c['rock has crate']==1)
c=run({{'rock','has','all'},{'rock','has','not all'},{'rock','has','crate'}})
assert(c['rock has crate']==1 and not c['rock has avatar'])
print('PASS: original ALL multiplicity and right-NOT HAS suppression')
