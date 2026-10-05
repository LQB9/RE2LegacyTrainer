// Exercise the actual C action processing and SDK invocation with a synthetic player.
#ifdef NDEBUG
#undef NDEBUG
#endif
#include <assert.h>
#define MH_QueueEnableHook fixture_enable
#define MH_QueueDisableHook fixture_disable
#define MH_ApplyQueued fixture_apply
#include "re2_legacy_native.c"
MH_STATUS WINAPI fixture_enable(LPVOID p){(void)p;return MH_OK;}
MH_STATUS WINAPI fixture_disable(LPVOID p){(void)p;return MH_OK;}
MH_STATUS WINAPI fixture_apply(void){return MH_OK;}
static unsigned char fixture_transform[0x110],fixture_go[0x30],fixture_hp[0x30];
static uintptr_t fixture_globals[16],fixture_hp_field,fixture_handler_field;
static unsigned char fixture_event;
static unsigned char fixture_cave[1024];
static int setters,invoke_failure,controller_syncs;
static float controller_position[4];
static REFrameworkManagedObjectHandle singleton_mock(const char* name) {
    return !strcmp(name,"app.ropeway.PlayerManager")?(void*)1:NULL;
}
static REFrameworkTDBHandle tdb_mock(void){return (void*)1;}
static REFrameworkMethodHandle find_method_mock(REFrameworkTDBHandle t,const char* name,const char* method) {
    (void)t;(void)name;(void)method;return (void*)1;
}
static bool managed_mock(void* o){return o!=NULL;}
static REFrameworkTypeDefinitionHandle type_mock(REFrameworkManagedObjectHandle o){(void)o;return (void*)1;}
static REFrameworkFieldHandle find_field_mock(REFrameworkTypeDefinitionHandle t,const char* name) {
    (void)t;return (void*)(uintptr_t)(!strcmp(name,"<HitPointController>k__BackingField")?1:!strcmp(name,"<IsEvent>k__BackingField")?2:!strcmp(name,"<CharacterHandler>k__BackingField")?3:0);
}
static void* data_mock(REFrameworkFieldHandle f,void* o,bool is_static) {
    (void)o;(void)is_static;return (uintptr_t)f==1?(void*)&fixture_hp_field:(uintptr_t)f==3?(void*)&fixture_handler_field:(void*)&fixture_event;
}
static REFrameworkResult invoke_mock(REFrameworkMethodHandle m,void* object,void** args,unsigned int args_size,void* out,unsigned int out_size) {
    assert(out_size==136);memset(out,0,out_size);
    if((uintptr_t)m==1){assert(!args&&args_size==0);*(void**)out=(void*)2;return REFRAMEWORK_ERROR_NONE;}
    if((uintptr_t)m==3){assert(object==fixture_transform&&!args);memcpy(out,fixture_transform+0x30,12);((float*)out)[0]+=100;return REFRAMEWORK_ERROR_NONE;}
    if((uintptr_t)m==5){
        assert(object==(void*)2&&args_size==sizeof(void*)&&!group(15)->enabled);
        if(invoke_failure)return REFRAMEWORK_ERROR_EXCEPTION;
        memcpy(fixture_transform+0x30,args[0],16);((float*)(fixture_transform+0x30))[0]-=100;
        memcpy(controller_position,fixture_transform+0x30,16);controller_syncs++;setters++;return REFRAMEWORK_ERROR_NONE;
    }
    assert((uintptr_t)m==2&&object==fixture_transform&&args_size==sizeof(void*));
    if(invoke_failure)return REFRAMEWORK_ERROR_EXCEPTION;
    memcpy(fixture_transform+0x30,args[0],16);setters++;return REFRAMEWORK_ERROR_NONE;
}
static void setup(void) {
    static REFrameworkSDKFunctions functions={0};functions.get_managed_singleton=singleton_mock;functions.get_tdb=tdb_mock;
    static REFrameworkTDB tdb={0};tdb.find_method=find_method_mock;
    static REFrameworkManagedObject managed={0};managed.is_managed_object=managed_mock;managed.get_type_definition=type_mock;
    static REFrameworkTDBTypeDefinition type={0};type.find_field=find_field_mock;
    static REFrameworkTDBField field_api={0};field_api.get_data_raw=data_mock;
    static REFrameworkTDBMethod method={0};method.invoke=invoke_mock;
    static REFrameworkSDKData sdk={0};sdk.functions=&functions;sdk.tdb=&tdb;sdk.managed_object=&managed;sdk.type_definition=&type;sdk.field=&field_api;sdk.method=&method;
    api_copy.sdk=&sdk;api=&api_copy;globals=fixture_globals;player_state=(void*)(globals+8);event_state=(void*)(globals+9);
    fixture_hp_field=(uintptr_t)fixture_hp;
    fixture_handler_field=3;
    *(uintptr_t*)(fixture_hp+0x10)=(uintptr_t)fixture_go;*(uintptr_t*)(fixture_go+0x18)=(uintptr_t)fixture_transform;
    Group* g=group(15);g->ready=1;g->enabled=1;g->cave=fixture_cave;g->error="";
    transform_set_position=(void*)2;fixture_event=0;invoke_failure=0;setters=controller_syncs=0;memset(controller_position,0,sizeof(controller_position));
    cancel_flight(1);flight_enabled=0;flight_sequence=0;legacy15_requested=1;transform_get_world_position=(void*)3;survivor_set_position=(void*)5;
    reset_teleport();teleport_saved=0;teleport_free=0;teleport_amount=1.6f;memset(commands,0,sizeof(commands));
}
static void pos(float x,float y,float z){float p[4]={x,y,z,0};memcpy(fixture_transform+0x30,p,sizeof(p));}
static float coord(int index){float value;memcpy(&value,fixture_transform+0x30+index*4,4);return value;}
static void tick(void){after_update();}
static void require_position(float x,float y,float z){assert(fabsf(coord(0)-x)<.00001f&&fabsf(coord(1)-y)<.00001f&&fabsf(coord(2)-z)<.00001f);}
static void config(const char* json) {
    wcscpy(config_path,L"native_actions_fixture.json");FILE* f=_wfopen(config_path,L"wb");assert(f);fputs(json,f);fclose(f);
    memset(&last_file,0,sizeof(last_file));poll_config();DeleteFileW(config_path);
}
int main(void) {
    setup();pos(38.094814f,2,-14.528539f);tick();teleport_pending[0]=1;tick();
    assert(teleport_saved&&setters==0);pos(99,-4,121);teleport_pending[1]=1;
    for(int i=0;i<16;i++){if(i)pos(coord(0)+.002f,coord(1)-.001f,coord(2)-.003f);tick();require_position(38.094814f,2,-14.528539f);}
    assert(teleport_settle==0&&setters==16);pos(38.2f,2,-14.5f);tick();require_position(38.2f,2,-14.5f);
    puts("PASS saved XYZ are restored through residual movement and horizontal movement resumes");

    setup();pos(3,1000,4);tick();teleport_pending[2]=1;
    for(int i=0;i<16;i++)tick();require_position(3,1001.6f,4);assert(!teleport_frames);
    teleport_pending[3]=1;for(int i=0;i<16;i++)tick();require_position(3,1000,4);
    puts("PASS original rise/fall distance is 1.6 over 16 frames, including large heights");

    setup();pos(3,2,4);tick();teleport_pending[0]=1;tick();teleport_pending[1]=1;tick();
    assert(teleport_settle==15);teleport_pending[2]=2;tick();assert(!teleport_settle);
    for(int i=1;i<16;i++){pos(coord(0)+.01f,coord(1),coord(2));tick();}
    require_position(3.15f,5.2f,4);
    teleport_pending[2]=1;tick();teleport_pending[3]=1;for(int i=0;i<16;i++)tick();require_position(3.15f,5.2f,4);
    puts("PASS queued presses keep their total distance, can reverse, and preserve horizontal movement");

    setup();pos(3,2,4);tick();teleport_pending[0]=1;tick();teleport_pending[1]=1;tick();
    fixture_event=1;tick();assert(!teleport_settle&&!teleport_frames&&!teleport_valid);
    fixture_event=0;tick();teleport_pending[2]=1;tick();group(15)->enabled=0;tick();assert(!teleport_valid&&!teleport_frames);
    group(15)->enabled=1;tick();int before=setters;tick();assert(setters==before);
    puts("PASS events and feature disable discard pending movement and settling");

    setup();config("{\"f15\":true,\"height_step15\":0.1,\"up15\":3}");
    assert(fabsf(teleport_amount-1.6f)<.000001f&&teleport_pending[2]==3);
    config("{\"f15\":true,\"height_step15\":0.1,\"up15\":3}");assert(teleport_pending[2]==3);
    reset_teleport();config("{\"f15\":true,\"height_step15\":0.1,\"up15\":0}");assert(!teleport_pending[2]);
    config("{\"f15\":true,\"height_step15\":0.1}");assert(fabsf(teleport_amount-1.6f)<.000001f);
    config("{\"f15\":true,\"height_step15\":0.0001}");assert(fabsf(teleport_amount-.16f)<.000001f);
    puts("PASS configuration total distance, command debounce, reset counters and legacy compatibility");

    setup();pos(3,2,4);tick();teleport_pending[2]=1;invoke_failure=1;tick();
    assert(!group(15)->ready&&!teleport_valid);
    puts("PASS SDK setter failure rejects the feature");
    setup();pos(3,2,4);config("{\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":120,\"fly27_y\":9,\"fly27_z\":6,\"fly27_interp\":true}");
    for(int i=0;i<30;i++){tick();assert(controller_syncs==i+1);}
    require_position(20,9,6);assert(!flight_active&&flight_saved&&flight_step==30);
    // The physics controller feeds its cached position back on later updates.
    // A Transform-only implementation would revert to the previous position.
    for(int i=0;i<16;i++){memcpy(fixture_transform+0x30,controller_position,16);tick();require_position(20,9,6);}
    assert(!flight_active&&!group(15)->enabled&&flight_saved);
    capture_player();tick();assert(flight_saved);
    config("{\"f27\":true,\"fly27_seq\":2,\"fly27_kind\":2}");for(int i=0;i<17;i++)tick();require_position(3,2,4);
    assert(!flight_saved&&!flight_active&&controller_syncs==31);
    assert(controller_position[0]==3&&controller_position[1]==2&&controller_position[2]==4);
    puts("PASS world targets and return synchronize both transform and physics controller with scene parents");

    setup();pos(1,2,3);config("{\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":104,\"fly27_y\":5,\"fly27_z\":6,\"fly27_interp\":false}");tick();require_position(4,5,6);
    config("{\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":900}");assert(!flight_pending);
    config("{\"f27\":true,\"fly27_seq\":2,\"fly27_kind\":0}");assert(!flight_active&&flight_saved);
    config("{\"f27\":false,\"fly27_seq\":2}");assert(!flight_saved);
    puts("PASS direct flight, duplicate rejection, stop and feature disable");

    setup();pos(1,2,3);config("{\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":104}");tick();fixture_event=1;tick();assert(!flight_active&&!flight_saved);
    fixture_event=0;config("{\"f27\":true,\"fly27_seq\":2,\"fly27_kind\":1,\"fly27_x\":104}");tick();
    config("{\"f15\":true,\"f27\":true,\"fly27_seq\":2,\"up15\":1}");assert(!flight_active&&!flight_pending);tick();assert(teleport_frames==15);
    config("{\"f15\":true,\"f27\":true,\"fly27_seq\":0}");assert(!flight_saved&&!flight_pending);
    puts("PASS event cancellation, legacy movement priority and reload sequence reset");

    setup();pos(1,2,3);config("{\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":104}");invoke_failure=1;tick();assert(group(15)->ready&&!flight_saved&&!flight_active&&strlen(flight_error)>0);
    puts("PASS flight SDK failure cancels flight without disabling the original noclip feature");

    setup();pos(1,2,3);config("{\"f15\":true,\"freeUD15\":true,\"f27\":true,\"fly27_seq\":1,\"fly27_kind\":1,\"fly27_x\":110,\"fly27_y\":9,\"fly27_z\":6,\"fly27_interp\":false}");
    assert(!group(15)->enabled&&legacy15_requested&&teleport_free);
    tick();require_position(10,9,6);assert(controller_syncs==1&&group(15)->enabled&&teleport_free&&group(15)->cave[16]);
    puts("PASS legacy collision hooks are suspended during the synchronized teleport and restored afterwards");

    FILE* result=fopen("native_action_test_results.json","wb");assert(result);
    fputs("{\"revision\":\"0.1.6\",\"passed\":11,\"tests\":[\"save and load with 16 frames of residual motion\",\"original 0.1 times 16 rise and fall at large heights\",\"queued presses, reversal and horizontal movement\",\"cancel on events and disable\",\"config distance, counters and legacy compatibility\",\"SDK invocation failure guard\",\"world target and exact local return synchronize physics\",\"direct flight debounce stop disable\",\"events legacy priority reload\",\"flight SDK failure leaves legacy features ready\",\"suspend collision hooks during survivor teleport and restore previous state\"]}",result);fclose(result);
    return 0;
}
