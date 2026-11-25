#include <wayland-client.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "pointer.h"
static struct zwlr_virtual_pointer_manager_v1 *manager;
static void global(void *data,struct wl_registry *reg,uint32_t name,const char *interface,uint32_t version){if(!strcmp(interface,"zwlr_virtual_pointer_manager_v1"))manager=wl_registry_bind(reg,name,&zwlr_virtual_pointer_manager_v1_interface,1);}
static void removed(void *data,struct wl_registry *reg,uint32_t name){}
int main(){struct wl_display *d=wl_display_connect(NULL);if(!d)return 1;struct wl_registry *r=wl_display_get_registry(d);struct wl_registry_listener l={global,removed};wl_registry_add_listener(r,&l,NULL);wl_display_roundtrip(d);if(!manager)return 2;struct zwlr_virtual_pointer_v1 *p=zwlr_virtual_pointer_manager_v1_create_virtual_pointer(manager,NULL);wl_display_roundtrip(d);puts("READY");fflush(stdout);char line[100],cmd;double x,y;while(fgets(line,sizeof(line),stdin)){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);uint32_t ms=t.tv_sec*1000+t.tv_nsec/1000000;if(sscanf(line,"%c %lf %lf",&cmd,&x,&y)<2)continue;if(cmd=='m')zwlr_virtual_pointer_v1_motion(p,ms,wl_fixed_from_double(x),wl_fixed_from_double(y));else if(cmd=='b')zwlr_virtual_pointer_v1_button(p,ms,272,(uint32_t)x);zwlr_virtual_pointer_v1_frame(p);wl_display_roundtrip(d);puts("OK");fflush(stdout);}wl_display_disconnect(d);}
