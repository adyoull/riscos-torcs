/* Host test of plib's RISC OS joystick back end (patches/plib 10 and 11)
   with a pretend Joystick module (kernel.h here stands in for UnixLib's).
   Modes: 0 USBJoystick's slot API answering properly; 1 Joystick_AxisInfo
   pointing at unmapped memory (a forum user's module: TORCS 1.3.7-riscos6
   aborted at race start); 2 no Joystick module; 3 a huge axis count. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "kernel.h"
#include "js.h"
static _kernel_oserror err = {1, "no"};
static int mode; /* 0 good USBJoystick, 1 Doug: bad AxisInfo pointer, 2 no module, 3 huge count */
static int reads;
struct Dev { uint32_t size; const char *m,*p,*s; uint32_t v,pid,na,nb,nh; } dev = {sizeof(Dev),"m","Pad",0,0,0,2,4,0};
struct Ax { uint32_t page,usage,type; const char*n; int32_t mn,md,mx,dig; } ax[2] = {{1,0x30,5,"X",0,128,255,0},{1,0x31,6,"Y",0,128,255,0}};
int32_t vals[2] = {200,50};
static const char *bad = (const char *)0x02f074a8;
_kernel_oserror *_kernel_swi(int n, _kernel_swi_regs *i, _kernel_swi_regs *o){
  if (mode==2) return &err;
  switch(n){
  case 0x43F44: o->r[0]=1; o->r[1]=1; return 0;
  case 0x43F45: o->r[2]=(int)(intptr_t)&dev; return 0;
  case 0x43F46: o->r[1]=sizeof(Ax); o->r[2]= mode==3? 100000:2; o->r[3]= mode==1? (int)(intptr_t)bad : (int)(intptr_t)ax; return 0;
  case 0x43F47: o->r[1]=4; o->r[2]=2; o->r[3]=(int)(intptr_t)vals; o->r[4]=5; return 0;
  case 0x43F40: reads++; o->r[0]=(40000<<16)|30000; o->r[1]=3; return 0;
  }
  return &err;
}
_kernel_oserror *_kernel_swi_c(int n, _kernel_swi_regs *i, _kernel_swi_regs *o, int *c){
  if (n!=0x3A) return &err;
  uintptr_t a=(uint32_t)i->r[0], e=(uint32_t)i->r[1];
  /* readable: anything not in the "bad" range 0x02000000-0x03000000 */
  *c = (a < 0x03000000 && e > 0x02000000) ? 1 : 0; return 0;
}
/* One case per run (the "slot API failed" flag is global, as on RISC OS):
   test_joystick MODE prints what jsJoystick(0) found and read. */
int main(int argc,char**argv){
  if (argc < 2) return 2;
  mode=atoi(argv[1]);
  jsJoystick j(0);
  int b=-1; float a[_JS_MAX_AXES]={0};
  j.rawRead(&b,a);
  printf("working=%d name='%s' axes=%d buttons=%d b=%d a0=%g a1=%g\n",!j.notWorking(),j.getName(),j.getNumAxes(),j.getNumButtons(),b,a[0],a[1]);
  return 0;
}
