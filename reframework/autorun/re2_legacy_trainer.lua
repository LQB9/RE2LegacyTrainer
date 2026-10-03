-- RE2 Legacy Trainer: all 26 functions from the original trainer.
-- Managed features use named TDB interfaces. Four native groups live in the helper DLL.
if reframework:get_game_name() ~= "re2" then return end
local VERSION="0.1.5"
local PROJECT_URL="https://github.com/LQB9/RE2LegacyTrainer"
local defs={
 {"无限生命","Infinte Health"},
 {"无消耗","Items Not Reduced"},
 {"一击即死","One Hit Kill"},
 {"暴君无法复活","Tyrant Can't Revive"},
 {"无后坐力","No Recoil"},
 {"超级精准度","Fast Weapon Accuracy"},
 {"包裹格数","Backpack Size"},
 {"可交互提示距离","Highilght Item Tip Distance"},
 {"游戏时间","Play Time"},
 {"存档次数","Save Counter"},
 {"开箱次数","Box Open Counter"},
 {"治疗次数","Recovery Item Used Counter"},
 {"走动步数","Step Counter"},
 {"移动速度","Move Speed"},
 {"瞬移&穿墙","Teleport & Through Wall"},
 {"视角距离","FOV Distance"},
 {"湿身效果","Wet Body"},
 {"极速开枪","No Firing Delay"},
 {"无敌","Invulnerable"},
 {"动态难度(分数)","Score"},
 {"真隐身模式","Zombies Don't Attack"},
 {"人物大小修改","Player Model Size"},
 {"免疫中毒","Immune Poisoning"},
 {"混合药草增益状态","Mixed Herbs Buffer"},
 {"艾达秒入侵","Ada Instant Hacking"},
 {"锁定倒计时","Freeze Countdown Timer"}}
local defaults={original_profile=1,all1=false,v7=20,v8=15,seconds9=0,v10=0,v11=0,v12=0,v13=0,v14=2,
 freeUD15=false,height_step15=.1,save15=0,load15=0,up15=0,down15=0,
 save_key15=0,save_mod15=0,load_key15=0,load_mod15=0,up_key15=0,up_mod15=0,down_key15=0,down_mod15=0,
 v16=1.3,h16=0,aimReset16=true,smooth16=true,change16=.2,v17=1,v20=12999,v22=1,vol22=false,english=false}
-- Original trainer's default assignment, verified against its IL and local .cfg:
-- LCtrl+N1..N0, LAlt+N1..N0, then LWin+N1..N6. Modifier bits retain L/R sides.
for i=1,26 do
 local digit=i%10;defaults["key"..i]=96+digit
 defaults["keymods"..i]=i<=10 and 4 or(i<=20 and 64 or 1)
 defaults["f"..i]=false
end
local cfg={};for k,v in pairs(defaults)do cfg[k]=v end
local font_ok,chinese_font=pcall(function()
 return imgui.load_font("re2_legacy_font.ttc",26,{0x20,0xff,0x3000,0x303f,0x4e00,0x9fff,0xff00,0xffef,0})
end)
if not font_ok then chinese_font=nil end
local function load_json(path)
 -- This installed REFramework logs an error for every missing json.load_file.
 -- fs.glob exists in older builds where the sandboxed io API is absent.
 local matches=fs.glob(path:gsub("%.","[.]"))
 if not matches or #matches==0 then return nil end
 return json.load_file(path)
end
local saved=load_json("re2_legacy_settings.json")
if type(saved)~="table"then saved=nil end
if type(saved)=="table"and saved.original_profile==1 then
 for k,v in pairs(defaults)do if type(saved[k])==type(v)then cfg[k]=saved[k]end end
end
-- Remember the user's feature switches as well as parameters and key bindings.
-- One-shot coordinate commands are never replayed after a reload.
cfg.height_step15=.1 -- Original hidden hchang; it is not an adjustable UI option.
for _,k in ipairs({"save15","load15","up15","down15"})do cfg[k]=0 end
local status={};for i=1,26 do status[i]={ready=true,hits=0,error=""}end
local player,player_hp,player_equipment,player_orderer
local native={};local frames=0;local journal={};local hooked={};local camera_height=0
-- Invalidate status left by a previous game process. The helper refreshes it each second.
json.dump_file("re2_legacy_native_status.json",{})
local prefix="app.ropeway."
local function label(cn,en)return cfg.english and en or cn end
local function fail(id,err)
 if status[id].error~=tostring(err)then log.warn("[RE2 Legacy] #"..id.." "..tostring(err))end
 status[id].error=tostring(err)
