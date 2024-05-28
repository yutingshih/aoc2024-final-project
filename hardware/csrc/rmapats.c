// file = 0; split type = patterns; threshold = 100000; total count = 0.
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "rmapats.h"

void  schedNewEvent (struct dummyq_struct * I1423, EBLK  * I1418, U  I626);
void  schedNewEvent (struct dummyq_struct * I1423, EBLK  * I1418, U  I626)
{
    U  I1697;
    U  I1698;
    U  I1699;
    struct futq * I1700;
    struct dummyq_struct * pQ = I1423;
    I1697 = ((U )vcs_clocks) + I626;
    I1699 = I1697 & ((1 << fHashTableSize) - 1);
    I1418->I668 = (EBLK  *)(-1);
    I1418->I669 = I1697;
    if (0 && rmaProfEvtProp) {
        vcs_simpSetEBlkEvtID(I1418);
    }
    if (I1697 < (U )vcs_clocks) {
        I1698 = ((U  *)&vcs_clocks)[1];
        sched_millenium(pQ, I1418, I1698 + 1, I1697);
    }
    else if ((peblkFutQ1Head != ((void *)0)) && (I626 == 1)) {
        I1418->I671 = (struct eblk *)peblkFutQ1Tail;
        peblkFutQ1Tail->I668 = I1418;
        peblkFutQ1Tail = I1418;
    }
    else if ((I1700 = pQ->I1325[I1699].I691)) {
        I1418->I671 = (struct eblk *)I1700->I689;
        I1700->I689->I668 = (RP )I1418;
        I1700->I689 = (RmaEblk  *)I1418;
    }
    else {
        sched_hsopt(pQ, I1418, I1697);
    }
}
#ifdef __cplusplus
extern "C" {
#endif
void SinitHsimPats(void);
#ifdef __cplusplus
}
#endif
