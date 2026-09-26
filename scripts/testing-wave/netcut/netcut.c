// Cuts or slows the network for ONE app process on a simulator (IMPROVEMENTS #36, #92; Finding 111-004).
// Injected at launch with SIMCTL_CHILD_DYLD_INSERT_LIBRARIES; interposes connect/connectx. Driven by
// netcut.sh, which also runs the slow proxy (slowproxy.mjs).
//
// Offline (the file named by NETCUT_FLAG exists): any non-loopback IPv4/IPv6 connect fails with
// ENETUNREACH. A watcher thread also shuts down every socket this library let connect the moment
// the flag appears, so a keep-alive connection opened before the cut carries nothing after it.
//
// Slow (the file named by NETCUT_SLOW exists, holding "<ms> <port>"): a TCP connect to a
// non-loopback address goes to the host proxy on loopback <port> instead. Before connecting, the
// socket is bound so its source port is known, and "<source port> <host> <port>" is appended to
// NETCUT_MAP; the proxy reads that line to reach the real server and holds each reply chunk for
// <ms>. The connect itself returns at once, so no thread of the app ever sleeps (122-009: a
// sleep inside connect() blocked Dart's IO threads and failed TLS). UDP to port 443 (QUIC) is
// refused in slow mode, so HTTP/3 falls back to TCP and goes through the proxy too.
//
// Every event is appended to NETCUT_LOG when it is set.
#include <sys/socket.h>
#include <sys/stat.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <fcntl.h>
#include <pthread.h>
#define DYLD_INTERPOSE(_r,_o) __attribute__((used)) static struct{const void*r;const void*o;} _interpose_##_o __attribute__((section("__DATA,__interpose"))) = {(const void*)(unsigned long)&_r,(const void*)(unsigned long)&_o};

#define MAXFD 16384
// 0: not ours. 1: connected straight to a non-loopback address. >1: connected through the slow
// proxy, and the value is the proxy's port (so the watcher can tell it from any other loopback peer).
static volatile int tracked[MAXFD];

static void note(const char*fmt, ...) __attribute__((format(printf,1,2)));
#include <stdarg.h>
static void note(const char*fmt, ...){
  const char*log=getenv("NETCUT_LOG"); if(!log) return;
  FILE*f=fopen(log,"a"); if(!f) return;
  struct timespec ts; clock_gettime(CLOCK_REALTIME,&ts);
  fprintf(f,"%ld.%03ld ",(long)ts.tv_sec,ts.tv_nsec/1000000);
  va_list ap; va_start(ap,fmt); vfprintf(f,fmt,ap); va_end(ap);
  fprintf(f," pid %d\n",getpid()); fclose(f);
}

static int loopback(const struct sockaddr *a){
  if(a->sa_family==AF_INET){ const struct sockaddr_in*s=(const void*)a; return (ntohl(s->sin_addr.s_addr)>>24)==127; }
  if(a->sa_family==AF_INET6){ const struct sockaddr_in6*s=(const void*)a; if(IN6_IS_ADDR_LOOPBACK(&s->sin6_addr)) return 1;
    return IN6_IS_ADDR_V4MAPPED(&s->sin6_addr) && s->sin6_addr.s6_addr[12]==127; }
  return 1; // not IP (unix sockets): never ours
}
static int ip(const struct sockaddr *a){ return a && (a->sa_family==AF_INET || a->sa_family==AF_INET6); }
static int exists(const char*env){ const char*p=getenv(env); return p && access(p,F_OK)==0; }
static int offline(void){ return exists("NETCUT_FLAG"); }

