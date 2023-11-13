#include <stdio.h>
#include <pcap.h>
#include <errno.h>  // errno
#include <string.h> // char *strerror(int errnum);
#include <unistd.h>
#include <pthread.h>

#define PCAP_OPEN 1
#define PCAP_LOOP 2
#define INJECT 7

int read_exact(unsigned char *buf, int len)
{
    int i, got = 0;
    do
    {
        if ((i = read(3, buf + got, len - got)) <= 0)
            return (i);
        got += i;
    } while (got < len);

    return len;
}

int write_exact(unsigned char *buf, int len)
{
    int i, wrote = 0;

    do
    {
        if ((i = write(4, buf + wrote, len - wrote)) <= 0)
            return (i);
        wrote += i;
    } while (wrote < len);

    return len;
}

int read_cmd(unsigned char *buf)
{
    int len;

    if (read_exact(buf, 2) != 2)
        return (-1);
    len = (buf[0] << 8) | buf[1];
    return read_exact(buf, len);
}

int write_cmd(unsigned char *buf, int len)
{
    unsigned char li;

    li = (len >> 8) & 0xff;
    write_exact(&li, 1);

    li = len & 0xff;
    write_exact(&li, 1);

    return write_exact(buf, len);
}

void loop(u_char *data,
          const struct pcap_pkthdr *hdr,
          const u_char *packet)
{
    if (write_cmd((unsigned char *)packet, hdr->caplen) < 0)
    {
        if (errno != EPIPE)
            fprintf(stderr, "ERROR ON LOOP:%s\r\n", strerror(errno));
    }
}

void *do_pcap_loop(pcap_t *pcap_id)
{
    int ret;
    if ((ret = pcap_loop(pcap_id, -1, (pcap_handler)loop, NULL)) <= 0)
    {
        pcap_perror(pcap_id, "PCAP LOOP ERROR: ");
    }
    return NULL;
}

int main()
{
    int command, promisc, snaplen, ifacelen, sock, len, mtu, timeout_ms, packet_len;

    char *iface;
    char error_msg[PCAP_ERRBUF_SIZE];
    pcap_t *pcap_id;

    pthread_t thr;
    struct pcap_pkthdr hdr;
    //    struct ifreq ifr;
    unsigned char *packet;
    unsigned char buf[67000];

    while ((len = read_cmd(buf)) > 0)
    {
        command = buf[0];
        switch (command)
        {
        case PCAP_OPEN:
            snaplen = *((int *)&buf[1]);    // 32 bits SnapLen
            promisc = buf[5];               //  8 bits Promisc
            timeout_ms = *((int *)&buf[6]); // 32 bits TimeoutMs
            ifacelen = *((int *)&buf[10]);  // 32 bits length(Iface)
            buf[14 + ifacelen] = 0;
            iface = (char *)&buf[14]; // .. bits Iface name
            error_msg[0] = 0;
            pcap_id = pcap_open_live(iface, snaplen, promisc, timeout_ms,
                                     error_msg);

            if (pcap_id == NULL)
                fprintf(stderr, "Error:%s\n", error_msg);

            write_cmd((unsigned char *)&pcap_id, sizeof(pcap_t *));
            break;
        case PCAP_LOOP:
            fprintf(stderr, "will loop for\r\n");
            pcap_id = *((pcap_t **)(&buf[1]));
            pthread_create(&thr, NULL, (void *(*)(void *))do_pcap_loop, pcap_id);
            break;
        case INJECT:
            pcap_id = *((pcap_t **)(&buf[1]));
            packet_len = *((int *)&buf[1 + sizeof(void *)]);
            pcap_inject(pcap_id, &buf[5 + sizeof(void *)], packet_len);
            break;
        }
    }
    fprintf(stderr, "sniff will terminate...\r\n");
    return 0;
}
