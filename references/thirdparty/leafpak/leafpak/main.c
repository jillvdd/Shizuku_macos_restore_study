/*
 * main.c
 * 10/06/1997 by TF <tf@imou.to>
*/

/*
 * Usage
 * leafpak [ehlvx] file.pak [file1 file2 ...]
 *    e,x: extract files
 *    l:   show file table
 *    v:   verbose mode
 *    h:   show help message
 */

#include <stdio.h>
#include <string.h>

#define MAIN
#include "leafpak.h"

static void usage_exit(void);

#define USAGE "leafpak [ehlvx] file.pak [file1 file2 ...]\n"

int main(int argc, char *argv[])
{
  LEAFPACK *lp;
  int mode, verbose = FALSE;
  int i;
  char *pak;

  switch (argc) {
  case 1:
    /* no file or option is specified */
    usage_exit();
    break;
  case 2:
    /* filename or option is specified. */
    mode = LIST;
    pak = argv[1];
    break;
  default:
    /* option and archive file should be specified. */
    /* in this case, an 'x' option exract whole archive. */
    pak = argv[2];
    if (!strncmp(argv[1], "h", 1)) {
      usage_exit();
    } else if (!strncmp(argv[1], "v", 1)) {
      verbose = TRUE;
    } else if (!strncmp(argv[1], "l", 1)) {
      /* list mode has priority to extract mode */
      mode = LIST;
    } else if (!strncmp(argv[1], "e", 1) || !strncmp(argv[1], "x", 1)) {
      mode = EXTRACT;
    } else {
      /* bad option */
      usage_exit();
    }
  }
  
  lp = leafpack_open(pak);
  if (lp == NULL) {
    exit(1);
  }

  print_type(lp);

  switch (mode) {
  case LIST:
    print_table(lp, verbose);
    break;
  case EXTRACT:
    if (argc == 3) {
      printf("Extract whole archive.\n");
      extract_all(lp);
    } else {
      for (i = 3; i < argc; i++) {
	leafpack_extract_file(lp, argv[i]);
      }
    }
    break;
  default:
    /* sholud not reach here. */
    fprintf(stderr, "Unexpected error.\n");
    exit(1);
  }
  
  leafpack_close(lp);
  
  return 0;
}

static void usage_exit()
{
  fprintf(stderr, USAGE);
  exit(1);
}

/* end of file */