/** The slow proxy's port from NETCUT_SLOW ("<ms> <port>"), or 0 when slow mode is off. */
static int slow_port(void){
  const char*p=getenv("NETCUT_SLOW"); if(!p) return 0;
  FILE*f=fopen(p,"r"); if(!f) return 0;
  int ms=0, port=0; if(fscanf(f,"%d %d",&ms,&port)!=2) port=0; fclose(f);
  return port>0 && port<65536 ? port : 0;
}
static int socktype(int fd){ int t=0; socklen_t l=sizeof t; if(getsockopt(fd,SOL_SOCKET,SO_TYPE,&t,&l)!=0) return -1; return t; }
static int port_of(const struct sockaddr*a){
  if(a->sa_family==AF_INET) return ntohs(((const struct sockaddr_in*)(const void*)a)->sin_port);
  return ntohs(((const struct sockaddr_in6*)(const void*)a)->sin6_port);
}
static void host_of(const struct sockaddr*a, char*buf, size_t n){
  if(a->sa_family==AF_INET) inet_ntop(AF_INET,&((const struct sockaddr_in*)(const void*)a)->sin_addr,buf,(socklen_t)n);
  else inet_ntop(AF_INET6,&((const struct sockaddr_in6*)(const void*)a)->sin6_addr,buf,(socklen_t)n);
}
static void track(int fd,int v){ if(fd>=0 && fd<MAXFD) tracked[fd]=v; }

/**
 * Slow mode for one TCP connect: bind for a known source port, tell the proxy where the socket
 * really goes, and fill [to] with the proxy's loopback address. 0 when the socket goes through
 * the proxy, -1 to connect straight (any step failed: better unslowed than broken).
 */
static int via_proxy(int fd, const struct sockaddr*dst, int port, struct sockaddr_storage*to, socklen_t*tolen){
  struct sockaddr_storage me; socklen_t ml=sizeof me;
  if(getsockname(fd,(struct sockaddr*)&me,&ml)!=0) return -1;
  if(port_of((struct sockaddr*)&me)==0){
    struct sockaddr_storage any; memset(&any,0,sizeof any);
    if(dst->sa_family==AF_INET){ struct sockaddr_in*s=(void*)&any; s->sin_family=AF_INET; s->sin_len=sizeof *s; }
    else { struct sockaddr_in6*s=(void*)&any; s->sin6_family=AF_INET6; s->sin6_len=sizeof *s; }
    if(bind(fd,(struct sockaddr*)&any,any.ss_len)!=0) return -1;
    ml=sizeof me; if(getsockname(fd,(struct sockaddr*)&me,&ml)!=0) return -1;
  }
  const char*map=getenv("NETCUT_MAP"); if(!map) return -1;
  char host[INET6_ADDRSTRLEN]; host_of(dst,host,sizeof host);
  int m=open(map,O_WRONLY|O_APPEND|O_CREAT,0644); if(m<0) return -1;
  char line[128]; int n=snprintf(line,sizeof line,"%d %s %d\n",port_of((struct sockaddr*)&me),host,port_of(dst));
  ssize_t w=write(m,line,(size_t)n); close(m); if(w!=n) return -1;
  memset(to,0,sizeof *to);
  if(dst->sa_family==AF_INET){ struct sockaddr_in*s=(void*)to; s->sin_family=AF_INET; s->sin_len=sizeof *s; s->sin_port=htons((uint16_t)port); s->sin_addr.s_addr=htonl(INADDR_LOOPBACK); *tolen=sizeof *s; }
  else { struct sockaddr_in6*s=(void*)to; s->sin6_family=AF_INET6; s->sin6_len=sizeof *s; s->sin6_port=htons((uint16_t)port); s->sin6_addr=in6addr_loopback; *tolen=sizeof *s; }
  note("slow fd %d -> %s:%d via proxy :%d", fd, host, port_of(dst), port);
  return 0;
}

/** What to do with a connect to [a]: 0 straight, 1 refuse, >1 through the proxy on that port. */
static int decide(int fd,const struct sockaddr*a,const char*what){
  if(!ip(a) || loopback(a)) return 0;
  char host[INET6_ADDRSTRLEN]; host_of(a,host,sizeof host);
  if(offline()){ note("blocked %s -> %s:%d", what, host, port_of(a)); return 1; }
  int port=slow_port(); if(!port) return 0;
  int t=socktype(fd);
  if(t==SOCK_STREAM) return port;
  if(t==SOCK_DGRAM && port_of(a)==443){ note("blocked %s udp :443 (slow mode: QUIC falls back to TCP)", what); return 1; }
  return 0;
}

