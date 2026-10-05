-- RE2 Legacy Trainer: original 26 functions plus aim teleport and enemy freeze.
-- Managed features use named TDB interfaces. Four native groups live in the helper DLL.
if reframework:get_game_name() ~= "re2" then return end
local VERSION="0.1.6"
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
 {"锁定倒计时","Freeze Countdown Timer"},
 {"飞雷神","Flying Thunder God"},
 {"敌人冻结","Freeze Enemies"}}
local FEATURE_COUNT=#defs
local feature_order={}
for i=1,15 do feature_order[#feature_order+1]=i end
feature_order[#feature_order+1]=27;feature_order[#feature_order+1]=28
for i=16,26 do feature_order[#feature_order+1]=i end
local defaults={original_profile=1,feature_keys_profile=1,all1=false,v7=20,v8=15,seconds9=0,v10=0,v11=0,v12=0,v13=0,v14=2,
 freeUD15=false,height_step15=.1,save15=0,load15=0,up15=0,down15=0,
 save_key15=0,save_mod15=0,load_key15=0,load_mod15=0,up_key15=0,up_mod15=0,down_key15=0,down_mod15=0,
 v16=1.3,h16=0,aimReset16=true,smooth16=true,change16=.2,v17=1,v20=12999,v22=1,vol22=false,english=false,
 interp27=true,aim_key27=0,aim_mod27=0,back_key27=0,back_mod27=0,
 aim_device27=1,aim_mouse27=4,aim_double27=true,back_device27=1,back_mouse27=5,
 freeze_device28=1,freeze_mouse28=1}
-- Feature toggle hotkeys start unbound; action bindings are separate.
for i=1,FEATURE_COUNT do defaults["key"..i]=0;defaults["keymods"..i]=0;defaults["f"..i]=false end
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
 -- Clear old toggle assignments once, preserving switches, parameters and actions.
 -- Bindings chosen after this migration survive later script/game restarts.
 if saved.feature_keys_profile~=1 then
  for i=1,FEATURE_COUNT do cfg["key"..i]=0;cfg["keymods"..i]=0 end
 end
end
-- Remember the user's feature switches as well as parameters and key bindings.
-- One-shot coordinate commands are never replayed after a reload.
cfg.height_step15=.1 -- Original hidden hchang; it is not an adjustable UI option.
for _,k in ipairs({"save15","load15","up15","down15"})do cfg[k]=0 end
local status={};for i=1,FEATURE_COUNT do status[i]={ready=true,hits=0,error=""}end
status[27].ready=false
local player,player_hp,player_equipment,player_orderer
local native={};local frames=0;local journal={};local hooked={};local camera_height=0
local frozen={};local aim_point,aim_time,aim_player
local stealth_body;local stealth_actions={}
local stealth_stats={enemies=0,lost_targets=0,blocked_find=0,blocked_attention=0,blocked_hate=0,blocked_actions=0}
local mouse_clicks={};local mouse_input={ready=false};local mouse_last_up=0
local flight_command={fly27_seq=0,fly27_kind=0,fly27_x=0,fly27_y=0,fly27_z=0}
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
 if not id or id==21 then stealth_body=nil;stealth_actions={};stealth_stats.enemies=0 end
 for key,item in pairs(journal)do if not id or item.id==id then
  pcall(set,item.object,item.name,item.value);journal[key]=nil
 end end
 if not id or id==28 then
  for key,item in pairs(frozen)do pcall(call,item.object,"set_TimeScale",item.scale);frozen[key]=nil end
 end
 if not id or id==27 then aim_point=nil;aim_player=nil;mouse_clicks={};flight_command.fly27_kind=0;flight_command.fly27_interp=nil;flight_command.fly27_seq=flight_command.fly27_seq+1 end
end
local function off(id)cfg["f"..id]=false;restore(id)end
local function native_config()
 local out={};for _,k in ipairs({"f8","v8","f14","v14","f15","freeUD15","height_step15","save15","load15","up15","down15","f22","v22","vol22"})do out[k]=cfg[k]end
 out.f27=cfg.f27;out.fly27_interp=cfg.interp27;for k,v in pairs(flight_command)do out[k]=v end
 json.dump_file("re2_legacy_native.json",out)
end
local function save_settings()mouse_clicks={};json.dump_file("re2_legacy_settings.json",cfg);native_config()end
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
local function safe_call(o,m,...)
 if not o then return nil end
 local ok,value=pcall(call,o,m,...);if ok then return value end
 return nil
end
local function vector(v)
 if not v then return nil end
 -- RE2 hit-position getters return Nullable<via.vec3>, not a plain Vector3f.
 local ok,has=pcall(function()return v:get_field("_HasValue")end)
 if ok and has~=nil then
  if has~=true then return nil end
  local value_ok,value=pcall(function()return v:get_field("_Value")end)
  if not value_ok or not value then return nil end
  v=value
 end
 local out={x=v.x,y=v.y,z=v.z}
 for _,k in ipairs({"x","y","z"})do local n=out[k];if type(n)~="number"or n~=n or math.abs(n)>100000 then return nil end end
 return out
end
local function frozen_count()local n=0;for _ in pairs(frozen)do n=n+1 end;return n end
local function in_event()
 local ok,event=pcall(field,player,"<IsEvent>k__BackingField");return ok and event==true
end
local function same_object(a,b)return a and b and a:get_address()==b:get_address()end
local function stealth_active()return enabled(21)and player and stealth_body and not in_event()end
local function lose_player_target(hate)
 if not hate or not stealth_active()then return end
 local seen={}
 local function lose(info)
  if not info or not same_object(safe_call(info,"get_TargetGameObject"),stealth_body)then return end
  local key=tostring(info:get_address());if seen[key]then return end;seen[key]=true
  if safe_call(info,"get_FindState")~=0 then
   -- Use the game's loss transition; never restore stale aggro when stealth ends.
   call(info,"lose");stealth_stats.lost_targets=stealth_stats.lost_targets+1
  end
 end
 lose(safe_call(hate,"get_CurrentTarget"))
 local list=safe_call(hate,"get_HateTargetList")
 if list then for i=0,math.min(call(list,"get_Count"),512)-1 do lose(call(list,"get_Item",i))end end
end
for _,name in ipairs({"find","attention","addHate"})do
 install({21},"EnemyHateController",name,function(args)
  if not stealth_active()then return end
  local target=sdk.to_managed_object(args[3])
  local source=name=="attention"and sdk.to_managed_object(args[4])or nil
  if same_object(target,stealth_body)or same_object(source,stealth_body)then
   local counter=name=="addHate"and"blocked_hate"or"blocked_"..name
   stealth_stats[counter]=stealth_stats[counter]+1;hit(21)
   return sdk.PreHookResult.SKIP_ORIGINAL
  end
 end)
end
install({21},"EnemyHateController","updateCurrentTarget",function(args)
 -- This runs after queued sensor/damage requests and before the AI selects a target.
 lose_player_target(obj(args))
end)
install({21},"ActionTargetController","setTargetObject",function(args)
 if not stealth_active()then return end
 local action=obj(args)
 if action and stealth_actions[tostring(action:get_address())]and same_object(sdk.to_managed_object(args[3]),stealth_body)then
  -- The original EXE nulls the target argument. Limit that behavior to enemy AI.
  args[3]=sdk.to_ptr(0);stealth_stats.blocked_actions=stealth_stats.blocked_actions+1;hit(21)
 end
end)
local function update_invisibility()
 if in_event()then restore(21);return end
 stealth_body=call(player,"get_GameObject")
 if not stealth_body then error("player game object unavailable")end
 local manager=singleton("EnemyManager");own(manager,"_IsInvisible",true,21)
 local list=call(manager,"get_EnemyList");if not list then error("enemy list unavailable")end
 local actions={};stealth_stats.enemies=0
 for i=0,math.min(call(list,"get_Count"),512)-1 do
  local controller=safe_call(call(list,"get_Item",i),"get_Controller")
  if controller and not same_object(safe_call(controller,"get_GameObject"),stealth_body)then
   stealth_stats.enemies=stealth_stats.enemies+1
   lose_player_target(safe_call(controller,"get_HateController"))
   local action=safe_call(controller,"get_ActionTarget")
   if action then
    actions[tostring(action:get_address())]=true
    if same_object(safe_call(action,"get_TargetObject"),stealth_body)and not call(action,"get_TargetLocked")then call(action,"clearTarget")end
   end
  end
 end
 stealth_actions=actions
end
local function update_extensions()
 if in_event()then restore(28);aim_point=nil;return end
 if enabled(27)then
  local camera=singleton("camera.CameraSystem")
  if safe_call(camera,"get_IsHoldWeaponCamera")then
   local point
   if safe_call(camera,"get_IsHitViewAim")then point=vector(safe_call(camera,"get_HitViewAimPosition"))end
   -- RE2 separates terrain and character rays; aiming at a wall uses terrain.
   if not point and safe_call(camera,"get_IsHitViewTerrain")then point=vector(safe_call(camera,"get_HitViewTerrainPosition"))end
   if point then aim_point=point;aim_time=os.time();aim_player=player:get_address()end
  end
 end
 if not enabled(28)then return end
 local ok,err=pcall(function()
  local manager=singleton("EnemyManager");local list=call(manager,"get_EnemyList")
  if not list then error("enemy list unavailable")end
  local count=call(list,"get_Count");local player_body=safe_call(player,"get_GameObject")
  local seen={}
  for index=0,math.min(count,512)-1 do
   local entry=call(list,"get_Item",index);local body=safe_call(entry,"get_GameObject")or safe_call(entry,"get_ContextGameObject")
   if body and(not player_body or body:get_address()~=player_body:get_address())then
    local key=tostring(body:get_address());seen[key]=true
    if not frozen[key]then
     local scale=call(body,"get_TimeScale")
     if type(scale)=="number"and scale==scale then frozen[key]={object=body,scale=scale}end
    end
    if frozen[key]then call(body,"set_TimeScale",0)end
   end
  end
  for key,item in pairs(frozen)do if not seen[key]then pcall(call,item.object,"set_TimeScale",item.scale);frozen[key]=nil end end
 end)
 if ok then hit(28)else fail(28,err);restore(28)end
end
local function request_flight(action,direct)
 if not enabled(27)or not player or in_event()or not status[27].ready then return false end
 local latest=load_json("re2_legacy_native_status.json");if latest and latest.version==5 then native=latest end
 local target,kind
 if action=="back"then
  if not(native.flight and native.flight.saved_valid)then fail(27,"return point unavailable");return false end
  kind=2
 elseif action=="aim"then
  if aim_point and aim_player==player:get_address()and os.time()-(aim_time or 0)<=10 then
   -- RE2 uses the recorded hit height directly; the RE4 +1 meter lift caused an offset.
   target={x=aim_point.x,y=aim_point.y,z=aim_point.z};kind=1;aim_point=nil
  elseif not direct and native.flight and native.flight.active then kind=0
  else fail(27,"aim at a surface first (target expires in 10 seconds)");return false end
 else return false end
 flight_command.fly27_seq=flight_command.fly27_seq+1;flight_command.fly27_kind=kind
 flight_command.fly27_interp=not direct and cfg.interp27
 if target then flight_command.fly27_x=target.x;flight_command.fly27_y=target.y;flight_command.fly27_z=target.z end
 hit(27);native_config();return true
end

local function frame_feature(id,fn)if enabled(id)then local ok,err=pcall(fn);if ok then hit(id)else fail(id,err)end end end
local function update()
 local pm=singleton("PlayerManager");local current=call(pm,"get_CurrentPlayerCondition")
 if player and(not current or current:get_address()~=player:get_address())then restore();camera_height=0 end
 player=current;player_hp=field(player,"<HitPointController>k__BackingField")
 player_equipment=field(player,"<Equipment>k__BackingField");player_orderer=field(player,"<ActionOrderer>k__BackingField")
 if not player then restore(28);aim_point=nil;return end
 update_extensions()
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
 frame_feature(21,update_invisibility)
 frame_feature(23,function()if field(player,"_IsPoison")then call(player,"set_IsPoison",false)end end)
 frame_feature(24,function()set(player,"_DopingTimer",180.0)end)
end
re.on_pre_application_entry("UpdateScene",function()
 local ok,err=pcall(update);if not ok then log.warn("[RE2 Legacy] player update: "..tostring(err))end
end)
local function snapshot()
 local features={};for i,s in ipairs(status)do features[tostring(i)]={ready=s.ready,hits=s.hits,error=s.error,enabled=enabled(i)}end
 local state={extensions={aim=aim_point,aim_time=aim_time,frozen_count=frozen_count(),mouse=mouse_input},invisibility=stealth_stats,version=VERSION,tdb=sdk.get_tdb_version(),player_ready=player~=nil,features=features,native=native}
 if player_hp then state.hp=field(player_hp,"<CurrentHitPoint>k__BackingField")or field(player_hp,"<CurrentHP>k__BackingField")end
 json.dump_file("re2_legacy_status.json",state)
end
local key_down={};local action_key_down={};local key_capture
local actions15={
 {"save15","save_key15","save_mod15","保存坐标","Save Location"},
 {"load15","load_key15","load_mod15","读取坐标","Load Location"},
 {"up15","up_key15","up_mod15","上升","Rise"},
 {"down15","down_key15","down_mod15","下降","Fall"}}
local actions27={
 {"aim","aim_key27","aim_mod27","传送到瞄准点 / 停止","Teleport to aim / Stop"},
 {"back","back_key27","back_mod27","返回出发点","Return to origin"}}
local action27_down={}
local mouse_codes={0,1,2,4,32,64}
local mouse_bindings={{"aim_device27","aim_mouse27"},{"back_device27","back_mouse27"},{"freeze_device28","freeze_mouse28"}}
local mouse_device,tick_method
local function read_mouse()
 local ok,up,down,tick=pcall(function()
  if not mouse_device then
   local hid=sdk.get_native_singleton("via.hid.Mouse");local td=sdk.find_type_definition("via.hid.Mouse")
   if not hid or not td then error("mouse device unavailable")end
   mouse_device=sdk.call_native_func(hid,td,"get_Device")
  end
  if not tick_method then local td=sdk.find_type_definition("System.Environment");tick_method=td and td:get_method("get_TickCount")end
  if not mouse_device or not tick_method then error("mouse or monotonic clock unavailable")end
  return call(mouse_device,"get_ButtonUp"),call(mouse_device,"get_ButtonDown"),tick_method:call(nil)
 end)
 if not ok or type(up)~="number"or type(down)~="number"or type(tick)~="number"then
  mouse_input.ready=false;mouse_input.error=tostring(up);mouse_device=nil;mouse_clicks={};return nil
 end
 mouse_input.ready=true;mouse_input.error=nil;mouse_input.up=up;mouse_input.down=down;mouse_input.tick=tick
 return up,down,tick
end
local function mouse_actions(blocked)
 local any=cfg.freeze_device28==2;for _,a in ipairs(actions27)do if cfg[a[1].."_device27"]==2 then any=true end end
 if not any then mouse_clicks={};return end
 local up,down,now=read_mouse();if not up then return end
 if blocked or not player or in_event()then mouse_clicks={};mouse_last_up=up;return end
 local freeze_code=cfg.freeze_device28==2 and(mouse_codes[cfg.freeze_mouse28]or 0)or 0
 if status[28].ready and freeze_code>0 and up&freeze_code~=0 and(mouse_last_up&freeze_code==0 or down&freeze_code~=0)then
  cfg.f28=not cfg.f28;if not cfg.f28 then restore(28)end;save_settings()
  mouse_input.last_action="freeze";mouse_input.last_trigger="single";mouse_input.sequence=nil;mouse_input.freeze_enabled=cfg.f28
 end
 if enabled(27)and status[27].ready then for _,a in ipairs(actions27)do
  local name=a[1];local code=cfg[name.."_device27"]==2 and(mouse_codes[cfg[name.."_mouse27"]]or 0)or 0
  -- Engine button-up flags match the RE4 reference. Guard repeated flags across frames.
  if code>0 and up&code~=0 and(mouse_last_up&code==0 or down&code~=0)then
   if name=="aim"and cfg.aim_double27 then
    local previous=mouse_clicks[name]
    if previous and(now-previous)%4294967296<=500 then
     mouse_clicks[name]=nil
     if request_flight(name,true)then mouse_input.last_action=name;mouse_input.last_trigger="double";mouse_input.sequence=flight_command.fly27_seq end
    else mouse_clicks[name]=now end
   elseif request_flight(name)then mouse_input.last_action=name;mouse_input.last_trigger="single";mouse_input.sequence=flight_command.fly27_seq end
  end
 end else mouse_clicks={}end
 mouse_last_up=up
end
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
  for i=1,FEATURE_COUNT do
   if "key"..i~=target.key and cfg["key"..i]==key and cfg["keymods"..i]==mods then cfg["key"..i]=0;cfg["keymods"..i]=0 end
  end
  for _,actions in ipairs({actions15,actions27})do for _,action in ipairs(actions)do
   if action[2]~=target.key and cfg[action[2]]==key and cfg[action[3]]==mods then cfg[action[2]]=0;cfg[action[3]]=0 end
  end
 end end
 cfg[target.key]=key;cfg[target.mods]=mods;key_capture=nil;save_settings()
end
local function capture_binding()
 for key=8,255 do
  local down=reframework:is_key_down(key)
  if down and not key_capture.held[key]then
   if key==27 then key_capture=nil;return end
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
 for i=1,FEATURE_COUNT do
  local down=(i~=28 or cfg.freeze_device28==1)and shortcut_down("key"..i,"keymods"..i)
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
 for index,action in ipairs(actions27)do
  local down=cfg[action[1].."_device27"]==1 and shortcut_down(action[2],action[3])
  if not was_capturing and down and not action27_down[index]then request_flight(action[1])end
  action27_down[index]=down
 end
 mouse_actions(was_capturing or reframework:is_drawing_ui())
 if frames%60==0 then
  native_config();native=load_json("re2_legacy_native_status.json")or{}
  for _,i in ipairs({8,14,15,22,27})do local s=native.features and native.features[tostring(i)]
   status[i].ready=s and s.ready or false;status[i].error=s and s.error or "native helper not loaded; restart the game"
  end
  if native.version and native.version<4 then status[15].ready=false;status[15].error="restart after installing the updated native helper"end
  if not native.version or native.version<5 then status[27].ready=false;status[27].error="restart after installing the 0.1.6 native helper"end
  snapshot()
 end
end)

local ui_open=true;local selected_feature=0;local ui_first_draw=true
local colors={muted=0xffaaaaaa,green=0xff91df91,blue=0xffff901e,warning=0xff78bcf0}
local function push_scrollbar_style()
 -- ImGui 1.90.1 indices, matching the installed REFramework's pinned dependency.
 -- Its Lua color binding accepts signed int; retain the packed ABGR bits.
 for _,entry in ipairs({{14,0xff252525},{15,0xff666666},{16,0xff888888},{17,0xffaaaaaa}})do
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
local key_names={[8]="Backspace",[9]="Tab",[13]="Enter",[19]="Pause",[20]="CapsLock",[27]="Esc",[32]="Space",
 [33]="PageUp",[34]="PageDown",[35]="End",[36]="Home",[37]="Left",[38]="Up",[39]="Right",[40]="Down",
 [44]="PrintScreen",[45]="Insert",[46]="Delete",[106]="Multiply",[107]="Add",[109]="Subtract",[110]="Decimal",[111]="Divide",
 [144]="NumLock",[145]="ScrollLock",[186]=";",[187]="=",[188]=",",[189]="-",[190]=".",[191]="/",[192]="`",[219]="[",[220]="\\",[221]="]",[222]="'"}
local modifier_names={{1,"LWin"},{2,"RWin"},{4,"LCtrl"},{8,"RCtrl"},{16,"LShift"},{32,"RShift"},{64,"LAlt"},{128,"RAlt"}}
local function binding_text(key_field,mods_field)
 if key_capture and key_capture.key==key_field then return label("现在按下你的热键","Now, press your hotkey")end
 local key=cfg[key_field]or 0;if key==0 then return label("未设置","Not Set")end
 local text=key==8 and label("退格键","Backspace")or key_names[key]
 if not text then
  if key>=112 and key<=135 then text="F"..(key-111)
  elseif key>=96 and key<=105 then text="N"..(key-96)
  elseif(key>=65 and key<=90)or(key>=48 and key<=57)then text=string.char(key)
  else text=string.format("VK %02X",key)end
 end
 local names={};for _,entry in ipairs(modifier_names)do if (cfg[mods_field]or 0)&entry[1]~=0 then names[#names+1]=entry[2]end end
 names[#names+1]=text;return table.concat(names,"+")
end
local function clear_binding(key_field,mods_field)
 cfg[key_field]=0;cfg[mods_field]=0;if key_capture and key_capture.key==key_field then key_capture=nil end;save_settings()
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
   clear_binding(key_field,mods_field)
  end
  imgui.end_table()
 end
end
local function input_binding_editor(action,feature_id)
 feature_id=feature_id or 27
 local name=action[1];local device_field=name.."_device"..feature_id;local mouse_field=name.."_mouse"..feature_id
 local function unique_mouse()
  if cfg[device_field]==2 and cfg[mouse_field]>1 then for _,other in ipairs(mouse_bindings)do
   if other[1]~=device_field and cfg[other[1]]==2 and cfg[other[2]]==cfg[mouse_field]then cfg[other[2]]=1 end
  end end
 end
 if imgui.begin_table("##flight_input_"..name,2,imgui.TableFlags.NoSavedSettings)then
  imgui.table_setup_column("device",imgui.ColumnFlags.WidthFixed,150)
  imgui.table_setup_column("button",imgui.ColumnFlags.WidthStretch,1)
  imgui.table_next_row();imgui.table_set_column_index(0);imgui.text(label("输入方式","Input"))
  imgui.table_set_column_index(1);imgui.text(label("对应按键","Binding"))
  imgui.table_next_row();imgui.table_set_column_index(0);imgui.set_next_item_width(-1)
  local changed,value=imgui.combo("##"..device_field,cfg[device_field],cfg.english and{"Keyboard","Mouse"}or{"键盘","鼠标"})
  if changed then cfg[device_field]=value;unique_mouse();if key_capture and key_capture.key==action[2]then key_capture=nil end;save_settings()end
  imgui.table_set_column_index(1);imgui.set_next_item_width(-1)
  if cfg[device_field]==1 then
   if imgui.begin_table("##flight_key_"..name,2,imgui.TableFlags.NoSavedSettings)then
    imgui.table_setup_column("key",imgui.ColumnFlags.WidthStretch,1)
    imgui.table_setup_column("clear",imgui.ColumnFlags.WidthFixed,80)
    imgui.table_next_row();imgui.table_set_column_index(0)
    if imgui.button(binding_text(action[2],action[3]).."##bind_"..action[2],{-1,36})then begin_binding(action[2],action[3],label(action[4],action[5]))end
    if imgui.is_item_hovered()then imgui.set_tooltip(label("点击后按新热键；退格键可绑定，Esc 取消。","Click, then press a hotkey; Backspace can be bound, Esc cancels."))end
    imgui.table_set_column_index(1)
    if imgui.button(label("清除","Clear").."##clear_"..action[2],{-1,36})then clear_binding(action[2],action[3])end
    imgui.end_table()
   end
  else
   changed,value=imgui.combo("##"..mouse_field,cfg[mouse_field],cfg.english and{"Not Set","Left","Right","Middle","Back","Forward"}or{"未设置","左键","右键","中键","后退侧键","前进侧键"})
   if changed then cfg[mouse_field]=value;unique_mouse();save_settings()end
  end
  imgui.end_table()
 end
end
local function freeze_binding_text()
 if cfg.freeze_device28~=2 then return binding_text("key28","keymods28")end
 return (cfg.english and{"Not Set","Mouse L","Mouse R","Mouse M","Mouse Back","Mouse Fwd"}or{"未设置","左键","右键","中键","后退侧键","前进侧键"})[cfg.freeze_mouse28]or label("未设置","Not Set")
end
local function flight_action_label(index)
 return label(({"瞄准传送","返回出发点"})[index],({"Aim teleport","Return to origin"})[index])
end
local function flight_binding_text(action)
 if cfg[action[1].."_device27"]~=2 then return binding_text(action[2],action[3])end
 local index=cfg[action[1].."_mouse27"]
 local name=(cfg.english and{"Not Set","Mouse L","Mouse R","Mouse M","Mouse Back","Mouse Fwd"}or{"未设置","左键","右键","中键","后退侧键","前进侧键"})[index]or label("未设置","Not Set")
 if index>1 and action[1]=="aim"and cfg.aim_double27 then name=name.." ×2"end
 return name
end
local function flight_actions()
 local target_valid=aim_point and os.time()-(aim_time or 0)<=10
 text_wrap(label(target_valid and"瞄准点：已记录（10 秒内有效）"or"瞄准点：持枪瞄准以记录",target_valid and"Target: recorded (valid for 10 seconds)"or"Target: aim a weapon to record"))
 text_wrap(label(native.flight and native.flight.saved_valid and"返回点：已记录"or"返回点：传送后自动记录",native.flight and native.flight.saved_valid and"Origin: saved"or"Origin: saved automatically on teleport"))
 for index,action in ipairs(actions27)do
  imgui.spacing();imgui.separator();imgui.spacing()
  imgui.text_colored(flight_action_label(index),colors.blue)
  input_binding_editor(action)
  local direct=action[1]=="aim"and cfg.aim_device27==2 and cfg.aim_double27
  if action[1]=="aim"then
   if cfg.aim_device27==2 then
    boolean("aim_double27","连按两次直接传送","Double-click for instant teleport")
    direct=cfg.aim_double27
    if imgui.is_item_hovered()then imgui.set_tooltip(label("0.5 秒内按下并松开两次，第二次直接到达。","Press and release twice within 0.5 seconds; the second release teleports instantly."))end
   end
   if not direct then boolean("interp27","平滑传送","Interpolate teleport")end
  end
  local available=action[1]=="aim"and(target_valid or native.flight and native.flight.active)or action[1]=="back"and native.flight and native.flight.saved_valid
  imgui.begin_disabled(not enabled(27)or not player or not status[27].ready or not available)
  if imgui.button(flight_action_label(index).." · "..flight_binding_text(action).."##flight_"..action[1],{-1,40})then request_flight(action[1],direct)end
  imgui.end_disabled()
 end
 imgui.spacing();text_wrap(label("关闭菜单后使用按键。","Use bindings with the menu closed."))
 if mouse_input.error then text_wrap(label("鼠标接口：","Mouse interface: ")..mouse_input.error)end
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
 elseif i==27 then
  flight_actions()
 elseif i==28 then text_wrap(label("冻结当前场景敌人；关闭后恢复原时间倍率。","Freeze scene enemies; restore their previous time scale when disabled."))
  text_wrap(label("关闭菜单，按一次切换冻结／恢复。","Close the menu; press once to toggle freeze / restore."))
  text_wrap(label("已冻结：","Frozen: ")..frozen_count())
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
  for _,i in ipairs(feature_order)do
   imgui.table_next_row();imgui.table_set_column_index(0)
   imgui.begin_disabled(not status[i].ready)
   if toggle(i)then selected_feature=i end
   imgui.end_disabled();imgui.table_set_column_index(1)
   if imgui.button((i==28 and freeze_binding_text()or binding_text("key"..i,"keymods"..i)).."##select_key"..i,{-1,36})then selected_feature=i end
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
 if i==28 then
  input_binding_editor({"freeze","key28","keymods28",defs[28][1],defs[28][2]},28)
 else
  if i>=27 then text_wrap(label("功能开关热键","Feature toggle hotkey"))end
  key_editor("key"..i,"keymods"..i,title)
 end
 imgui.spacing();imgui.separator();imgui.spacing()
 parameters(i)
 if i==21 then
  imgui.spacing();text_wrap(label("待测试","Pending gameplay test"))
 end
 if not status[i].ready then imgui.spacing();text_wrap(label("此功能暂不可用：","Unavailable: ")..status[i].error)end
 if i==27 and status[i].ready and status[i].error~=""then imgui.spacing();text_wrap(label("传送提示：","Teleport: ")..status[i].error)end
end
local function reset_settings()
 for i=1,FEATURE_COUNT do off(i)end
 for key,value in pairs(defaults)do cfg[key]=value end
 key_capture=nil;save_settings()
end
re.on_draw_ui(function()
 if chinese_font then imgui.push_font(chinese_font)end
 if imgui.tree_node("RE2 Legacy Trainer / 原版修改器 (28)")then
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
 for i=1,FEATURE_COUNT do off(i)end;native_config()
end)
save_settings()
log.info("[RE2 Legacy] All 28 menu functions registered; saved switches and settings restored")
