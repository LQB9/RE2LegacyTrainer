import sys,pathlib,json,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
from lupa.lua54 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
files={};hooks={};callbacks={};storage={};drawn={};down_keys={};ui_inputs={}
function json_copy(v)
 if type(v)~='table'then return v end
 local out={};for k,item in pairs(v)do out[k]=json_copy(item)end;return out
end
reframework={get_game_name=function()return 're2'end,is_key_down=function(_,k)return down_keys[k]or false end}
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
 find_type_definition=function(n)return {get_method=function(_,m)return {get_function=function()return n..'.'..m end}end}end,
 hook=function(m,pre,post) hooks[m:get_function()]={pre=pre,post=post}end}
window_depth=0;table_depth=0;child_depth=0;color_depth=0;style_depth=0
imgui={tree_node=function()return true end,tree_pop=function()end,text=function()end,
 button=function(name)return name:match('##select_feature(%d+)')==tostring(feature_click)or(binding_click~=nil and name:match('##bind_(.+)')==binding_click)or(github_click and name:find('##github_project',1,true)~=nil)end,
 checkbox=function(name,v)if name:match('##feature')then table.insert(drawn,name)else table.insert(ui_inputs,name)end;if name:find('##panel_visible',1,true)and show_panel~=nil then return true,show_panel end;return false,v end,
 drag_int=function(n,v)table.insert(ui_inputs,n);return false,v end,slider_float=function(n,v)table.insert(ui_inputs,n);return false,v end,
 slider_int=function(n,v)table.insert(ui_inputs,n);return false,v end,
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
api=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg,update=update,restore=restore,status=status,defs=defs}\n')
lua.globals().api=api
tests=[]
def check(name,source):
    lua.execute(source);tests.append(name);print('PASS',name)
check('all 26 effects disabled and listed once in the original order', '''
 for i=1,26 do assert(api.cfg['f'..i]==false)end
 local seen={}
 callbacks.draw()
 for _,name in ipairs(drawn)do local id=tonumber(name:match('##feature(%d+)'));assert(not seen[id]);seen[id]=true end
 assert(#drawn==26);for i=1,26 do assert(seen[i]and tonumber(drawn[i]:match('##feature(%d+)'))==i)end
 assert(window_depth==0 and table_depth==0 and child_depth==0)
''')
original=json.loads((ROOT/'tests/fixtures/original_settings.json').read_text(encoding='utf8'))
payload=json.loads((ROOT/'tests/fixtures/original_features.json').read_text(encoding='utf8'))
for row in original:
    if row['SetIndex']==0 and 1<=row['Id']<=26:
        assert api['cfg']['key'+str(row['Id'])]==row['KeyConfig']['KeyCode']
        assert api['cfg']['keymods'+str(row['Id'])]==row['KeyConfig']['ModifierKeys']
for row in payload['cheats']:
    if 1<=row['id']<=26:
        assert api['defs'][row['id']][1]==row['label'] and api['defs'][row['id']][2]==row['label2']