int my_connect(int fd,const struct sockaddr*a,socklen_t l){
  int d=decide(fd,a,"connect");
  if(d==1){ errno=ENETUNREACH; return -1; }
  if(d>1){
    struct sockaddr_storage to; socklen_t tl;
    if(via_proxy(fd,a,d,&to,&tl)==0){
      int r=connect(fd,(struct sockaddr*)&to,tl);
      if(r==0 || errno==EINPROGRESS) track(fd,d);
      return r;
    }
  }
  int r=connect(fd,a,l);
  if(ip(a) && (r==0 || errno==EINPROGRESS)) track(fd, loopback(a) ? 0 : 1);
  return r;
}

int my_connectx(int fd,const sa_endpoints_t*ep,sae_associd_t aid,unsigned int fl,const struct iovec*iov,unsigned int n,size_t*len,sae_connid_t*cid){
  const struct sockaddr*a = ep ? ep->sae_dstaddr : NULL;
  int d = a ? decide(fd,a,"connectx") : 0;
  if(d==1){ errno=ENETUNREACH; return -1; }
  if(d>1 && !ep->sae_srcaddr){
    struct sockaddr_storage to; socklen_t tl;
    if(via_proxy(fd,a,d,&to,&tl)==0){
      sa_endpoints_t e=*ep; e.sae_dstaddr=(struct sockaddr*)&to; e.sae_dstaddrlen=tl;
      int r=connectx(fd,&e,aid,fl,iov,n,len,cid);
      if(r==0 || errno==EINPROGRESS) track(fd,d);
      return r;
    }
  }
  int r=connectx(fd,ep,aid,fl,iov,n,len,cid);
  if(ip(a) && (r==0 || errno==EINPROGRESS)) track(fd, loopback(a) ? 0 : 1);
  return r;
}
DYLD_INTERPOSE(my_connect, connect)
DYLD_INTERPOSE(my_connectx, connectx)

/**
 * Shut down every socket this library let connect, still open and still going where it went
 * (an fd may since have been closed and reused for a file or another socket, so each is checked).
 */
static int cut_open_sockets(void){
  int cut=0;
  for(int fd=0; fd<MAXFD; fd++){
    int v=tracked[fd]; if(!v) continue;
    tracked[fd]=0;
    struct stat st; if(fstat(fd,&st)!=0 || !S_ISSOCK(st.st_mode)) continue;
    struct sockaddr_storage p; socklen_t pl=sizeof p;
    if(getpeername(fd,(struct sockaddr*)&p,&pl)!=0 || !ip((struct sockaddr*)&p)) continue;
    int lb=loopback((struct sockaddr*)&p);
    if(v==1 ? lb : (!lb || port_of((struct sockaddr*)&p)!=v)) continue;
    char host[INET6_ADDRSTRLEN]; host_of((struct sockaddr*)&p,host,sizeof host);
    if(shutdown(fd,SHUT_RDWR)==0){ cut++; note("closed fd %d (open to %s:%d before the cut)", fd, host, port_of((struct sockaddr*)&p)); }
  }
  return cut;
}

/** Watches the offline flag every 50 ms; on each appearance, cuts the sockets already open. */
static void* watcher(void*unused){
  (void)unused;
  int was=offline();
  for(;;){
    usleep(50*1000);
    int now=offline();
    if(now && !was) note("cut: %d open socket(s) shut down", cut_open_sockets());
    was=now;
  }
  return NULL;
}
__attribute__((constructor)) static void start(void){
  if(!getenv("NETCUT_FLAG")) return;
  pthread_t t; if(pthread_create(&t,NULL,watcher,NULL)==0) pthread_detach(t);
}
