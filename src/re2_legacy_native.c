#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "REFramework_API.h"
#include "MinHook.h"

typedef struct {int offset;int value;} Relocation;
typedef struct {uint32_t rva;int length,entry,back;const unsigned char* signature;int branch,origin;} HookSpec;
typedef struct {int id;const unsigned char* source;size_t size;const Relocation* globals;int ng;const HookSpec* sites;int ns;unsigned char* cave;int ready,enabled;const char* error;} Group;
#include "native_generated.h"
static const REFrameworkPluginInitializeParam* api;
static REFrameworkPluginInitializeParam api_copy;
static uintptr_t image;
static size_t image_size;
static uintptr_t* globals;
static uint64_t* player_state;
static uint64_t* event_state;
static wchar_t config_path[MAX_PATH],status_path[MAX_PATH],temporary_path[MAX_PATH];
static ULONGLONG last_poll,last_status;
static FILETIME last_file;
static unsigned commands[4];
static unsigned teleport_pending[4];
static uintptr_t teleport_transform;
static int teleport_valid,teleport_saved,teleport_frames,teleport_free,teleport_settle;
static float teleport_load_position[4];
static double teleport_y,teleport_target_y;
static float teleport_amount=1.6f;
static REFrameworkMethodHandle transform_set_position;

static int readable(const void* p,size_t n) {
    MEMORY_BASIC_INFORMATION m;
    if(!p||!VirtualQuery(p,&m,sizeof(m))||m.State!=MEM_COMMIT||m.Protect&(PAGE_NOACCESS|PAGE_GUARD)) return 0;
    return (uintptr_t)p+n<=(uintptr_t)m.BaseAddress+m.RegionSize;
}
static uintptr_t readptr(uintptr_t p) {return readable((void*)p,8)?*(uintptr_t*)p:0;}
static void* field(void* object,const char* name) {
    if(!object||!api->sdk->managed_object->is_managed_object(object))return NULL;
    REFrameworkTypeDefinitionHandle t=api->sdk->managed_object->get_type_definition(object);
    for(int i=0;t&&i<12;i++,t=api->sdk->type_definition->get_parent_type(t)) {
        REFrameworkFieldHandle f=api->sdk->type_definition->find_field(t,name);
        if(f)return api->sdk->field->get_data_raw(f,object,false);
    }
    return NULL;
}
static void capture_player(void) {
    uintptr_t hp=0,transform=0;*player_state=0;*event_state=0;
    void* pm=api->sdk->functions->get_managed_singleton("app.ropeway.PlayerManager");
    if(pm) {
        REFrameworkTDBHandle tdb=api->sdk->functions->get_tdb();
        REFrameworkMethodHandle method=api->sdk->tdb->find_method(tdb,"app.ropeway.PlayerManager","get_CurrentPlayerCondition");
        unsigned char out[136]={0};
        if(method&&api->sdk->method->invoke(method,pm,NULL,0,out,sizeof(out))==REFRAMEWORK_ERROR_NONE&&!out[128]) {
            void* condition=*(void**)out;
            void* f=field(condition,"<HitPointController>k__BackingField");
            if(f)hp=readptr((uintptr_t)f);
            uintptr_t game_object=readptr(hp+0x10);
            transform=readptr(game_object+0x18);
            if(!readable((void*)transform,0x60))transform=0;
            void* event=field(condition,"<IsEvent>k__BackingField");
            if(event&&readable(event,1))*event_state=*(unsigned char*)event?1:0;
        }
    }
    globals[0]=(uintptr_t)player_state;globals[8/8]=hp;
    globals[16/8]=transform;globals[24/8]=transform?transform+0x50:0;
    globals[32/8]=(uintptr_t)event_state;
    *player_state=(hp&&transform)?1:0;
}
static unsigned char* near_alloc(size_t size) {
    SYSTEM_INFO info;GetSystemInfo(&info);
    uintptr_t base=image&~((uintptr_t)info.dwAllocationGranularity-1);
    for(uintptr_t delta=0x100000;delta<0x60000000;delta+=info.dwAllocationGranularity) {
        unsigned char* p=VirtualAlloc((void*)(base+delta),size,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE);
        if(p)return p;
        if(base>delta) {p=VirtualAlloc((void*)(base-delta),size,MEM_RESERVE|MEM_COMMIT,PAGE_EXECUTE_READWRITE);if(p)return p;}
    }
    return NULL;
}
static int rel32(unsigned char* destination,int64_t value) {
    if(value<INT32_MIN||value>INT32_MAX)return 0;
    int32_t v=(int32_t)value;memcpy(destination,&v,4);return 1;
}
static void prepare(Group* g) {
    g->error="signature mismatch or another mod has hooked this site";
    for(int i=0;i<g->ns;i++) {
        if((size_t)g->sites[i].rva+24>image_size){g->error="game image does not contain this hook site";return;}
        if(memcmp((void*)(image+g->sites[i].rva),g->sites[i].signature,24))return;
    }
    g->cave=near_alloc(g->size);
    if(!g->cave){g->error="near allocation failed";return;}
    memcpy(g->cave,g->source,g->size);
    for(int i=0;i<g->ng;i++) {
        const Relocation* r=&g->globals[i];
        if(!rel32(g->cave+r->offset,(int64_t)(uintptr_t)globals-(int64_t)(uintptr_t)g->cave+r->value)){g->error="global relocation out of range";return;}
    }
    for(int i=0;i<g->ns;i++) {
        const HookSpec* h=&g->sites[i];uintptr_t a=image+h->rva;
        if(!rel32(g->cave+h->back+1,(int64_t)(a+h->length)-(int64_t)(uintptr_t)(g->cave+h->back+5))){g->error="return relocation out of range";return;}
        if(h->branch>=0) {
            unsigned char* original=(unsigned char*)(a+h->origin);
            if(*original!=0xe8&&*original!=0xe9){g->error="unexpected original branch";return;}
            int32_t old;memcpy(&old,original+1,4);
            int destination=h->entry+h->branch;
            if(!rel32(g->cave+destination,(int64_t)(uintptr_t)(original+5+old)-(int64_t)(uintptr_t)(g->cave+destination+4))){g->error="branch relocation out of range";return;}
        }
    }
    FlushInstructionCache(GetCurrentProcess(),g->cave,g->size);
    for(int i=0;i<g->ns;i++) {
        const HookSpec* h=&g->sites[i];void* original;
        MH_STATUS result=MH_CreateHook((void*)(image+h->rva),g->cave+h->entry,&original);
        if(result!=MH_OK) {
            for(int j=0;j<i;j++)MH_RemoveHook((void*)(image+g->sites[j].rva));
            g->error=MH_StatusToString(result);return;
        }
    }
    g->ready=1;g->error="";
}
static Group* group(int id) {for(size_t i=0;i<sizeof(groups)/sizeof(groups[0]);i++)if(groups[i].id==id)return &groups[i];return NULL;}
static double number(const char* json,const char* key,double fallback) {
    char token[64];snprintf(token,sizeof(token),"\"%s\"",key);
    const char* p=strstr(json,token);if(!p)return fallback;p=strchr(p,':');if(!p)return fallback;
    p++;while(*p==' '||*p=='\r'||*p=='\n'||*p=='\t')p++;
    if(!strncmp(p,"true",4))return 1;if(!strncmp(p,"false",5))return 0;
    char* end;double v=strtod(p,&end);return end!=p&&isfinite(v)?v:fallback;
}
static float bounded(const char* json,const char* key,float fallback,float low,float high) {double v=number(json,key,fallback);return (float)(v<low?low:v>high?high:v);}
static void set_float(Group* g,int offset,float v) {if(g&&g->ready)memcpy(g->cave+offset,&v,4);}
static void enable(Group* g,int enabled) {
    if(!g->ready||g->enabled==enabled)return;
    for(int i=0;i<g->ns;i++) {
        MH_STATUS result=enabled?MH_QueueEnableHook((void*)(image+g->sites[i].rva)):MH_QueueDisableHook((void*)(image+g->sites[i].rva));
        if(result!=MH_OK){g->error=MH_StatusToString(result);return;}
    }
    MH_STATUS result=MH_ApplyQueued();
    if(result==MH_OK)g->enabled=enabled;else g->error=MH_StatusToString(result);
}
static void poll_config(void) {
    WIN32_FILE_ATTRIBUTE_DATA attr;FILETIME now;GetSystemTimeAsFileTime(&now);
    uint64_t current=((uint64_t)now.dwHighDateTime<<32)|now.dwLowDateTime;
    int fresh=GetFileAttributesExW(config_path,GetFileExInfoStandard,&attr);
    uint64_t modified=fresh?((uint64_t)attr.ftLastWriteTime.dwHighDateTime<<32)|attr.ftLastWriteTime.dwLowDateTime:0;
    fresh=fresh&&current>=modified&&current-modified<50000000;
    if(!fresh){for(int i=0;i<4;i++)enable(&groups[i],0);return;}
    if(CompareFileTime(&last_file,&attr.ftLastWriteTime)==0)return;
    char json[4096]={0};FILE* f=_wfopen(config_path,L"rb");if(!f)return;
    size_t n=fread(json,1,sizeof(json)-1,f);fclose(f);if(!n||!strchr(json,'}'))return;
    last_file=attr.ftLastWriteTime;
    Group* g8=group(8);Group* g14=group(14);Group* g15=group(15);Group* g22=group(22);
    set_float(g8,0,bounded(json,"v8",15,1,50));set_float(g14,0,bounded(json,"v14",2,.5f,5));
    set_float(g22,0,bounded(json,"v22",1,.1f,5));if(g22->ready)g22->cave[4]=number(json,"vol22",0)!=0;
    if(g15->ready) {
        teleport_free=number(json,"freeUD15",0)!=0;
        g15->cave[16]=teleport_free;
        // Preserve the original hidden hchang: 0.1 for each of 16 update frames.
        teleport_amount=16*bounded(json,"height_step15",.1f,.01f,5);
        set_float(g15,28,teleport_amount/16);
        const char* keys[]={"save15","load15","up15","down15"};
        for(int i=0;i<4;i++) {
            unsigned seq=(unsigned)number(json,keys[i],0);
            if(seq>commands[i]&&number(json,"f15",0)!=0) {
                unsigned count=seq-commands[i];
                teleport_pending[i]+=count<32?count:32;
            }
            commands[i]=seq;
        }
        // Let the legacy sites suppress their original position writers. Process
        // coordinate actions after UpdateScene, after the current engine's ground fix.
        memset(g15->cave+17,0,4);memset(g15->cave+24,0,4);
    }
    for(int i=0;i<4;i++){char k[16];snprintf(k,sizeof(k),"f%d",groups[i].id);enable(&groups[i],number(json,k,0)!=0);}
}
static void reset_teleport(void) {
    teleport_valid=0;teleport_frames=0;teleport_settle=0;
    memset(teleport_pending,0,sizeof(teleport_pending));
}
static int teleport_position(Group* g,uintptr_t transform,float position[4]) {
    if(!teleport_valid||teleport_transform!=transform) {
        teleport_transform=transform;teleport_valid=1;
        teleport_y=teleport_target_y=position[1];teleport_frames=0;teleport_settle=0;
    }
    if(teleport_settle)memcpy(position,teleport_load_position,16);
    if(teleport_pending[0]){memcpy(g->cave,position,16);teleport_saved=1;}
    int loaded=teleport_pending[1]&&teleport_saved;
    if(loaded) {
        memcpy(teleport_load_position,g->cave,16);memcpy(position,teleport_load_position,16);
        teleport_y=teleport_target_y=position[1];teleport_frames=0;teleport_settle=16;
    }
    int direction=(int)teleport_pending[2]-(int)teleport_pending[3];
    if(direction) {
        if(!teleport_frames)teleport_target_y=teleport_y;
        teleport_target_y+=direction*(double)teleport_amount;
        teleport_frames=16;teleport_settle=0;
    }
    memset(teleport_pending,0,sizeof(teleport_pending));
    // Keep all three saved coordinates briefly while residual movement settles.
    // Rise/fall, a new transform, events or disabling the feature cancel this hold.
    if(teleport_settle){teleport_settle--;return 1;}
    int moving=teleport_frames!=0;
    if(moving) {
        teleport_y+=(teleport_target_y-teleport_y)/teleport_frames;
        if(!--teleport_frames)teleport_y=teleport_target_y;
    }
    if(!teleport_free&&!moving&&!loaded){teleport_y=teleport_target_y=position[1];return 0;}
    position[1]=(float)teleport_y;return 1;
}
static void after_update(void) {
    Group* g=group(15);
    if(g->ready&&g->enabled)capture_player();
    if(!g->ready||!g->enabled||!*player_state||*event_state||!transform_set_position||!readable((void*)globals[2],0x60)) {
        reset_teleport();return;
    }
    float position[4];memcpy(position,(void*)(globals[2]+0x30),16);
    if(!teleport_position(g,globals[2],position))return;
    void* args[]={position};unsigned char out[136]={0};
    REFrameworkResult result=api->sdk->method->invoke(transform_set_position,(void*)globals[2],args,sizeof(args),out,sizeof(out));
    if(result!=REFRAMEWORK_ERROR_NONE||out[128]){g->error="native transform position setter failed";enable(g,0);g->ready=0;teleport_valid=0;}
}
static void write_status(void) {
    FILE* f=_wfopen(temporary_path,L"wb");if(!f)return;
    fprintf(f,"{\"version\":4,\"player_ready\":%s,\"features\":{",*player_state?"true":"false");
    for(int i=0;i<4;i++)fprintf(f,"%s\"%d\":{\"ready\":%s,\"enabled\":%s,\"error\":\"%s\"}",i?",":"",groups[i].id,groups[i].ready?"true":"false",groups[i].enabled?"true":"false",groups[i].error?groups[i].error:"");
    Group* g=group(15);float p[3]={0};if(g->ready)memcpy(p,g->cave,12);
    for(int i=0;i<3;i++)if(!isfinite(p[i]))p[i]=0;
    float current_position[3]={0};
    if(*player_state&&readable((void*)globals[2],0x40))memcpy(current_position,(void*)(globals[2]+0x30),12);
    for(int i=0;i<3;i++)if(!isfinite(current_position[i]))current_position[i]=0;
    fprintf(f,"},\"saved_valid\":%s,\"load_settle_frames\":%d,\"saved\":[%.9g,%.9g,%.9g],\"position\":[%.9g,%.9g,%.9g]}",teleport_saved?"true":"false",teleport_settle,p[0],p[1],p[2],current_position[0],current_position[1],current_position[2]);fclose(f);
    MoveFileExW(temporary_path,status_path,MOVEFILE_REPLACE_EXISTING);
}
static void on_update(void) {
    capture_player();ULONGLONG now=GetTickCount64();
    // Poll action counters each scene update while teleport is enabled, so a
    // save press does not capture a position up to 100 ms later while walking.
    if(group(15)->enabled||now-last_poll>=100){last_poll=now;poll_config();}
    if(now-last_status>=1000){last_status=now;write_status();}
}
__declspec(dllexport) void reframework_plugin_required_version(REFrameworkPluginVersion* version) {
    version->major=REFRAMEWORK_PLUGIN_VERSION_MAJOR;version->minor=REFRAMEWORK_PLUGIN_VERSION_MINOR;version->patch=REFRAMEWORK_PLUGIN_VERSION_PATCH;version->game_name="RE2";
}
__declspec(dllexport) bool reframework_plugin_initialize(const REFrameworkPluginInitializeParam* parameters) {
    if(!parameters||!parameters->sdk||!parameters->functions)return false;
    api_copy=*parameters;api=&api_copy;image=(uintptr_t)GetModuleHandleW(NULL);
    IMAGE_DOS_HEADER* dos=(IMAGE_DOS_HEADER*)image;
    if(dos->e_magic!=IMAGE_DOS_SIGNATURE)return false;
    IMAGE_NT_HEADERS64* nt=(IMAGE_NT_HEADERS64*)(image+dos->e_lfanew);
    if(nt->Signature!=IMAGE_NT_SIGNATURE)return false;
    image_size=nt->OptionalHeader.SizeOfImage;
    wchar_t root[MAX_PATH];GetModuleFileNameW(NULL,root,MAX_PATH);wchar_t* slash=wcsrchr(root,L'\\');if(!slash)return false;*slash=0;
    swprintf(config_path,MAX_PATH,L"%ls\\reframework\\data",root);CreateDirectoryW(config_path,NULL);
#if defined(RE2_LIVE_TEST) && RE2_LIVE_TEST>=4
    swprintf(config_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v4_native.json",root);
    swprintf(status_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v4_native_status.json",root);
#elif defined(RE2_LIVE_TEST) && RE2_LIVE_TEST>=3
    swprintf(config_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v3_native.json",root);
    swprintf(status_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v3_native_status.json",root);
#elif defined(RE2_LIVE_TEST)
    swprintf(config_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v2_native.json",root);
    swprintf(status_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_v2_native_status.json",root);
#else
    swprintf(config_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_native.json",root);
    swprintf(status_path,MAX_PATH,L"%ls\\reframework\\data\\re2_legacy_native_status.json",root);
#endif
    swprintf(temporary_path,MAX_PATH,L"%ls.tmp",status_path);
    globals=(uintptr_t*)near_alloc(4096);if(!globals)return false;
    player_state=(uint64_t*)(globals+8);event_state=(uint64_t*)(globals+9);globals[0]=(uintptr_t)player_state;globals[4]=(uintptr_t)event_state;
    MH_STATUS init=MH_Initialize();if(init!=MH_OK&&init!=MH_ERROR_ALREADY_INITIALIZED)return false;
    for(int i=0;i<4;i++)prepare(&groups[i]);
    if(group(15)->ready) {
        // The legacy movement sites operate on Transform's local position.
        // Use the matching setter so parent transforms do not shift world coordinates.
        transform_set_position=api->sdk->tdb->find_method(api->sdk->functions->get_tdb(),"via.Transform","set_LocalPosition");
        if(!transform_set_position){group(15)->ready=0;group(15)->error="native transform position setter missing";}
    }
    api->functions->log_info("[RE2 Legacy] Native helper loaded; all four feature groups initially disabled");
    return api->functions->on_pre_application_entry("UpdateScene",on_update)&&api->functions->on_post_application_entry("UpdateScene",after_update);
}
