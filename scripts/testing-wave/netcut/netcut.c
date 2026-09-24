// Cuts the network for ONE app process on a simulator (IMPROVEMENTS #36, from ticket 20's run).
// Injected at launch with SIMCTL_CHILD_DYLD_INSERT_LIBRARIES; interposes connect/connectx.
// While the file named by NETCUT_FLAG exists, any non-loopback IPv4/IPv6 connect fails with
// ENETUNREACH. Blocked calls are appended to NETCUT_LOG when it is set. Driven by netcut.sh.
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define DYLD_INTERPOSE(_r,_o) __attribute__((used)) static struct{const void*r;const void*o;} _interpose_##_o __attribute__((section("__DATA,__interpose"))) = {(const void*)(unsigned long)&_r,(const void*)(unsigned long)&_o};
static int blocked(const struct sockaddr *a){
  const char *flag = getenv("NETCUT_FLAG");
  if(!a || !flag) return 0;
  if(access(flag, F_OK)!=0) return 0;
  if(a->sa_family==AF_INET){ const struct sockaddr_in*s=(const void*)a; if((ntohl(s->sin_addr.s_addr)>>24)==127) return 0; return 1; }
  if(a->sa_family==AF_INET6){ const struct sockaddr_in6*s=(const void*)a; if(IN6_IS_ADDR_LOOPBACK(&s->sin6_addr)) return 0;
    if(IN6_IS_ADDR_V4MAPPED(&s->sin6_addr) && s->sin6_addr.s6_addr[12]==127) return 0; return 1; }
  return 0;
}
static void note(const char*w){ const char*log=getenv("NETCUT_LOG"); if(!log) return; FILE*f=fopen(log,"a"); if(f){ fprintf(f,"%ld blocked %s pid %d\n",(long)time(NULL),w,getpid()); fclose(f);} }
int my_connect(int fd,const struct sockaddr*a,socklen_t l){ if(blocked(a)){ note("connect"); errno=ENETUNREACH; return -1;} return connect(fd,a,l); }
int my_connectx(int fd,const sa_endpoints_t*ep,sae_associd_t aid,unsigned int fl,const struct iovec*iov,unsigned int n,size_t*len,sae_connid_t*cid){
  if(ep && blocked(ep->sae_dstaddr)){ note("connectx"); errno=ENETUNREACH; return -1;} return connectx(fd,ep,aid,fl,iov,n,len,cid); }
DYLD_INTERPOSE(my_connect, connect)
DYLD_INTERPOSE(my_connectx, connectx)