end
local function field(o,k)return o and o:get_field(k)end
local function set(o,k,v)if not o then error("object unavailable: "..k)end;o:set_field(k,v)end
local function call(o,m,...)return o and o:call(m,...)end
local function own(o,k,v,id)
 if not o then return end
 local key=tostring(o:get_address())..":"..k..":"..id
 if not journal[key]then journal[key]={object=o,name=k,value=field(o,k),id=id}end
 set(o,k,v)
end
local function restore(id)
 for key,item in pairs(journal)do if not id or item.id==id then
  pcall(set,item.object,item.name,item.value);journal[key]=nil
 end end
end
local function off(id)cfg["f"..id]=false;restore(id)end
local function native_config()
 local out={};for _,k in ipairs({"f8","v8","f14","v14","f15","freeUD15","height_step15","save15","load15","up15","down15","f22","v22","vol22"})do out[k]=cfg[k]end
 json.dump_file("re2_legacy_native.json",out)
end
local function save_settings()json.dump_file("re2_legacy_settings.json",cfg);native_config()end
local function enabled(id)return cfg["f"..id]end
local function obj(args)return sdk.to_managed_object(args[2])end
local function is_player(o)return o and player and o:get_address()==player:get_address()end
local function hit(id)status[id].hits=status[id].hits+1;status[id].error=""end
local function install(ids,type_name,method_name,pre,post)
 local td=sdk.find_type_definition(prefix..type_name);local method=td and td:get_method(method_name)
 if not method then for _,id in ipairs(ids)do status[id].ready=false;fail(id,"missing method "..type_name.."."..method_name)end;return end
 local address=tostring(method:get_function())
 if hooked[address]then for _,id in ipairs(ids)do status[id].ready=false;fail(id,"shared method address: "..method_name)end;return end
 hooked[address]=true
 local ok,err=pcall(function()sdk.hook(method,
  function(args)
   local success,result=pcall(pre,args,thread.get_hook_storage())
   if not success then for _,id in ipairs(ids)do if enabled(id)then fail(id,result)end end end
   return success and result or sdk.PreHookResult.CALL_ORIGINAL
  end,
  function(ret)
   if not post then return ret end
   local success,result=pcall(post,ret,thread.get_hook_storage())
   if not success then for _,id in ipairs(ids)do if enabled(id)then fail(id,result)end end;return ret end
   return result or ret
  end)end)
 if not ok then for _,id in ipairs(ids)do status[id].ready=false;fail(id,err)end end
end
install({1,3},"HitPointController","addDamage",function(args)
 -- Remembered one-hit-kill must not classify the player as an enemy during loading.
 if not player_hp then return end
 local hp=obj(args);local ours=hp and player_hp and hp:get_address()==player_hp:get_address()
 if enabled(19)and ours then args[3]=sdk.to_ptr(0);hit(19)
 elseif enabled(1)and(ours or cfg.all1)then args[3]=sdk.to_ptr(0);hit(1)
 elseif enabled(3)and hp and not ours then args[3]=sdk.to_ptr(1073741823);hit(3)end
end)
install({2},"inventory.Slot","set_Number",function(args)
 if not enabled(2)then return end
 local slot=obj(args);local stock=field(slot,"_Stock")
 if stock then
  local old=call(slot,"get_Number");local value=sdk.to_int64(args[3])
  if old and value<old then args[3]=sdk.to_ptr(old);hit(2)end
 end
end)
install({2},"inventory.Slot","reduce",function(args,s)
 s.reduced=nil
 if enabled(2)then
  local count=call(obj(args),"get_Number");local amount=sdk.to_int64(args[3])
  if count and count>0 and amount>0 then
   s.reduced=math.min(count,amount);hit(2);return sdk.PreHookResult.SKIP_ORIGINAL
  end
 end
end,function(ret,s)if s.reduced then return sdk.to_ptr(s.reduced)end;return ret end)
install({4},"enemy.em6200.Em6200Think","doSleep",function(args,s)
 s.skipped=enabled(4);if s.skipped then hit(4);return sdk.PreHookResult.SKIP_ORIGINAL end
end,function(ret,s)if s.skipped then return sdk.to_ptr(0)end;return ret end)
install({5},"camera.PlayerCameraController","updateRecoil",function()
 if enabled(5)then hit(5);return sdk.PreHookResult.SKIP_ORIGINAL end
end)
install({6},"survivor.Equipment","updateReticleFit",function(args,s)s.e=enabled(6)and obj(args)or nil end,
 function(ret,s)if s.e and player_equipment and s.e:get_address()==player_equipment:get_address()then
  set(s.e,"_ReticleFitPoint",100.0);set(s.e,"_IsReticleFit",true);hit(6)
 end;return ret end)
