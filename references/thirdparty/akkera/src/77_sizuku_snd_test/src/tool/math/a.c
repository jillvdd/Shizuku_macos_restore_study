#include <stdio.h>
#include <math.h>

int main(int argc, char* argv[])
{
    FILE *fp;
    int i;
    double sn;
    char str[80];
    
    if((fp=fopen("m_Sintbl.txt","w"))!=NULL){

        fprintf(fp, "short m_Sintbl[] = {\n");

        for(i=0; i<256; i++){
            sn = (double)(sin( 3.1415926536 * (double)i / 128));
            sprintf(str, "\t%4.0f,\t\t/* no.%3d */\n", (sn * 128) / 2, i);
            
            fprintf(fp, str);
            printf("%s", str);
        }
        fprintf(fp, "};\n");
        fclose(fp);
    }
    return 0;
}
