DEST=/usr/local/bin
CFLAGS=-Wall

all: leafpak leafpak2

leafpak.o: leafpak.c leafpak.h
	$(CC) -c -Wall -g leafpak.c

main.o: main.c leafpak.h
	$(CC) -c -Wall -g main.c

leafpak: main.o leafpak.o
	$(CC) -o leafpak main.o leafpak.o

leafpak2: leafpak2.c
	$(CC) $(CFLAGS) -o leafpak2 leafpak2.c

clean:
	rm -f leafpak leafpak2 core a.out main.o leafpak.o

install: leafpak
	install -m 755 leafpak $(DEST)