tests.append('source EXE labels and local original default shortcuts match all 26 rows');print('PASS',tests[-1])
check('selected options retain all original visible parameters without a height-distance control', '''
 for id=1,26 do feature_click=id;callbacks.draw()end;feature_click=nil
 local seen={};for _,name in ipairs(ui_inputs)do seen[name:match('##(.+)')]=true end
 for _,key in ipairs({'all1','v7','v8','time9_1','time9_2','time9_3','v10','v11','v12','v13','v14',
  'freeUD15','v16','h16','aimReset16','smooth16','change16','v17','v20','v22','vol22'})do assert(seen[key],key)end
 assert(not seen.height_step15 and not seen.height_amount15)
 assert(window_depth==0 and table_depth==0 and child_depth==0)
''')
check('original shortcuts distinguish left and right modifiers and debounce toggles', '''
 down_keys={[163]=true,[97]=true};callbacks.frame();assert(api.cfg.f1==false)
 down_keys={};callbacks.frame();down_keys={[162]=true,[97]=true};callbacks.frame();assert(api.cfg.f1)
 callbacks.frame();assert(api.cfg.f1);down_keys={};callbacks.frame()
 down_keys={[91]=true,[97]=true};callbacks.frame();assert(api.cfg.f21)
 down_keys={};callbacks.frame();api.cfg.f1=false;api.cfg.f21=false
''')
check('managed runtime fixture', '''
 hp=object({[backing('CurrentHitPoint')]=1200,[backing('Invincible')]=false})
 equipment=object({_ReticleFitPoint=.1,_IsReticleFit=false})
 layers=object({mCount=3})
 handle=object({[backing('LayerNos')]=layers})
 orderer=object({[backing('RejectPrecedeOrdersTrackHandle')]=handle})
 player=object({[backing('HitPointController')]=hp,[backing('Equipment')]=equipment,
 [backing('ActionOrderer')]=orderer,_IsPoison=true,_DopingTimer=0},{set_IsPoison=function(self,value)self.fields._IsPoison=value end})
 pm=object({[backing('Pedometer')]=100},{get_CurrentPlayerCondition=function()return player end})
 inv=object({_CurrentSlotSize=8});singleton('PlayerManager',pm)
 singleton('gamemastering.InventoryManager',object({[backing('CurrentInventory')]=inv}))
 clock_data=object({_GameElapsedTime=123,_DemoSpendingTime=15,_InventorySpendingTime=25,_PauseSpendingTime=35})
 singleton('GameClock',object({_GameSaveData=clock_data}))
 save_data=object({SaveTimes=6});singleton('gamemastering.MainFlowManager',object({gameHeaderSaveData=save_data}))
 records=object({OpenItemBox=12,UseHealItem=14});singleton('gamemastering.RecordManager',object({gameSaveData=records}))
 rank=object({[backing('IsRankPointFix')]=false,[backing('RankPoint')]=4000});singleton('GameRankSystem',rank)
 enemies=object({_IsInvisible=false});singleton('EnemyManager',enemies)
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
check('Escape cancels binding, Backspace clears it, and reload retains shortcuts', '''
 binding_click='load_key15';callbacks.draw();binding_click=nil;down_keys={[27]=true};callbacks.frame()
 assert(api.cfg.load_key15==117)
 down_keys={};callbacks.frame();binding_click='load_key15';callbacks.draw();binding_click=nil
 down_keys={[8]=true};callbacks.frame();assert(api.cfg.load_key15==0 and api.cfg.load_mod15==0)
 down_keys={};callbacks.frame()
''')
# Use a separate fixture to verify a real reload, leaving the current callback set intact.
lua.execute('original_callbacks={};for k,v in pairs(callbacks)do original_callbacks[k]=v end')
persisted=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
assert persisted['cfg']['save_key15']==75 and persisted['cfg']['save_mod15']==4
assert persisted['cfg']['load_key15']==0 and persisted['cfg']['up_key15']==118 and persisted['cfg']['down_key15']==119
assert persisted['cfg']['f15']==True
assert all(persisted['cfg']['f'+str(i)]==api['cfg']['f'+str(i)] for i in range(1,27))
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
 expected_switches={};for i=1,26 do expected_switches[i]=api.cfg['f'..i]end
 callbacks.reset();for i=1,26 do assert(api.cfg['f'..i]==false)end
 assert(files['re2_legacy_native.json'].f8==false and files['re2_legacy_native.json'].f14==false and files['re2_legacy_native.json'].f15==false and files['re2_legacy_native.json'].f22==false)
 for i=1,26 do assert(files['re2_legacy_settings.json']['f'..i]==expected_switches[i])end
''')
reset_reload=lua.execute((ROOT/'src/re2_legacy_trainer.lua').read_text(encoding='utf8')+'\nreturn {cfg=cfg}\n')
lua.globals().reset_reload=reset_reload
check('reload after script teardown restores the saved selections and parameters', '''
 for i=1,26 do assert(reset_reload.cfg['f'..i]==expected_switches[i])end
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
(ROOT/'build').mkdir(exist_ok=True)
(ROOT/'build/lua_test_results.json').write_text(json.dumps({'passed':len(tests),'tests':tests},indent=2),encoding='utf8')
print('ALL PASSED',len(tests))
