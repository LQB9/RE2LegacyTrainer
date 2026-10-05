import sys,pathlib,json,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
files={};hooks={};callbacks={};storage={};drawn={};down_keys={};ui_inputs={};combo_changes={};mouse_up=0;mouse_down=0;tick_ms=0
function json_copy(v)
 if type(v)~='table'then return v end
 local out={};for k,item in pairs(v)do out[k]=json_copy(item)end;return out
end
reframework={get_game_name=function()return 're2'end,is_key_down=function(_,k)return down_keys[k]or false end,is_drawing_ui=function()return menu_open or false end}
log={info=function()end,warn=function(e) error_log=e end}
fs={glob=function(pattern)local out={};for p in pairs(files)do if p:match(pattern:gsub('%[%.%]','%%.'))then table.insert(out,p)end end;return out end}
json={load_file=function(p)if files[p]==nil then error('attempt to load missing JSON '..p)end;return json_copy(files[p])end,dump_file=function(p,v)files[p]=json_copy(v)end}
re={on_frame=function(f)callbacks.frame=f end,on_draw_ui=function(f)callbacks.draw=f end,
 on_script_reset=function(f)callbacks.reset=f end,on_pre_application_entry=function(n,f)callbacks.update=f end}
thread={get_hook_storage=function()return storage end}
singletons={}
sdk={PreHookResult={CALL_ORIGINAL=0,SKIP_ORIGINAL=1},get_tdb_version=function()return 70 end,
 to_managed_object=function(o)return o end,to_int64=function(i)return i end,to_ptr=function(i)return i end,
 get_managed_singleton=function(n)return singletons[n]end,
 get_native_singleton=function(n)assert(n=='via.hid.Mouse');return {}end,
 call_native_func=function(_,_,m)assert(m=='get_Device');if mouse_missing then return nil end;return {call=function(_,method)if method=='get_ButtonUp'then return mouse_up elseif method=='get_ButtonDown'then return mouse_down end;error('unexpected mouse method')end}end,
 find_type_definition=function(n)return {get_method=function(_,m)return {get_function=function()return n..'.'..m end,call=function()assert(n=='System.Environment'and m=='get_TickCount');if clock_missing then error('clock unavailable')end;return tick_ms end}end}end,
 hook=function(m,pre,post) hooks[m:get_function()]={pre=pre,post=post}end}
window_depth=0;table_depth=0;child_depth=0;color_depth=0;style_depth=0
imgui={tree_node=function()return true end,tree_pop=function()end,text=function()end,
 button=function(name)return name:match('##select_feature(%d+)')==tostring(feature_click)or(binding_click~=nil and name:match('##bind_(.+)')==binding_click)or(clear_binding_click~=nil and name:match('##clear_(.+)')==clear_binding_click)or(github_click and name:find('##github_project',1,true)~=nil)end,
 checkbox=function(name,v)if name:match('##feature')then table.insert(drawn,name)else table.insert(ui_inputs,name)end;if name:find('##panel_visible',1,true)and show_panel~=nil then return true,show_panel end;return false,v end,
 drag_int=function(n,v)table.insert(ui_inputs,n);return false,v end,slider_float=function(n,v)table.insert(ui_inputs,n);return false,v end,
 slider_int=function(n,v)table.insert(ui_inputs,n);return false,v end,
 combo=function(n,v,choices)table.insert(ui_inputs,n);assert(choices[v]);if combo_changes[n]then local value=combo_changes[n];combo_changes[n]=nil;return true,value end;return false,v end,
 TableFlags={NoSavedSettings=0,SizingStretchSame=0},ColumnFlags={WidthFixed=0,WidthStretch=0},
 begin_table=function()table_depth=table_depth+1;return true end,end_table=function()table_depth=table_depth-1 end,
 table_setup_column=function()end,table_next_row=function()end,table_set_column_index=function()end,
 table_set_bg_color=function()end,
 set_next_item_width=function()end,text_colored=function()end,spacing=function()end,separator=function()end,
 same_line=function()end,indent=function()end,unindent=function()end,
 is_item_hovered=function()return false end,set_tooltip=function()end,
 set_clipboard=function(text)clipboard=text end,
 push_style_color=function(index,color)assert(index>=14 and index<=17 and color>=-2147483648 and color<=2147483647);color_depth=color_depth+1 end,
 pop_style_color=function(count)color_depth=color_depth-count;assert(color_depth>=0)end,
 push_style_var=function(index,value)assert(index==18 and value>=16);style_depth=style_depth+1 end,
 pop_style_var=function(count)style_depth=style_depth-count;assert(style_depth>=0)end,
 begin_disabled=function()end,end_disabled=function()end,
 set_next_window_size=function()end,set_next_window_pos=function()end,
 get_display_size=function()return {x=1920,y=1080}end,get_window_size=function()return {x=860,y=680}end,
 begin_window=function()window_depth=window_depth+1;return not close_window end,
 end_window=function()window_depth=window_depth-1 end,
 begin_child_window=function()child_depth=child_depth+1;return true end,end_child_window=function()child_depth=child_depth-1 end}
next_address=100
function object(fields,methods)
 next_address=next_address+1
 return {fields=fields or{},methods=methods or{},address=next_address,
 get_address=function(self)return self.address end,
 get_field=function(self,k)if self.fields[k]==nil then error('missing field '..k)end;return self.fields[k]end,
 set_field=function(self,k,v)if self.fields[k]==nil then error('missing field '..k)end;self.fields[k]=v end,
 call=function(self,m,...)if not self.methods[m]then error('missing method '..m)end;return self.methods[m](self,...)end}
end
function backing(k)return '<'..k..'>k__BackingField'end
function singleton(n,o)singletons['app.ropeway.'..n]=o end
function method(n,m) return hooks['app.ropeway.'..n..'.'..m]end
function invoke(n,m,args,original)
 local h=method(n,m);storage={};local result=h.pre(args)
 local ret=original or 0;if result~=1 and type(original)=='function'then ret=original()end
 return result,h.post(ret)