-- Suppress precisely the animation track count checked by the old firing-delay patch.
install({18},"survivor.SurvivorActionOrderer","updatePrecedeBit",function(args,s)
 s.layers=nil
 local orderer=obj(args)
 if enabled(18)and player_orderer and orderer:get_address()==player_orderer:get_address()then
  local handle=field(orderer,"<RejectPrecedeOrdersTrackHandle>k__BackingField")
  local layers=field(handle,"<LayerNos>k__BackingField")
  if layers then s.count=field(layers,"mCount");s.layers=layers;set(layers,"mCount",0);hit(18)end
 end
end,function(ret,s)if s.layers then set(s.layers,"mCount",s.count)end;return ret end)
install({17},"effect.script.PlRainEffect","MaterialUpdate",function(args,s)
 s.obj=nil
 if enabled(17)then
  local o=obj(args);s.obj=o;s.wet=field(o,"NowWetRate");s.rain=field(o,"NowRainRate");s.state=field(o,"MatState")
  set(o,"NowWetRate",cfg.v17);set(o,"NowRainRate",cfg.v17);set(o,"MatState",3);hit(17)
 end
end,function(ret,s)if s.obj then set(s.obj,"NowWetRate",s.wet);set(s.obj,"NowRainRate",s.rain);set(s.obj,"MatState",s.state)end;return ret end)
install({23},"survivor.SurvivorCondition","set_IsPoison",function(args)
 if enabled(23)and is_player(obj(args))then args[3]=sdk.to_ptr(0);hit(23)end
end)
install({25},"gimmick.action.GimmickWiringNodeBase","updateCountSub",function(args)
 if enabled(25)then local o=obj(args);set(o,"_MotorCount",field(o,"_CapacityValue"));hit(25)end
end)
install({26},"gui.CountDownBehavior","updateCountDown",function(args,s)
 s.o=enabled(26)and obj(args)or nil;if s.o then s.value=field(s.o,"<CurrentTimerFrame>k__BackingField")end
end,function(ret,s)if s.o then set(s.o,"<CurrentTimerFrame>k__BackingField",s.value);hit(26)end;return ret end)

