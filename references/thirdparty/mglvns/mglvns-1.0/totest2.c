#include <stdio.h>
#include <stdlib.h>

#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include "leafpack.h"

#define SCNNUM 0x0a96
#define GET_SHORT(p) (((p)[1]<<8)|(p)[0])
#define GET_LONG(p) ((p)[3]<<24|(p)[2]<<16|(p)[1]<<8|(p)[0])

int
main(int argc, char **argv)
{
    int fd;
    struct stat sb;
    u_char *addr;
    u_char *extract;

    if ((fd = open(argv[1], 0, O_RDONLY)) < 0) {
        perror(argv[1]);
        return NULL;
    }

    if (fstat(fd, &sb) < 0 ||
        (addr = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0))
        == MAP_FAILED) {
        perror("mmap");
        close(fd);
        return -1;
    }
    close(fd);    /* マップしたので不要 */


    } else {
        u_char *p_scn  = data + GET_SHORT(data) * 16;
        u_char *p_text = data + GET_SHORT(data+2) * 16;
        size_t size_scn  = GET_LONG(p_scn);
        size_t size_text = GET_LONG(p_text);
        
#if 0   
        fprintf(stderr, "size_scn: %d\n", size_scn);
#endif

        scn_data = realloc(scn_data, size_scn);
        scn_text = realloc(scn_text, size_text);

        /* lzs 展開 */
        leafpack_lzs2(p_scn  + 4, scn_data, size_scn);
        leafpack_lzs2(p_text + 4, scn_text, size_text);

        fprintf(stdout, "%s:%d %d\n", name, GET_SHORT(scn_data), GET_SHORT(scn_text));
    }
}
