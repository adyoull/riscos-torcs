#ifndef FAKE_KERNEL_H
#define FAKE_KERNEL_H
typedef struct { int r[10]; } _kernel_swi_regs;
typedef struct { int errnum; char errmess[252]; } _kernel_oserror;
_kernel_oserror *_kernel_swi(int, _kernel_swi_regs *, _kernel_swi_regs *);
_kernel_oserror *_kernel_swi_c(int, _kernel_swi_regs *, _kernel_swi_regs *, int *);
#endif