-- Apply camera parameters before position calculation; restore shared resources afterward.
install({16},"camera.PlayerCameraController","onCameraUpdate",function(args,s)
 s.params={}
 if not enabled(16)or not player then return end
 local cam=obj(args);local kind=field(cam,"<NowKindType>k__BackingField")
 local aiming=type(kind)=="number"and kind~=0
 local target=cfg.aimReset16 and aiming and 0 or cfg.h16
 if cfg.smooth16 then
  camera_height=camera_height<target and math.min(target,camera_height+cfg.change16)or math.max(target,camera_height-cfg.change16)
 else camera_height=target end
 local interpolation=field(cam,"<Param>k__BackingField")
 local seen={}
 for _,key in ipairs({"<NextInfo>k__BackingField","<PrevInfo>k__BackingField"})do
  local info=field(interpolation,key);local transition=field(info,"_Param");local p=field(transition,"_Param")
  if p and not seen[p:get_address()]then
   seen[p:get_address()]=true
   local distance=field(p,"_GazeDistance");local offset=field(p,"_Offset")
   local original={x=offset.x,y=offset.y,z=offset.z}
   table.insert(s.params,{p=p,distance=distance,offset=original})
   offset.y=offset.y+camera_height;set(p,"_Offset",offset);set(p,"_GazeDistance",cfg.v16)
  end
 end
 hit(16)
end,function(ret,s)
 for _,entry in ipairs(s.params or{})do
  set(entry.p,"_GazeDistance",entry.distance)
  local v=field(entry.p,"_Offset");v.x=entry.offset.x;v.y=entry.offset.y;v.z=entry.offset.z;set(entry.p,"_Offset",v)
 end
 return ret
end)
local function singleton(n)return sdk.get_managed_singleton(prefix..n)end
-- Original counter patches run on their own game events, rather than altering
-- save/box/heal totals as soon as the checkbox is enabled.
install({10},"gamemastering.MainFlowManager","addSaveTimes",function(args,s)
 s.save_manager=enabled(10)and obj(args)or nil
end,function(ret,s)
 if s.save_manager and enabled(10)then set(field(s.save_manager,"gameHeaderSaveData"),"SaveTimes",cfg.v10);hit(10)end
 return ret
end)
install({11,12},"gamemastering.RecordManager","addRecordCount",function(args,s)
 s.record_counts={}
 if not enabled(11)and not enabled(12)then return end
 local data=field(obj(args),"gameSaveData")
 for _,entry in ipairs({{11,"OpenItemBox"},{12,"UseHealItem"}})do
  if enabled(entry[1])then s.record_counts[#s.record_counts+1]={id=entry[1],data=data,name=entry[2],before=field(data,entry[2])}end
 end
end,function(ret,s)
 for _,entry in ipairs(s.record_counts or{})do
  if enabled(entry.id)and field(entry.data,entry.name)~=entry.before then
   set(entry.data,entry.name,cfg["v"..entry.id]);hit(entry.id)
  end
 end
 return ret
end)
install({13},"PlayerManager","addPedometer",function(args,s)
 s.pedometer=enabled(13)and obj(args)or nil
end,function(ret,s)
 if s.pedometer and enabled(13)then set(s.pedometer,"<Pedometer>k__BackingField",cfg.v13);hit(13)end
 return ret
end)
local function frame_feature(id,fn)if enabled(id)then local ok,err=pcall(fn);if ok then hit(id)else fail(id,err)end end end
local function update()
 local pm=singleton("PlayerManager");local current=call(pm,"get_CurrentPlayerCondition")
 if player and(not current or current:get_address()~=player:get_address())then restore();camera_height=0 end
 player=current;player_hp=field(player,"<HitPointController>k__BackingField")
 player_equipment=field(player,"<Equipment>k__BackingField");player_orderer=field(player,"<ActionOrderer>k__BackingField")
 if not player then return end
 frame_feature(7,function()
  local inv=field(singleton("gamemastering.InventoryManager"),"<CurrentInventory>k__BackingField")
  if inv then own(inv,"_CurrentSlotSize",cfg.v7,7)else error("inventory unavailable")end
 end)
 frame_feature(9,function()
  local clock=singleton("GameClock");local data=field(clock,"_GameSaveData")
  set(data,"_GameElapsedTime",math.floor(cfg.seconds9*10000000))
  for _,k in ipairs({"_DemoSpendingTime","_InventorySpendingTime","_PauseSpendingTime"})do set(data,k,0)end
 end)
 frame_feature(19,function()own(player_hp,"<Invincible>k__BackingField",true,19)end)
 frame_feature(20,function()local rank=singleton("GameRankSystem");own(rank,"<IsRankPointFix>k__BackingField",true,20);set(rank,"<RankPoint>k__BackingField",cfg.v20)end)
 frame_feature(21,function()own(singleton("EnemyManager"),"_IsInvisible",true,21)end)
 frame_feature(23,function()if field(player,"_IsPoison")then call(player,"set_IsPoison",false)end end)
 frame_feature(24,function()set(player,"_DopingTimer",180.0)end)
end
re.on_pre_application_entry("UpdateScene",function()
 local ok,err=pcall(update);if not ok then log.warn("[RE2 Legacy] player update: "..tostring(err))end
end)
local function snapshot()
 local features={};for i,s in ipairs(status)do features[tostring(i)]={ready=s.ready,hits=s.hits,error=s.error,enabled=enabled(i)}end
 local state={version=VERSION,tdb=sdk.get_tdb_version(),player_ready=player~=nil,features=features,native=native}
 if player_hp then state.hp=field(player_hp,"<CurrentHitPoint>k__BackingField")or field(player_hp,"<CurrentHP>k__BackingField")end
 json.dump_file("re2_legacy_status.json",state)
end
local key_down={};local action_key_down={};local key_capture
local actions15={
 {"save15","save_key15","save_mod15","保存坐标","Save Location"},
 {"load15","load_key15","load_mod15","读取坐标","Load Location"},
 {"up15","up_key15","up_mod15","上升","Rise"},
 {"down15","down_key15","down_mod15","下降","Fall"}}
local function modifiers()
 local value=0
 for _,pair in ipairs({{91,1},{92,2},{162,4},{163,8},{160,16},{161,32},{164,64},{165,128}})do
  if reframework:is_key_down(pair[1])then value=value|pair[2]end
 end
 if value&12==0 and reframework:is_key_down(17)then value=value|4 end
 if value&48==0 and reframework:is_key_down(16)then value=value|16 end
 if value&192==0 and reframework:is_key_down(18)then value=value|64 end
 return value
end
local function shortcut_down(key_field,mods_field)
 local key=cfg[key_field]or 0
 return key>0 and key<=255 and reframework:is_key_down(key)and modifiers()==(cfg[mods_field]or 0)
end
local function begin_binding(key_field,mods_field,title)
 local held={};for key=8,255 do held[key]=reframework:is_key_down(key)end
 key_capture={key=key_field,mods=mods_field,title=title,held=held}
end
local function assign_binding(key,mods)
 local target=key_capture
 if key>0 then
  -- A chord has one action, so binding it here replaces an older duplicate.
  for i=1,26 do
   if "key"..i~=target.key and cfg["key"..i]==key and cfg["keymods"..i]==mods then cfg["key"..i]=0;cfg["keymods"..i]=0 end
  end
  for _,action in ipairs(actions15)do
   if action[2]~=target.key and cfg[action[2]]==key and cfg[action[3]]==mods then cfg[action[2]]=0;cfg[action[3]]=0 end
  end
 end
 cfg[target.key]=key;cfg[target.mods]=mods;key_capture=nil;save_settings()
end
local function capture_binding()
 for key=8,255 do
  local down=reframework:is_key_down(key)
  if down and not key_capture.held[key]then
   if key==27 then key_capture=nil;return end
   if key==8 then assign_binding(0,0);return end
   if key~=16 and key~=17 and key~=18 and key~=91 and key~=92 and not(key>=160 and key<=165)then
    assign_binding(key,modifiers());return
   end
  end
  key_capture.held[key]=down
 end
end
local initial_command=load_json("re2_legacy_commands.json")
local command_seq=type(initial_command)=="table"and tonumber(initial_command.seq)or 0
command_seq=command_seq or 0
re.on_frame(function()
 frames=frames+1
 if frames%15==0 then
  local command=load_json("re2_legacy_commands.json")
  if type(command)=="table"and type(command.seq)=="number"and command.seq>command_seq then
   command_seq=command.seq
   if type(command.values)=="table"then
    for k,v in pairs(command.values)do
     if cfg[k]~=nil and type(cfg[k])==type(v)then
      cfg[k]=v;local id=k:match("^f(%d+)$");if id and not v then restore(tonumber(id))end
     end
    end
    save_settings()
   end
  end
 end
 local was_capturing=key_capture~=nil
 if was_capturing then capture_binding()end
 for i=1,26 do
  local down=shortcut_down("key"..i,"keymods"..i)
  if not was_capturing and down and not key_down[i]and status[i].ready then
   cfg["f"..i]=not cfg["f"..i];if not enabled(i)then restore(i)end;save_settings()
  end
  key_down[i]=down
 end
 for index,action in ipairs(actions15)do
  local down=shortcut_down(action[2],action[3])
  if not was_capturing and down and not action_key_down[index]and enabled(15)and player and status[15].ready then
   cfg[action[1]]=cfg[action[1]]+1;save_settings()
  end
  action_key_down[index]=down
 end
 if frames%60==0 then
  native_config();native=load_json("re2_legacy_native_status.json")or{}
  for _,i in ipairs({8,14,15,22})do local s=native.features and native.features[tostring(i)]
   status[i].ready=s and s.ready or false;status[i].error=s and s.error or "native helper not loaded; restart the game"
  end
  if native.version and native.version<4 then status[15].ready=false;status[15].error="restart after installing the updated native helper"end
  snapshot()
 end
end)

local ui_open=true;local selected_feature=0;local ui_first_draw=true
local colors={muted=0xffaaaaaa,green=0xff91df91,blue=0xffff901e,warning=0xff78bcf0}
local function push_scrollbar_style()
 -- ImGui 1.90.1 indices, matching the installed REFramework's pinned dependency.
 -- Its Lua color binding accepts signed int; retain the packed ABGR bits.
 for _,entry in ipairs({{14,0xff252525},{15,0xff66c8ff},{16,0xff88ddff},{17,0xffa9ebff}})do
  imgui.push_style_color(entry[1],entry[2]-0x100000000)
 end
 imgui.push_style_var(18,18.0)
end
local function pop_scrollbar_style()imgui.pop_style_var(1);imgui.pop_style_color(4)end
local function muted(cn,en)imgui.text_colored(label(cn,en),colors.muted)end
local function text_wrap(text)
 local width=math.max(120,imgui.get_window_size().x-26);local line="";local used=0
 for _,code in utf8.codes(text)do
  local character=utf8.char(code);local advance=code>=0x3000 and 26 or 13
  if code==10 or used+advance>width then imgui.text(line);line="";used=0 end
  if code~=10 then line=line..character;used=used+advance end
 end
 if line~=""then imgui.text(line)end
end
local function toggle(id,caption)
 local changed,value=imgui.checkbox((caption or "").."##feature"..id,enabled(id))
 if changed then
  cfg["f"..id]=status[id].ready and value or false
  if not enabled(id)then restore(id)end;save_settings()
 end
 return changed
end
local function boolean(key,cn,en)
 local changed,value=imgui.checkbox(label(cn,en).."##"..key,cfg[key])
 if changed then cfg[key]=value;save_settings()end
end
local function number(key,cn,en,lo,hi,integer,step)
 text_wrap(label(cn,en));imgui.set_next_item_width(-1)
 local changed,value
 if integer and step then changed,value=imgui.slider_int("##"..key,cfg[key],lo,hi)
 elseif integer then changed,value=imgui.drag_int("##"..key,cfg[key],1,lo,hi)
 else changed,value=imgui.slider_float("##"..key,cfg[key],lo,hi,"%.2f")end
 if changed then
  value=math.max(lo,math.min(hi,value))
  if step and value<hi then value=lo+math.floor((value-lo)/step+.5)*step end
  cfg[key]=math.max(lo,math.min(hi,value));save_settings()
 end
 imgui.spacing()
end
local key_names={[8]="Back",[9]="Tab",[13]="Enter",[19]="Pause",[20]="CapsLock",[27]="Esc",[32]="Space",
 [33]="PageUp",[34]="PageDown",[35]="End",[36]="Home",[37]="Left",[38]="Up",[39]="Right",[40]="Down",
 [44]="PrintScreen",[45]="Insert",[46]="Delete",[106]="Multiply",[107]="Add",[109]="Subtract",[110]="Decimal",[111]="Divide",
 [144]="NumLock",[145]="ScrollLock",[186]=";",[187]="=",[188]=",",[189]="-",[190]=".",[191]="/",[192]="`",[219]="[",[220]="\\",[221]="]",[222]="'"}
local modifier_names={{1,"LWin"},{2,"RWin"},{4,"LCtrl"},{8,"RCtrl"},{16,"LShift"},{32,"RShift"},{64,"LAlt"},{128,"RAlt"}}
local function binding_text(key_field,mods_field)
 if key_capture and key_capture.key==key_field then return label("现在按下你的热键","Now, press your hotkey")end
 local key=cfg[key_field]or 0;if key==0 then return label("未设置","Not Set")end
 local text=key_names[key]
 if not text then
  if key>=112 and key<=135 then text="F"..(key-111)
  elseif key>=96 and key<=105 then text="N"..(key-96)
  elseif(key>=65 and key<=90)or(key>=48 and key<=57)then text=string.char(key)
  else text=string.format("VK %02X",key)end
 end
 local names={};for _,entry in ipairs(modifier_names)do if (cfg[mods_field]or 0)&entry[1]~=0 then names[#names+1]=entry[2]end end
 names[#names+1]=text;return table.concat(names,"+")
end
local function key_editor(key_field,mods_field,title)
 if imgui.begin_table("##binding_"..key_field,3,imgui.TableFlags.NoSavedSettings)then
  imgui.table_setup_column("key",imgui.ColumnFlags.WidthStretch,1)
  imgui.table_setup_column("change",imgui.ColumnFlags.WidthFixed,90)
  imgui.table_setup_column("clear",imgui.ColumnFlags.WidthFixed,74)
  imgui.table_next_row();imgui.table_set_column_index(0)
  local binding=binding_text(key_field,mods_field)
  if imgui.button(binding.."##bind_"..key_field,{-1,36})then begin_binding(key_field,mods_field,title)end
  if imgui.is_item_hovered()then imgui.set_tooltip(label("点击这里设置热键","Click Here Set Hotkey"))end
  imgui.table_set_column_index(1)
  if imgui.button(label("更改","Change").."##change_"..key_field,{-1,36})then begin_binding(key_field,mods_field,title)end
  imgui.table_set_column_index(2)
  if imgui.button(label("清除","Clear").."##clear_"..key_field,{-1,36})then
   cfg[key_field]=0;cfg[mods_field]=0;if key_capture and key_capture.key==key_field then key_capture=nil end;save_settings()
  end
  imgui.end_table()
 end
end
local function time_input()
 text_wrap(label("游戏时间","Play Time"))
 local hours=math.floor(cfg.seconds9/3600)%24;local minutes=math.floor(cfg.seconds9/60)%60;local seconds=cfg.seconds9%60
 local changed=false
 if imgui.begin_table("##time9",3,imgui.TableFlags.SizingStretchSame)then
  for index,entry in ipairs({{"时","H",hours,23},{"分","M",minutes,59},{"秒","S",seconds,59}})do
   if index==1 then imgui.table_next_row()end;imgui.table_set_column_index(index-1)
   imgui.text(label(entry[1],entry[2]));imgui.set_next_item_width(-1)
   local c,v=imgui.drag_int("##time9_"..index,entry[3],1,0,entry[4]);changed=changed or c
   if index==1 then hours=v elseif index==2 then minutes=v else seconds=v end
  end
  imgui.end_table()
 end
 if changed then cfg.seconds9=hours*3600+minutes*60+seconds;save_settings()end
end
local function parameters(i)
 if i==1 then boolean("all1","敌人也一样","Enemy Also Effective")
 elseif i==7 then number("v7","格子数","Grid Size",8,20,true,1)
 elseif i==8 then number("v8","距离","Distance",1,50,false,1)
 elseif i==9 then time_input()
 elseif i==10 then number("v10","存档后生效","Count (Effective After Saving Game)",0,2147483647,true)
 elseif i==11 then number("v11","开箱后生效","Count (Effective After Open Box)",0,2147483647,true)
 elseif i==12 then number("v12","治疗后生效","Count (Effective After Use Of Recovery Item)",0,2147483647,true)
 elseif i==13 then number("v13","走动步数","Count",0,2147483647,true)
 elseif i==14 then number("v14","移动倍数","Speed Multiple",.5,5,false,.1)
 elseif i==15 then
  boolean("freeUD15","随意上升/下降","Free Rise/Fall");imgui.spacing()
  for _,action in ipairs(actions15)do
   imgui.begin_disabled(not enabled(15)or not player or not status[15].ready)
   if imgui.button(label(action[4],action[5]).."##"..action[1],{-1,36})then cfg[action[1]]=cfg[action[1]]+1;native_config()end
   imgui.end_disabled();key_editor(action[2],action[3],label(action[4],action[5]));imgui.spacing()
  end
 elseif i==16 then
  number("v16","距离","Distance",0,20,false,.1);number("h16","高度","Height",-5,5,false,.01)
  boolean("aimReset16","瞄准时恢复高度","Restore Height When Aiming")
  boolean("smooth16","平滑镜头","Smooth Camera")
  number("change16","平滑增幅","Smooth Change",.05,.5,false,.01)
 elseif i==17 then number("v17","湿度","Effect",0,1,false,.1)
 elseif i==20 then number("v20","分数","Score",0,12999,false,100)
 elseif i==22 then
  number("v22","人物大小","Size",.1,5,false,.1)
  boolean("vol22","是否修改碰撞体积","Volume Calc")
 end
end
local function feature_list()
 if imgui.begin_table("##original_code_list",3,imgui.TableFlags.NoSavedSettings)then
  imgui.table_setup_column("enabled",imgui.ColumnFlags.WidthFixed,36)
  imgui.table_setup_column("hotkey",imgui.ColumnFlags.WidthFixed,166)
  imgui.table_setup_column("description",imgui.ColumnFlags.WidthStretch,1)
  imgui.table_next_row();imgui.table_set_column_index(1);imgui.text(label("热键","Hotkey"))
  imgui.table_set_column_index(2);imgui.text(label("功能","Description"))
  for i=1,26 do
   imgui.table_next_row();imgui.table_set_column_index(0)
   imgui.begin_disabled(not status[i].ready)
   if toggle(i)then selected_feature=i end
   imgui.end_disabled();imgui.table_set_column_index(1)
   if imgui.button(binding_text("key"..i,"keymods"..i).."##select_key"..i,{-1,36})then selected_feature=i end
   imgui.table_set_column_index(2)
   local title=label(defs[i][1],defs[i][2])
   if selected_feature==i then imgui.table_set_bg_color(1,0x38ff901e)end
   if imgui.button(title.."##select_feature"..i,{-1,36})then selected_feature=i end
  end
  imgui.end_table()
 end
end
local function option_panel()
 local i=selected_feature;if i<1 then return end
 local title=label(defs[i][1],defs[i][2]);imgui.text_colored(title,colors.blue)
 imgui.begin_disabled(not status[i].ready);toggle(i,label("开启","Enable"));imgui.end_disabled()
 key_editor("key"..i,"keymods"..i,title);imgui.spacing();imgui.separator();imgui.spacing()
 parameters(i)
 if i==21 then
  imgui.spacing();text_wrap(label("待测试","Pending gameplay test"))
 end
 if not status[i].ready then imgui.spacing();text_wrap(label("此功能暂不可用：","Unavailable: ")..status[i].error)end
end
local function reset_settings()
 for i=1,26 do off(i)end
 for key,value in pairs(defaults)do cfg[key]=value end
 key_capture=nil;save_settings()
end
re.on_draw_ui(function()
 if chinese_font then imgui.push_font(chinese_font)end
 if imgui.tree_node("RE2 Legacy Trainer / 原版修改器 (26)")then
  local changed;changed,ui_open=imgui.checkbox(label("显示修改器面板","Show trainer panel").."##panel_visible",ui_open)
  if imgui.tree_node(label("接口诊断","Interface diagnostics"))then
   for i,s in ipairs(status)do imgui.text(string.format("%02d %s  %s",i,s.ready and"ready"or"unavailable",s.error))end
   if native.saved_valid and native.saved and native.position then
    imgui.text("Saved XYZ: "..table.concat(native.saved,", "));imgui.text("Current XYZ: "..table.concat(native.position,", "))
   end
   imgui.tree_pop()
  end
  imgui.tree_pop()
 end
 if ui_open then
  if ui_first_draw then
   local display=imgui.get_display_size();local width=math.min(1180,display.x-48);local height=math.min(850,display.y-48)
   imgui.set_next_window_size({width,height},1);imgui.set_next_window_pos({(display.x-width)/2,(display.y-height)/2},1)
   ui_first_draw=false
  end
  ui_open=imgui.begin_window("BIOHAZARD RE2 "..label("修改器","Trainer").."###RE2LegacyPanel",ui_open)
  if ui_open then
   imgui.text("BIOHAZARD RE2");imgui.same_line();muted("RE2 Legacy Trainer v"..VERSION,"RE2 Legacy Trainer v"..VERSION)
   imgui.text_colored(label(player and"游戏正在运行中"or"等待进入游戏",player and"Game Is Running"or"Wait For Game Start"),player and colors.green or colors.warning)
   imgui.spacing()
   push_scrollbar_style()
   if imgui.begin_table("##original_trainer_layout",2,imgui.TableFlags.NoSavedSettings)then
    imgui.table_setup_column("features",imgui.ColumnFlags.WidthStretch,370)
    imgui.table_setup_column("options",imgui.ColumnFlags.WidthStretch,205)
    imgui.table_next_row();local window=imgui.get_window_size();local content_height=math.max(160,window.y-175-(key_capture and 36 or 0))
    imgui.table_set_column_index(0)
    local visible=imgui.begin_child_window("##original_features",{0,content_height},true)
    if visible then feature_list()end;imgui.end_child_window()
    imgui.table_set_column_index(1)
    visible=imgui.begin_child_window("##original_options",{0,content_height},true)
    if visible then option_panel()end;imgui.end_child_window();imgui.end_table()
   end
   pop_scrollbar_style()
   if imgui.button("CHS##language_chs",{70,36})then cfg.english=false;save_settings()end
   imgui.same_line();if imgui.button("ENG##language_eng",{70,36})then cfg.english=true;save_settings()end
   imgui.same_line();if imgui.button(label("恢复设置","RESET SETTING").."##restore_original",{200,36})then reset_settings()end
   imgui.same_line()
   if imgui.button("github.com/LQB9/RE2LegacyTrainer##github_project",{-1,36})then imgui.set_clipboard(PROJECT_URL)end
   if imgui.is_item_hovered()then imgui.set_tooltip(label("点击复制项目地址：","Click to copy project URL: ")..PROJECT_URL)end
   if key_capture then text_wrap(label("现在按下你的热键：","Now, press your hotkey: ")..key_capture.title)end
  end
  -- The installed binding returns the close button state; End is also needed on close.
  imgui.end_window()
 end
 if chinese_font then imgui.pop_font()end
end)
re.on_script_reset(function()
 -- Persist the selected switches before disabling effects for script teardown.
 json.dump_file("re2_legacy_settings.json",cfg)
 for i=1,26 do off(i)end;native_config()
end)
save_settings()
log.info("[RE2 Legacy] All 26 menu functions registered; saved switches and settings restored")
