#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include "REFramework_API.h"
static REFOnPreApplicationEntryCb frame;
static REFOnPostApplicationEntryCb post_frame;
static bool register_frame(const char* name,REFOnPreApplicationEntryCb cb){if(strcmp(name,"UpdateScene"))return false;frame=cb;return true;}
static bool register_post_frame(const char* name,REFOnPostApplicationEntryCb cb){if(strcmp(name,"UpdateScene"))return false;post_frame=cb;return true;}
static REFrameworkManagedObjectHandle singleton(const char* name){(void)name;return NULL;}
static void logger(const char* format,...){va_list args;va_start(args,format);vprintf(format,args);va_end(args);puts("");}
int main(void) {
 CreateDirectoryW(L"reframework",NULL);
 HMODULE dll=LoadLibraryW(L"re2_legacy_native.dll");if(!dll){printf("load error %lu\n",GetLastError());return 1;}
 REFPluginRequiredVersionFn version_fn=(REFPluginRequiredVersionFn)GetProcAddress(dll,"reframework_plugin_required_version");
 REFPluginInitializeFn initialize=(REFPluginInitializeFn)GetProcAddress(dll,"reframework_plugin_initialize");
 if(!version_fn||!initialize)return 2;
 REFrameworkPluginVersion version={0};version_fn(&version);
 if(version.major!=1||version.minor!=10||strcmp(version.game_name,"RE2"))return 3;
 REFrameworkPluginFunctions functions={0};functions.log_info=logger;functions.on_pre_application_entry=register_frame;functions.on_post_application_entry=register_post_frame;
 REFrameworkSDKFunctions sdk_functions={0};sdk_functions.get_managed_singleton=singleton;
 REFrameworkSDKData sdk={0};sdk.functions=&sdk_functions;
 REFrameworkPluginInitializeParam api={0};api.version=&version;api.functions=&functions;api.sdk=&sdk;
 DeleteFileW(L"reframework/data/re2_legacy_native_status.json");
 if(!initialize(&api)||!frame||!post_frame)return 4;
 frame();post_frame();FILE* f=fopen("reframework/data/re2_legacy_native_status.json","rb");if(!f)return 5;
 char json[4096]={0};fread(json,1,sizeof(json)-1,f);fclose(f);
 if(!strstr(json,"\"version\":4")||!strstr(json,"\"player_ready\":false")||!strstr(json,"game image does not contain this hook site"))return 6;
 if(!strstr(json,"\"ready\":false,\"enabled\":false"))return 7;
 puts("PASS required version, initialize ABI, callback registration, absent player, incompatible image guard, status JSON");
 FILE* report=fopen("native_abi_test_results.json","wb");if(!report)return 8;
 fputs("{\"revision\":\"0.1.4\",\"passed\":6,\"native_version\":4,\"checks\":[\"uppercase RE2 and API 1.10\",\"plugin initialization ABI\",\"pre and post UpdateScene registration\",\"absent player\",\"incompatible image guard\",\"status JSON version 4\"]}",report);fclose(report);
 return 0;
}
