#include <stdio.h>
#include <stdlib.h>

#include "leafpack.h"

#define SCNNUM 0x0a96
#define GET_SHORT(p) (((p)[1]<<8)|(p)[0])
#define GET_LONG(p) ((p)[3]<<24|(p)[2]<<16|(p)[1]<<8|(p)[0])

int
main(void)
{
    int i;
    int index;
    u_char *data;
    u_char *scn_data = NULL;
    u_char *scn_text = NULL;
    LeafPack *scnpack;
    char name[1024];

    scnpack = leafpack_new("LVNS3SCN.PAK");

    /* シナリオファイル名決定 */


    for (i=0;i<SCNNUM;i++) {
        sprintf(name, "%04x.SCN", i);
        if ((index  = leafpack_find(scnpack, name)) < 0 ||
            (data = leafpack_extract(scnpack, index, NULL)) == NULL) {
            fprintf(stderr, "can't load scenario %s\n", name);
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
}
