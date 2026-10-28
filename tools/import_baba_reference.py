"""Regenerate embedded test layouts from an installed Baba Is You (no runtime dependency)."""
from pathlib import Path
import argparse, hashlib, re, struct, zlib

BEGIN = '    -- BEGIN OFFICIAL REFERENCE LAYOUTS\n'
END = '    -- END OFFICIAL REFERENCE LAYOUTS\n'

def generate(data):
    values = (data / 'values.lua').read_text(encoding='utf-8-sig')
    tiles = {}
    for m in re.finditer(r'\b(object\d+)\s*=\s*\{(.*?)\n\t\}', values, re.S):
        tile = re.search(r'tile\s*=\s*\{(\d+),\s*(\d+)\}', m[2])
        name = re.search(r'name\s*=\s*"(.*?)"', m[2])
        if tile and name:
            tiles[int(tile[1]) + 256 * int(tile[2])] = (m[1], name[1])
    out = [BEGIN, '''    local function official_world(width,height,entries)
        local world=RW_CreateSession().world
        world.width=width;world.height=height;world.entities={};world.next_entity_id=1
        world.language.nouns={AVATAR="avatar",ROCK="rock",FLAG="flag",WALL="wall",BELT="belt",GHOST="ghost",LAVA="lava",LEVEL={tag="level",block_type="level_block"}}
        for _,spec in ipairs(entries) do
            local id=world.next_entity_id
            if spec[1]:sub(1,5) == "text_" then
                world.entities[id]={id=id,kind="object",class="text",text={name=spec[1]:sub(6):upper()},
                    x=spec[2],y=spec[3],direction=spec[4]}
                world.next_entity_id=id+1
            else object(world,id,spec[1],spec[2],spec[3]);world.entities[id].direction=spec[4] end
        end
        local navigation_y=1
        for _,e in pairs(world.entities) do if e.y==1 and e.x<=2 then navigation_y=height end end
        for _,e in pairs(world.entities) do assert(not (e.y==navigation_y and e.x<=2),"reference navigation overlaps authored objects") end
        local id=world.next_entity_id
        object(world,id,"cursor",1,navigation_y);portal(world,id+1,2,navigation_y,"PARENT");object(world,id+2,"line",1,navigation_y)
        return world
    end
''']
    for index, stem in enumerate(('0level','1level','163level','302level')):
        path = data / 'Worlds' / 'baba' / (stem + '.l')
        raw = path.read_bytes()
        ld = path.with_suffix('.ld').read_text(encoding='utf-8-sig')
        overrides = dict(re.findall(r'^(object\d+)_name=(.*)',ld,re.M))
        at = raw.index(b'LAYR')
        width,height = struct.unpack_from('<II',raw,at+10)
        assert width > 2 and height > 2
        entries = []
        offset = 0
        while (offset := raw.find(b'MAIN', offset)) >= 0:
            size = struct.unpack_from('<I',raw,offset+4)[0]
            cells = zlib.decompress(raw[offset+8:offset+8+size])
            assert len(cells) == width*height*2
            at = offset+8+size
            assert raw[at:at+4] == b'DATA' and raw[at+4:at+9] == b'\x01\0\0\0\0'
            size = struct.unpack_from('<I',raw,at+9)[0]
            directions = zlib.decompress(raw[at+13:at+13+size])
            assert len(directions) == width*height
            for i,(tile,) in enumerate(struct.iter_unpack('<H',cells)):
                if tile in (0,65535): continue
                obj,name = tiles[tile]
                name = overrides.get(obj,name)
                if name in ('tile','grass'): continue
                name = name.replace('baba','avatar')
                assert name in ('avatar','rock','flag','wall','belt','ghost','lava') or name in {
                    'text_avatar','text_rock','text_flag','text_wall','text_belt','text_is','text_you','text_push','text_stop','text_win','text_word','text_not','text_and','text_defeat','text_shift','text_ghost','text_lava','text_more','text_near','text_text','text_level','text_empty'}
                x,y = i%width,i//width
                assert 0<x<width-1 and 0<y<height-1
                entries.append((name,x,y,('Right','Up','Left','Down')[directions[i]]))
            offset += 4
        title = re.search(r'^name=(.*)',ld,re.M)[1]
        out.append(f'    -- Original {stem}: {title}; .l SHA256 {hashlib.sha256(raw).hexdigest()}\n')
        out.append(f'    definitions["reference.{index}"]={{id="reference.{index}",initial_world=official_world({width-2},{height-2},{{\n')
        for name,x,y,direction in entries:
            out.append(f'        {{"{name}",{x},{y},"{direction}"}},\n')
        out.append('    })}\n')
    out.append('''    local reference_map=RW_CreateSession().world
    reference_map.entities={};reference_map.next_entity_id=1
    object(reference_map,1,"cursor",2,2)
    portal(reference_map,2,3,2,"BIY","reference.0")
    portal(reference_map,3,4,2,"WHERE","reference.1")
    portal(reference_map,4,1,2,"PARENT")
    portal(reference_map,9,5,2,"AUTO","reference.2")
    object(reference_map,10,"line",5,2)
    portal(reference_map,11,6,2,"TRAP","reference.3")
    object(reference_map,12,"line",6,2)
    portal(reference_map,13,7,2,"MOTION","navigation.motion")
    object(reference_map,14,"line",7,2)
    for x=1,4 do object(reference_map,4+x,"line",x,2) end
    definitions["navigation.reference"]={id="navigation.reference",initial_world=reference_map}
    portal(root,64,12,2,"REF","navigation.reference")
    object(root,65,"line",12,2)
    for x=8,11 do object(root,58+x,"line",x,2) end
''')
    out.append(END)
    return ''.join(out)

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--data',type=Path,default=Path('C:/Program Files (x86)/Steam/steamapps/common/Baba Is You/Data'))
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    path=Path('external_lua_file/world.lua');source=path.read_text(encoding='utf-8')
    generated=generate(args.data)
    if BEGIN in source:
        first=source.index(BEGIN);last=source.index(END,first)+len(END)
        updated=source[:first]+generated+source[last:]
    else:
        marker='    -- WIN is authored visibly in these two victory fixtures, never a Flag default.'
        assert marker in source
        updated=source.replace(marker,generated+marker)
    if args.check:
        assert source==updated, 'Embedded reference layouts differ from installed originals'
        print('PASS: embedded reference layouts match original MAIN/DATA coordinates, directions and hashes')
    else:
        path.write_text(updated,encoding='utf-8')