end
''')
api=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg,update=update,restore=restore,status=status,defs=defs,request_flight=request_flight,flight_command=flight_command}\n')
lua.globals().api=api
tests=[]
def check(name,source):
    lua.execute(source);tests.append(name);print('PASS',name)
check('all 28 effects disabled; aim teleport and freeze follow legacy teleport with stable feature IDs', '''
 for i=1,26 do assert(api.cfg['f'..i]==false)end
 local seen={}
 callbacks.draw()
 for _,name in ipairs(drawn)do local id=tonumber(name:match('##feature(%d+)'));assert(not seen[id]);seen[id]=true end
 local order={};for i=1,15 do order[#order+1]=i end;order[#order+1]=27;order[#order+1]=28;for i=16,26 do order[#order+1]=i end
 assert(#drawn==28);for position,id in ipairs(order)do assert(seen[id]and tonumber(drawn[position]:match('##feature(%d+)'))==id)end
 assert(window_depth==0 and table_depth==0 and child_depth==0)
''')
original=json.loads((ROOT/'tests/fixtures/original_settings.json').read_text(encoding='utf8'))
payload=json.loads((ROOT/'tests/fixtures/original_features.json').read_text(encoding='utf8'))
for row in original:
    if row['SetIndex']==0 and 1<=row['Id']<=26:
        assert api['cfg']['key'+str(row['Id'])]==0
        assert api['cfg']['keymods'+str(row['Id'])]==0
for row in payload['cheats']:
    if 1<=row['id']<=26:
        assert api['defs'][row['id']][1]==row['label'] and api['defs'][row['id']][2]==row['label2']
tests.append('source EXE labels retain all 26 rows and feature toggle hotkeys start unbound');print('PASS',tests[-1])
check('selected options retain all original visible parameters without a height-distance control', '''
 for id=1,26 do feature_click=id;callbacks.draw()end;feature_click=nil
 local seen={};for _,name in ipairs(ui_inputs)do seen[name:match('##(.+)')]=true end
 for _,key in ipairs({'all1','v7','v8','time9_1','time9_2','time9_3','v10','v11','v12','v13','v14',
  'freeUD15','v16','h16','aimReset16','smooth16','change16','v17','v20','v22','vol22'})do assert(seen[key],key)end
 assert(not seen.height_step15 and not seen.height_amount15)
 assert(window_depth==0 and table_depth==0 and child_depth==0)
''')
check('assigned toggle shortcuts distinguish left and right modifiers and debounce toggles', '''
 api.cfg.key1=97;api.cfg.keymods1=4;api.cfg.key21=97;api.cfg.keymods21=1
 down_keys={[163]=true,[97]=true};callbacks.frame();assert(api.cfg.f1==false)
 down_keys={};callbacks.frame();down_keys={[162]=true,[97]=true};callbacks.frame();assert(api.cfg.f1)
 callbacks.frame();assert(api.cfg.f1);down_keys={};callbacks.frame()
 down_keys={[91]=true,[97]=true};callbacks.frame();assert(api.cfg.f21)
 down_keys={};callbacks.frame();api.cfg.f1=false;api.cfg.f21=false
 api.cfg.key1=0;api.cfg.keymods1=0;api.cfg.key21=0;api.cfg.keymods21=0
''')
check('managed runtime fixture', '''
 stealth_player_fixture=object({})
 hp=object({[backing('CurrentHitPoint')]=1200,[backing('Invincible')]=false})
 equipment=object({_ReticleFitPoint=.1,_IsReticleFit=false})
 layers=object({mCount=3})
 handle=object({[backing('LayerNos')]=layers})
 orderer=object({[backing('RejectPrecedeOrdersTrackHandle')]=handle})
 player=object({[backing('HitPointController')]=hp,[backing('Equipment')]=equipment,
 [backing('ActionOrderer')]=orderer,_IsPoison=true,_DopingTimer=0},{set_IsPoison=function(self,value)self.fields._IsPoison=value end,get_GameObject=function()return stealth_player_fixture end})
 pm=object({[backing('Pedometer')]=100},{get_CurrentPlayerCondition=function()return player end})
 inv=object({_CurrentSlotSize=8});singleton('PlayerManager',pm)
 singleton('gamemastering.InventoryManager',object({[backing('CurrentInventory')]=inv}))
 clock_data=object({_GameElapsedTime=123,_DemoSpendingTime=15,_InventorySpendingTime=25,_PauseSpendingTime=35})
 singleton('GameClock',object({_GameSaveData=clock_data}))
 save_data=object({SaveTimes=6});singleton('gamemastering.MainFlowManager',object({gameHeaderSaveData=save_data}))
 records=object({OpenItemBox=12,UseHealItem=14});singleton('gamemastering.RecordManager',object({gameSaveData=records}))
 rank=object({[backing('IsRankPointFix')]=false,[backing('RankPoint')]=4000});singleton('GameRankSystem',rank)
 enemies=object({_IsInvisible=false},{get_EnemyList=function()return object({},{get_Count=function()return 0 end})end});singleton('EnemyManager',enemies)
 callbacks.update()
''')
check('health and one hit kill discriminate player and enemy', '''
 api.cfg.f1=true;local args={0,hp,200};invoke('HitPointController','addDamage',args);assert(args[3]==0)
 local enemy=object({});args={0,enemy,200};invoke('HitPointController','addDamage',args);assert(args[3]==200)
 api.cfg.all1=true;invoke('HitPointController','addDamage',args);assert(args[3]==0)
 api.cfg.all1=false;api.cfg.f3=true;args={0,enemy,200};invoke('HitPointController','addDamage',args);assert(args[3]==1073741823)
 args={0,hp,200};invoke('HitPointController','addDamage',args);assert(args[3]==0)
''')
check('items allow increases and preserve consumption return value', '''
 api.cfg.f2=true;local slot=object({_Stock=object({})},{get_Number=function()return 10 end})
 local args={0,slot,3};invoke('inventory.Slot','set_Number',args);assert(args[3]==10)
 args={0,slot,15};invoke('inventory.Slot','set_Number',args);assert(args[3]==15)
 local skip,ret=invoke('inventory.Slot','reduce',{0,slot,3},0);assert(skip==1 and ret==3)
''')
check('Tyrant sleep and recoil are conditional', '''
 api.cfg.f4=true;local skip,ret=invoke('enemy.em6200.Em6200Think','doSleep',{0,object({})},1);assert(skip==1 and ret==0)
 api.cfg.f4=false;skip,ret=invoke('enemy.em6200.Em6200Think','doSleep',{0,object({})},1);assert(skip==0 and ret==1)
 api.cfg.f5=true;skip=invoke('camera.PlayerCameraController','updateRecoil',{0,object({})});assert(skip==1)
''')
check('accuracy and firing delay restore temporary animation data', '''
 api.cfg.f6=true;invoke('survivor.Equipment','updateReticleFit',{0,equipment});assert(equipment.fields._ReticleFitPoint==100 and equipment.fields._IsReticleFit)
 api.cfg.f18=true;local h=method('survivor.SurvivorActionOrderer','updatePrecedeBit');storage={};h.pre({0,orderer});assert(layers.fields.mCount==0);h.post(0);assert(layers.fields.mCount==3)
''')
check('backpack, four statistics and game clock use named fields', '''
 for _,i in ipairs({7,9,10,11,12,13})do api.cfg['f'..i]=true end
 api.cfg.seconds9=60;api.cfg.v10=2;api.cfg.v11=3;api.cfg.v12=4;api.cfg.v13=5;callbacks.update()
 assert(inv.fields._CurrentSlotSize==20 and clock_data.fields._GameElapsedTime==600000000)
 assert(clock_data.fields._DemoSpendingTime==0 and clock_data.fields._InventorySpendingTime==0 and clock_data.fields._PauseSpendingTime==0)
 assert(save_data.fields.SaveTimes==6 and records.fields.OpenItemBox==12 and records.fields.UseHealItem==14 and pm.fields[backing('Pedometer')]==100)
 local manager=singletons['app.ropeway.gamemastering.MainFlowManager']
 invoke('gamemastering.MainFlowManager','addSaveTimes',{0,manager},function()save_data.fields.SaveTimes=7;return 99 end)
 assert(save_data.fields.SaveTimes==2)
 manager=singletons['app.ropeway.gamemastering.RecordManager']
 invoke('gamemastering.RecordManager','addRecordCount',{0,manager},function()records.fields.OpenItemBox=13;return 99 end)
 assert(records.fields.OpenItemBox==3 and records.fields.UseHealItem==14)
 invoke('gamemastering.RecordManager','addRecordCount',{0,manager},function()records.fields.UseHealItem=15;return 99 end)
 assert(records.fields.UseHealItem==4)
 api.cfg.v11=33;api.cfg.v12=44
 invoke('gamemastering.RecordManager','addRecordCount',{0,manager},99)
 assert(records.fields.OpenItemBox==3 and records.fields.UseHealItem==4,'unrelated record events must not apply counters')
 api.cfg.v11=3;api.cfg.v12=4
 invoke('PlayerManager','addPedometer',{0,pm},function()pm.fields[backing('Pedometer')]=101;return 99 end)
 assert(pm.fields[backing('Pedometer')]==5)
 api.restore(7);assert(inv.fields._CurrentSlotSize==8)
''')
check('invulnerability, invisibility and rank fixing restore flags', '''
 for _,i in ipairs({19,20,21,23,24})do api.cfg['f'..i]=true end
 callbacks.update();assert(hp.fields[backing('Invincible')] and enemies.fields._IsInvisible and rank.fields[backing('IsRankPointFix')])
 assert(rank.fields[backing('RankPoint')]==12999 and player.fields._IsPoison==false and player.fields._DopingTimer==180)
 api.restore(19);api.restore(20);api.restore(21)
 assert(hp.fields[backing('Invincible')]==false and enemies.fields._IsInvisible==false and rank.fields[backing('IsRankPointFix')]==false)
''')
check('invisibility drops existing player aggro and action target without freezing enemies', '''
 function list_of(items)return object({},{get_Count=function()return #items end,get_Item=function(_,i)return items[i+1]end})end
 function hate_info(body,state)return object({[backing('TargetGameObject')]=body,[backing('FindState')]=state},{
  get_TargetGameObject=function(self)return self.fields[backing('TargetGameObject')]end,
  get_FindState=function(self)return self.fields[backing('FindState')]end,
  lose=function(self)self.losses=(self.losses or 0)+1;self.fields[backing('FindState')]=0 end})end
 function ai_enemy(body,target)
  local action=object({target=target,locked=false},{get_TargetObject=function(self)return self.fields.target end,
   get_TargetLocked=function(self)return self.fields.locked end,clearTarget=function(self)self.fields.target=false;self.clears=(self.clears or 0)+1 end})
  local info=hate_info(target,2);local other=hate_info(object({}),2)
  local hate=object({},{get_CurrentTarget=function()return info end,get_HateTargetList=function()return list_of({info,other})end})
  local controller=object({},{get_GameObject=function()return body end,get_HateController=function()return hate end,get_ActionTarget=function()return action end})
  local entry=object({},{get_Controller=function()return controller end})
  return {entry=entry,controller=controller,hate=hate,info=info,other=other,action=action,body=body}
 end
 old_enemy_list=enemies.methods.get_EnemyList
 ai_body=object({TimeScale=1.25});ai=ai_enemy(ai_body,stealth_player_fixture);ai_entries={ai.entry}
 enemies.methods.get_EnemyList=function()return list_of(ai_entries)end
 api.cfg.f21=true;callbacks.update()
 assert(api.status[21].error=='',api.status[21].error)
 assert(ai.info.fields[backing('FindState')]==0 and ai.info.losses==1 and ai.other.fields[backing('FindState')]==2)
 assert(ai.action.fields.target==false and ai.action.clears==1 and ai_body.fields.TimeScale==1.25)
 callbacks.update();assert(ai.info.losses==1 and ai.action.clears==1)
''')
check('invisibility blocks player sight, damage hate and player-sourced noise while allowing other targets', '''
 for _,name in ipairs({'find','addHate'})do
  local calls=0
  local result=invoke('EnemyHateController',name,{0,ai.hate,stealth_player_fixture,1},function()calls=calls+1 end)
  assert(result==1 and calls==0,name)
  invoke('EnemyHateController',name,{0,ai.hate,ai.other.fields[backing('TargetGameObject')],1},function()calls=calls+1 end)
  assert(calls==1)
 end
 local calls=0
 invoke('EnemyHateController','attention',{0,ai.hate,nil,stealth_player_fixture},function()calls=calls+1 end)
 invoke('EnemyHateController','attention',{0,ai.hate,stealth_player_fixture,nil},function()calls=calls+1 end)
 assert(calls==0)
 invoke('EnemyHateController','attention',{0,ai.hate,nil,ai.other.fields[backing('TargetGameObject')]},function()calls=calls+1 end)
 assert(calls==1)
 local args={0,ai.action,stealth_player_fixture};invoke('ActionTargetController','setTargetObject',args);assert(args[3]==0)
 args={0,object({}),stealth_player_fixture};invoke('ActionTargetController','setTargetObject',args);assert(args[3]==stealth_player_fixture)
''')
check('invisibility handles pending target requests, later spawns and script-controlled locked targets', '''
 ai.info.fields[backing('FindState')]=2
 invoke('EnemyHateController','updateCurrentTarget',{0,ai.hate},function()assert(ai.info.fields[backing('FindState')]==0)end)
 local later=ai_enemy(object({}),stealth_player_fixture);ai_entries[#ai_entries+1]=later.entry
 callbacks.update();assert(later.info.losses==1 and later.action.fields.target==false)
 ai.action.fields.target=stealth_player_fixture;ai.action.fields.locked=true
 callbacks.update();assert(ai.action.fields.target==stealth_player_fixture and ai.action.fields.locked)
 ai.action.fields.locked=false
''')
check('invisibility stops during events, restores detection when disabled and leaves no stale target map', '''
 player.fields[backing('IsEvent')]=true;callbacks.update();assert(not enemies.fields._IsInvisible)
 local calls=0
 invoke('EnemyHateController','find',{0,ai.hate,stealth_player_fixture,1},function()calls=calls+1 end);assert(calls==1)
 player.fields[backing('IsEvent')]=false;callbacks.update();assert(enemies.fields._IsInvisible)
 api.cfg.f21=false;api.restore(21);assert(not enemies.fields._IsInvisible)
 invoke('EnemyHateController','find',{0,ai.hate,stealth_player_fixture,1},function()calls=calls+1 end);assert(calls==2)
 local args={0,ai.action,stealth_player_fixture};invoke('ActionTargetController','setTargetObject',args);assert(args[3]==stealth_player_fixture)
 assert(ai.info.fields[backing('FindState')]==0,'off must not restore stale aggro')
 enemies.methods.get_EnemyList=old_enemy_list
''')
check('poison setter and wet material state restore original values', '''
 local args={0,player,1};invoke('survivor.SurvivorCondition','set_IsPoison',args);assert(args[3]==0)
 api.cfg.f17=true;local rain=object({NowWetRate=.2,NowRainRate=.3,MatState=0})
 local h=method('effect.script.PlRainEffect','MaterialUpdate');storage={};h.pre({0,rain})
 assert(rain.fields.NowWetRate==1 and rain.fields.NowRainRate==1 and rain.fields.MatState==3)
 h.post(0);assert(rain.fields.NowWetRate==.2 and rain.fields.NowRainRate==.3 and rain.fields.MatState==0)
''')
check('camera distance, smooth height and aim reset preserve shared params', '''
 api.cfg.f16=true;api.cfg.h16=2;api.cfg.smooth16=false
 local param=object({_GazeDistance=3,_Offset={x=1,y=2,z=3}})
 local transition=object({_Param=param});local info=object({_Param=transition})
 local interpolation=object({[backing('NextInfo')]=info,[backing('PrevInfo')]=info})
 local cam=object({[backing('NowKindType')]=0,[backing('Param')]=interpolation})
 local h=method('camera.PlayerCameraController','onCameraUpdate');storage={};h.pre({0,cam})
 assert(param.fields._GazeDistance==1.3 and param.fields._Offset.y==4)
 h.post(0);assert(param.fields._GazeDistance==3 and param.fields._Offset.y==2)
 cam.fields[backing('NowKindType')]=10001;storage={};h.pre({0,cam});assert(param.fields._Offset.y==2);h.post(0)
 cam.fields[backing('NowKindType')]=1;storage={};h.pre({0,cam});assert(param.fields._Offset.y==2);h.post(0)
 cam.fields[backing('NowKindType')]=0;api.cfg.h16=1;api.cfg.smooth16=true;api.cfg.change16=.2
 storage={};h.pre({0,cam});assert(math.abs(param.fields._Offset.y-2.2)<.0001);h.post(0)
 for i=1,6 do storage={};h.pre({0,cam});h.post(0)end
 storage={};h.pre({0,cam});assert(math.abs(param.fields._Offset.y-3)<.0001);h.post(0)
''')
check('Ada hack fills capacity and countdown retains prior frame', '''
 api.cfg.f25=true;local node=object({_MotorCount=0,_CapacityValue=500});invoke('gimmick.action.GimmickWiringNodeBase','updateCountSub',{0,node});assert(node.fields._MotorCount==500)
 api.cfg.f26=true;local timer=object({[backing('CurrentTimerFrame')]=100})
 local h=method('gui.CountDownBehavior','updateCountDown');storage={};h.pre({0,timer});timer.fields[backing('CurrentTimerFrame')]=99;h.post(0);assert(timer.fields[backing('CurrentTimerFrame')]==100)
''')
check('four action bindings are captured, named and persisted without firing', '''
 files['re2_legacy_native_status.json']={version=4,features={['8']={ready=true},['14']={ready=true},['15']={ready=true},['22']={ready=true}}}
 feature_click=15;callbacks.draw();feature_click=nil;api.cfg.f15=true
 for index,key in ipairs({116,117,118,119})do
  local fields={'save_key15','load_key15','up_key15','down_key15'}
  local actions={'save15','load15','up15','down15'}
  down_keys={};binding_click=fields[index];callbacks.draw();binding_click=nil
  down_keys={[key]=true};callbacks.frame()
  assert(api.cfg[fields[index]]==key and files['re2_legacy_settings.json'][fields[index]]==key)
  assert(api.cfg[actions[index]]==0,'binding itself must not trigger an action')
  callbacks.frame();assert(api.cfg[actions[index]]==0)
  down_keys={};callbacks.frame()
 end
 assert(files['re2_legacy_native.json'].height_step15==.1)
 assert(files['re2_legacy_native.json'].height_amount15==nil)
''')
check('action shortcuts trigger once per press and require enabled, ready player', '''
 for _,s in pairs(api.status)do s.ready=true end
 api.cfg.f15=true
 local actions={'save15','load15','up15','down15'}
 for index,key in ipairs({116,117,118,119})do
  local before=api.cfg[actions[index]]
  down_keys={[key]=true};callbacks.frame();assert(api.cfg[actions[index]]==before+1)
  for i=1,10 do callbacks.frame()end;assert(api.cfg[actions[index]]==before+1)
  down_keys={};callbacks.frame()
 end
 local before=api.cfg.save15
 api.cfg.f15=false;down_keys={[116]=true};callbacks.frame();assert(api.cfg.save15==before)
 down_keys={};callbacks.frame();api.cfg.f15=true;api.status[15].ready=false
 down_keys={[116]=true};callbacks.frame();assert(api.cfg.save15==before)
 down_keys={};callbacks.frame();api.status[15].ready=true
 singleton('PlayerManager',nil);callbacks.update();down_keys={[116]=true};callbacks.frame();assert(api.cfg.save15==before)
 singleton('PlayerManager',pm);callbacks.update();down_keys={};callbacks.frame()
''')
check('combination binding replaces only the matching chord and ignores held keys', '''
 api.cfg.key1=75;api.cfg.keymods1=4;api.cfg.key2=75;api.cfg.keymods2=0
 down_keys={[65]=true};binding_click='save_key15';callbacks.draw();binding_click=nil
 callbacks.frame();assert(api.cfg.save_key15==116,'already held key must be ignored')
 down_keys={[162]=true};callbacks.frame();assert(api.cfg.save_key15==116,'modifier alone must be ignored')
 down_keys={[162]=true,[75]=true};callbacks.frame()
 assert(api.cfg.save_key15==75 and api.cfg.save_mod15==4)
 assert(api.cfg.key1==0 and api.cfg.key2==75)
 down_keys={};callbacks.frame();local before=api.cfg.save15
 down_keys={[162]=true,[160]=true,[75]=true};callbacks.frame();assert(api.cfg.save15==before)
 down_keys={};callbacks.frame();down_keys={[162]=true,[75]=true};callbacks.frame();assert(api.cfg.save15==before+1)
 down_keys={};callbacks.frame()
''')
check('Escape cancels binding, Backspace binds without firing and the explicit clear button removes it', '''
 binding_click='load_key15';callbacks.draw();binding_click=nil;down_keys={[27]=true};callbacks.frame()
 assert(api.cfg.load_key15==117)
 down_keys={};callbacks.frame();binding_click='load_key15';callbacks.draw();binding_click=nil
 local before=api.cfg.load15;down_keys={[8]=true};callbacks.frame();assert(api.cfg.load_key15==8 and api.cfg.load_mod15==0 and api.cfg.load15==before)
 down_keys={};callbacks.frame()
 clear_binding_click='load_key15';callbacks.draw();clear_binding_click=nil;assert(api.cfg.load_key15==0 and api.cfg.load_mod15==0)
''')
check('new features start with unbound toggle hotkeys', '''
 for i=27,28 do assert(api.cfg['key'..i]==0 and api.cfg['keymods'..i]==0 and not api.cfg['f'..i])end
''')
check('enemy freeze excludes the player, handles late spawns, and restores exact previous scales', '''
 local function body(scale)return object({},{get_TimeScale=function(self)return self.scale end,set_TimeScale=function(self,s)self.scale=s end})end
 enemy_a=body();enemy_a.scale=.6;enemy_b=body();enemy_b.scale=1.4;player_body=body();player_body.scale=1
 player.methods.get_GameObject=function()return player_body end
 entries={object({},{get_GameObject=function()return enemy_a end}),object({},{get_GameObject=function()return nil end}),object({},{get_GameObject=function()return player_body end})}
 list=object({},{get_Count=function()return #entries end,get_Item=function(_,i)return entries[i+1]end})
 enemies.methods.get_EnemyList=function()return list end
 api.cfg.f28=true;callbacks.update();assert(enemy_a.scale==0 and player_body.scale==1)
 entries[#entries+1]=object({},{get_GameObject=function()return enemy_b end})
 callbacks.update();assert(enemy_b.scale==0)
 table.remove(entries,1);callbacks.update();assert(enemy_a.scale==.6 and enemy_b.scale==0)
 api.cfg.f28=false;api.restore(28);assert(enemy_b.scale==1.4 and player_body.scale==1)
''')
check('freeze restores on cutscenes and script reset', '''
 api.cfg.f28=true;callbacks.update();assert(enemy_b.scale==0)
 player.fields[backing('IsEvent')]=true;callbacks.update();assert(enemy_b.scale==1.4)
 player.fields[backing('IsEvent')]=false;callbacks.update();assert(enemy_b.scale==0)
 api.restore();assert(enemy_b.scale==1.4);api.cfg.f28=false
''')
check('aim teleport uses a copied valid hit, preserves 10 second expiry and blocks events', '''
 test_time=1000;original_time=os.time;os.time=function()return test_time end
 aim_vector={x=12,y=3,z=-5};camera=object({},{get_IsHoldWeaponCamera=function()return aiming end,get_IsHitViewAim=function()return aim_hit end,get_HitViewAimPosition=function()return aim_vector end,get_CameraDirection=function()return {x=6,y=0,z=8}end})
 singleton('camera.CameraSystem',camera);api.cfg.f27=true;api.status[27].ready=true
 aiming=true;aim_hit=false;callbacks.update();assert(not api.request_flight('aim'))
 aim_hit=true;callbacks.update();aim_vector.x=99
 assert(api.request_flight('aim'));assert(api.flight_command.fly27_x==12 and api.flight_command.fly27_y==3)
 aiming=false;test_time=1011;callbacks.update();assert(not api.request_flight('aim'))
 test_time=1001;player.fields[backing('IsEvent')]=true;assert(not api.request_flight('aim'));player.fields[backing('IsEvent')]=false
 os.time=original_time
''')
check('removed camera action cannot issue a command or retain default controls', '''
 assert(api.cfg.distance27==nil and api.cfg.forward_key27==nil and api.cfg.forward_device27==nil)
 local seq=api.flight_command.fly27_seq;assert(not api.request_flight('forward'));assert(api.flight_command.fly27_seq==seq)
 api.cfg.forward_key27=120;api.cfg.forward_mod27=0;api.cfg.forward_device27=1
 down_keys={};callbacks.frame();down_keys={[120]=true};callbacks.frame();assert(api.flight_command.fly27_seq==seq)
 down_keys={};callbacks.frame();api.cfg.forward_key27=nil;api.cfg.forward_mod27=nil;api.cfg.forward_device27=nil
''')
check('flight shortcuts debounce and do not write coordinates when disabled', '''
 files['re2_legacy_native_status.json']={version=5,flight={active=false,saved_valid=true},features={['8']={ready=true},['14']={ready=true},['15']={ready=true},['22']={ready=true},['27']={ready=true}}}
 api.cfg.back_key27=120;api.cfg.back_mod27=0
 down_keys={};for i=1,60 do callbacks.frame()end
 local seq=api.flight_command.fly27_seq;down_keys={[120]=true};callbacks.frame();assert(api.flight_command.fly27_seq==seq+1)
 for i=1,10 do callbacks.frame()end;assert(api.flight_command.fly27_seq==seq+1)
 down_keys={};callbacks.frame();api.cfg.f27=false;down_keys={[120]=true};callbacks.frame();assert(api.flight_command.fly27_seq==seq+1)
 down_keys={};callbacks.frame();api.restore(27)
 assert(files['re2_legacy_native.json'].fly27_seq~=nil)
''')

check('RE2 nullable terrain hits are decoded and absent values never become targets', '''
 api.cfg.f27=true;api.status[27].ready=true;api.restore(27)
 aiming=true;aim_hit=false
 nullable=object({_HasValue=true,_Value={x=8,y=2,z=-3}})
 camera.methods.get_IsHitViewTerrain=function()return true end
 camera.methods.get_HitViewTerrainPosition=function()return nullable end
 callbacks.update();assert(api.request_flight('aim'))
 assert(api.flight_command.fly27_x==8 and api.flight_command.fly27_y==2 and api.flight_command.fly27_z==-3)
 api.restore(27);nullable.fields._HasValue=false;callbacks.update();assert(not api.request_flight('aim'))
 nullable.fields._HasValue=true;nullable.fields._Value.x=0/0;callbacks.update();assert(not api.request_flight('aim'))
 aiming=false;api.cfg.f27=false;api.restore(27)
''')
check('enemy context game objects retain inherited negative time scale on restore', '''
 local context_body=object({},{get_TimeScale=function(self)return self.scale end,set_TimeScale=function(self,value)self.scale=value end})
 context_body.scale=-1
 entries[#entries+1]=object({},{get_GameObject=function()return nil end,get_ContextGameObject=function()return context_body end})
 api.cfg.f28=true;callbacks.update();assert(context_body.scale==0)
 api.cfg.f28=false;api.restore(28);assert(context_body.scale==-1)
''')
check('mouse binding UI offers five buttons, persists choices and prevents duplicate mouse actions', '''
 feature_click=27;callbacks.draw();feature_click=nil
 local before=#ui_inputs;callbacks.draw();local seen={};for i=before+1,#ui_inputs do seen[ui_inputs[i]]=true end
 assert(seen['##aim_device27']and seen['##back_device27'],'both action bindings are immediately visible')
 assert(not seen['##forward_device27']and not seen['##distance27'])
 combo_changes={['##aim_device27']=2};callbacks.draw()
 assert(api.cfg.aim_device27==2 and api.cfg.aim_mouse27==4 and api.cfg.aim_double27)
 assert(files['re2_legacy_settings.json'].aim_device27==2)
 combo_changes={['##back_device27']=2,['##back_mouse27']=4};callbacks.draw()
 assert(api.cfg.back_mouse27==4 and api.cfg.aim_mouse27==1)
 combo_changes={['##aim_mouse27']=4};callbacks.draw()
 combo_changes={['##back_mouse27']=5};callbacks.draw()
 assert(api.cfg.aim_mouse27==4 and api.cfg.back_mouse27==5 and api.cfg.forward_mouse27==nil)
 assert(window_depth==0 and table_depth==0 and child_depth==0)
 function mouse_frame(up,down,tick)mouse_up=up;mouse_down=down;tick_ms=tick;callbacks.frame()end
 function new_aim()api.cfg.f27=true;api.status[27].ready=true;aiming=true;nullable.fields._HasValue=true;nullable.fields._Value={x=8,y=2,z=-3};callbacks.update();aiming=false end
 files['re2_legacy_native_status.json'].flight.active=false
''')
check('middle mouse double release teleports once directly, ignores holding and consumes the aim cache', '''
 api.restore(27);api.cfg.interp27=true;new_aim();local seq=api.flight_command.fly27_seq
 mouse_frame(0,4,1000);mouse_frame(0,0,1030);assert(api.flight_command.fly27_seq==seq)
 mouse_frame(4,0,1050);assert(api.flight_command.fly27_seq==seq)
 mouse_frame(4,0,1060);assert(api.flight_command.fly27_seq==seq,'repeated release flag is not another click')
 mouse_frame(0,4,1150);mouse_frame(4,0,1200)
 assert(api.flight_command.fly27_seq==seq+1 and api.flight_command.fly27_kind==1)
 assert(files['re2_legacy_native.json'].fly27_interp==false and api.cfg.interp27==true)
 assert(api.flight_command.fly27_x==8 and api.flight_command.fly27_y==2 and not api.request_flight('aim',true))
 for i=1,10 do mouse_frame(4,0,1200+i)end;assert(api.flight_command.fly27_seq==seq+1)
''')
check('mouse double clicks expire after 500 ms and remain valid across the 32 bit clock wrap', '''
 api.restore(27);new_aim();local seq=api.flight_command.fly27_seq
 mouse_frame(0,0,2000);mouse_frame(4,0,2010);mouse_frame(0,0,2500);mouse_frame(4,0,2511)
 assert(api.flight_command.fly27_seq==seq)
 mouse_frame(0,0,2600);mouse_frame(4,0,2611);assert(api.flight_command.fly27_seq==seq+1)
 api.restore(27);new_aim();seq=api.flight_command.fly27_seq
 mouse_frame(0,0,4294967190);mouse_frame(4,0,4294967200);mouse_frame(0,0,25);mouse_frame(4,0,50)
 assert(api.flight_command.fly27_seq==seq+1)
''')
check('menu clicks, disabled actions, cutscenes and missing input clock cannot form a teleport double click', '''
 api.restore(27);new_aim();local seq=api.flight_command.fly27_seq
 menu_open=true;mouse_frame(0,0,3000);mouse_frame(4,0,3010);menu_open=false
 mouse_frame(0,0,3100);mouse_frame(4,0,3110);assert(api.flight_command.fly27_seq==seq)
 api.cfg.f27=false;mouse_frame(0,0,3200);mouse_frame(4,0,3210);api.cfg.f27=true
 mouse_frame(0,0,3300);mouse_frame(4,0,3310);assert(api.flight_command.fly27_seq==seq)
 player.fields[backing('IsEvent')]=true;mouse_frame(0,0,3400);mouse_frame(4,0,3410);player.fields[backing('IsEvent')]=false
 mouse_frame(0,0,3500);mouse_frame(4,0,3510);assert(api.flight_command.fly27_seq==seq)
 clock_missing=true;mouse_frame(0,0,3550);clock_missing=false;mouse_frame(0,0,3600);mouse_frame(4,0,3610)
 assert(api.flight_command.fly27_seq==seq)
''')
check('single mouse releases respect interpolation and the return side button debounces without a camera action', '''
 api.restore(27);api.cfg.aim_double27=false;new_aim();local seq=api.flight_command.fly27_seq
 mouse_frame(0,0,4000);mouse_frame(4,0,4010);assert(api.flight_command.fly27_seq==seq+1)
 assert(files['re2_legacy_native.json'].fly27_interp==true)
 mouse_frame(0,0,4020);mouse_frame(32,0,4030);assert(api.flight_command.fly27_kind==2)
 mouse_frame(32,0,4040);assert(api.flight_command.fly27_seq==seq+2)
 mouse_frame(0,0,4050);mouse_frame(64,0,4060);assert(api.flight_command.fly27_seq==seq+2 and api.flight_command.fly27_kind==2)
 mouse_frame(0,0,4070);api.cfg.aim_double27=true;api.cfg.f27=false;api.restore(27)
''')
check('return action captures Backspace, triggers once per press and can be cleared independently', '''
 feature_click=27;callbacks.draw();feature_click=nil
 api.cfg.f27=true;api.status[27].ready=true;api.cfg.back_device27=1
 down_keys={};callbacks.frame();binding_click='back_key27';callbacks.draw();binding_click=nil
 local seq=api.flight_command.fly27_seq
 down_keys={[8]=true};callbacks.frame();assert(api.cfg.back_key27==8 and api.cfg.back_mod27==0)
 assert(api.flight_command.fly27_seq==seq,'capturing a return key must not teleport')
 assert(files['re2_legacy_settings.json'].back_key27==8)
 callbacks.frame();assert(api.flight_command.fly27_seq==seq)
 down_keys={};callbacks.frame();down_keys={[8]=true};callbacks.frame()
 assert(api.flight_command.fly27_seq==seq+1 and api.flight_command.fly27_kind==2)
 callbacks.frame();assert(api.flight_command.fly27_seq==seq+1)
 down_keys={};callbacks.frame();clear_binding_click='back_key27';callbacks.draw();clear_binding_click=nil
 assert(api.cfg.back_key27==0 and files['re2_legacy_settings.json'].back_key27==0)
 api.cfg.f27=false;combo_changes={['##back_device27']=2};callbacks.draw();api.restore(27)
''')

check('freeze binding UI saves keyboard or mouse selection and resolves conflicts with teleport actions', '''
 feature_click=28;callbacks.draw();feature_click=nil
 combo_changes={['##freeze_device28']=2,['##freeze_mouse28']=4};callbacks.draw()
 assert(api.cfg.freeze_device28==2 and api.cfg.freeze_mouse28==4 and api.cfg.aim_mouse27==1)
 feature_click=27;callbacks.draw();feature_click=nil;combo_changes={['##aim_mouse27']=4};callbacks.draw()
 assert(api.cfg.aim_mouse27==4 and api.cfg.freeze_mouse28==1)
 feature_click=28;callbacks.draw();feature_click=nil;combo_changes={['##freeze_mouse28']=6};callbacks.draw()
 assert(files['re2_legacy_settings.json'].freeze_device28==2 and files['re2_legacy_settings.json'].freeze_mouse28==6)
 assert(api.cfg.back_mouse27==5 and window_depth==0 and table_depth==0 and child_depth==0)
''')
check('all five mouse buttons toggle freeze once per release independently of teleport and restore enemy scales', '''
 api.cfg.f27=false;api.status[27].ready=false;api.cfg.f28=false;api.restore(28)
 local seq=api.flight_command.fly27_seq
 for index,code in ipairs({1,2,4,32,64})do
  api.cfg.freeze_mouse28=index+1;mouse_frame(0,0,5000+index*100)
  mouse_frame(0,code,5001+index*100);assert(not api.cfg.f28)
  mouse_frame(code,0,5002+index*100);assert(api.cfg.f28);callbacks.update()
  assert(enemy_b.scale==0 and player_body.scale==1)
  mouse_frame(code,0,5003+index*100);assert(api.cfg.f28)
  mouse_frame(0,code,5004+index*100);mouse_frame(code,0,5005+index*100)
  assert(not api.cfg.f28 and enemy_b.scale==1.4 and player_body.scale==1)
 end
 assert(api.flight_command.fly27_seq==seq);api.status[27].ready=true
 mouse_frame(0,0,5700)
''')
check('freeze mouse ignores menus, capture, events, missing player or clock and respects keyboard mode', '''
 api.cfg.freeze_device28=2;api.cfg.freeze_mouse28=6;api.cfg.f28=false;api.cfg.f27=false
 menu_open=true;mouse_frame(64,0,6000);menu_open=false;mouse_frame(64,0,6010);assert(not api.cfg.f28)
 mouse_frame(0,0,6020);player.fields[backing('IsEvent')]=true;mouse_frame(64,0,6030)
 player.fields[backing('IsEvent')]=false;mouse_frame(64,0,6040);assert(not api.cfg.f28)
 mouse_frame(0,0,6050);singleton('PlayerManager',nil);callbacks.update();mouse_frame(64,0,6060)
 singleton('PlayerManager',pm);callbacks.update();mouse_frame(64,0,6070);assert(not api.cfg.f28)
 mouse_frame(0,0,6080);clock_missing=true;mouse_frame(64,0,6090);assert(not api.cfg.f28)
 clock_missing=false;mouse_frame(0,0,6100)
 feature_click=27;callbacks.draw();feature_click=nil;binding_click='key27';callbacks.draw();binding_click=nil
 mouse_frame(64,0,6110);assert(not api.cfg.f28)
 down_keys={[27]=true};callbacks.frame();down_keys={};mouse_frame(0,0,6120)
 api.cfg.freeze_device28=1;api.cfg.key28=123;api.cfg.keymods28=0
 mouse_frame(64,0,6130);assert(not api.cfg.f28)
 down_keys={[123]=true};callbacks.frame();assert(api.cfg.f28)
 callbacks.frame();assert(api.cfg.f28);callbacks.update();assert(enemy_b.scale==0)
 down_keys={};callbacks.frame();down_keys={[123]=true};callbacks.frame()
 assert(not api.cfg.f28 and enemy_b.scale==1.4);down_keys={};mouse_frame(0,0,6140)
 feature_click=28;callbacks.draw();feature_click=nil;combo_changes={['##freeze_device28']=2};callbacks.draw()
''')

# Use a separate fixture to verify a real reload, leaving the current callback set intact.
lua.execute('original_callbacks={};for k,v in pairs(callbacks)do original_callbacks[k]=v end;files["re2_legacy_settings.json"].forward_key27=120;files["re2_legacy_settings.json"].forward_device27=2;files["re2_legacy_settings.json"].forward_mouse27=6;files["re2_legacy_settings.json"].distance27=3')
persisted=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
assert persisted['cfg']['save_key15']==75 and persisted['cfg']['save_mod15']==4
assert persisted['cfg']['load_key15']==0 and persisted['cfg']['up_key15']==118 and persisted['cfg']['down_key15']==119
assert persisted['cfg']['f15']==True
assert persisted['cfg']['aim_device27']==2 and persisted['cfg']['aim_mouse27']==4 and persisted['cfg']['aim_double27']==True
assert persisted['cfg']['back_device27']==2 and persisted['cfg']['forward_device27'] is None
assert persisted['cfg']['freeze_device28']==2 and persisted['cfg']['freeze_mouse28']==6 and persisted['cfg']['key28']==123
assert persisted['cfg']['forward_key27'] is None and persisted['cfg']['forward_mouse27'] is None and persisted['cfg']['distance27'] is None
assert all(persisted['cfg']['f'+str(i)]==api['cfg']['f'+str(i)] for i in range(1,29))
assert all(persisted['cfg'][key]==0 for key in ('save15','load15','up15','down15'))
tests.append('all saved switches and shortcuts survive reload without replaying coordinate commands');print('PASS',tests[-1])
lua.globals().startup_cfg=persisted['cfg']
check('remembered one hit kill leaves damage unchanged until the current player is known', '''
 assert(startup_cfg.f3)
 local args={0,hp,25};fresh_start_return=method('HitPointController','addDamage').pre(args)
 assert(args[3]==25 and (fresh_start_return==nil or fresh_start_return==0))
''')
# Restore the original closures for reset checks without losing their player references.
lua.globals().api=api
lua.execute('callbacks=original_callbacks')
check('script reset disables all native and managed controls', '''
 expected_switches={};for i=1,28 do expected_switches[i]=api.cfg['f'..i]end
 callbacks.reset();for i=1,28 do assert(api.cfg['f'..i]==false)end
 assert(files['re2_legacy_native.json'].f8==false and files['re2_legacy_native.json'].f14==false and files['re2_legacy_native.json'].f15==false and files['re2_legacy_native.json'].f22==false)
 for i=1,28 do assert(files['re2_legacy_settings.json']['f'..i]==expected_switches[i])end
''')
reset_reload=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
lua.globals().reset_reload=reset_reload
check('reload after script teardown restores the saved selections and parameters', '''
 for i=1,28 do assert(reset_reload.cfg['f'..i]==expected_switches[i])end
 assert(reset_reload.cfg.v16==api.cfg.v16 and reset_reload.cfg.h16==api.cfg.h16)
 for _,key in ipairs({'save15','load15','up15','down15'})do assert(reset_reload.cfg[key]==0)end
''')
lua.execute("files['re2_legacy_settings.json']=7;files['re2_legacy_commands.json']={seq=777,values={f1=true,f15=true}}")
fresh=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
lua.globals().fresh=fresh
check('reload tolerates malformed settings and ignores stale enable commands', '''
 for i=1,60 do callbacks.frame()end
 for i=1,26 do assert(fresh.cfg['f'..i]==false)end
''')
check('closing the trainer panel balances the installed Begin/End binding', '''
 close_window=true;callbacks.draw();close_window=false
 assert(window_depth==0 and table_depth==0 and child_depth==0)
''')
check('scrollbar styles remain scoped and project button copies the public repository URL', '''
 clipboard=nil;show_panel=true;callbacks.draw();show_panel=nil
 assert(clipboard==nil and color_depth==0 and style_depth==0)
 github_click=true;callbacks.draw();github_click=false
 assert(clipboard=='https://github.com/LQB9/RE2LegacyTrainer')
 assert(color_depth==0 and style_depth==0 and window_depth==0 and table_depth==0 and child_depth==0)
''')
lua.execute('legacy_settings=json_copy(api.cfg);legacy_settings.original_profile=1;legacy_settings.feature_keys_profile=nil;legacy_settings.f15=true;legacy_settings.v14=3;legacy_settings.back_key27=8;legacy_settings.back_mod27=0;legacy_settings.back_device27=1;for i=1,28 do legacy_settings["key"..i]=96+i%10;legacy_settings["keymods"..i]=4 end;files["re2_legacy_settings.json"]=legacy_settings')
upgraded=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg,save_settings=save_settings}\n')
assert all(upgraded['cfg']['key'+str(i)]==0 and upgraded['cfg']['keymods'+str(i)]==0 for i in range(1,29))
assert upgraded['cfg']['f15'] and upgraded['cfg']['v14']==3 and upgraded['cfg']['back_key27']==8 and upgraded['cfg']['back_device27']==1
assert upgraded['cfg']['feature_keys_profile']==1
upgraded['cfg']['key27']=118
upgraded['save_settings']()
upgraded_reload=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
assert upgraded_reload['cfg']['key27']==118 and upgraded_reload['cfg']['back_key27']==8
tests.append('legacy toggle hotkeys clear once without losing switches or action keys; newly assigned hotkeys survive reload');print('PASS',tests[-1])
(ROOT/'build').mkdir(exist_ok=True)
(ROOT/'build/lua_test_results.json').write_text(json.dumps({'passed':len(tests),'tests':tests},indent=2),encoding='utf8')
print('ALL PASSED',len(tests))
