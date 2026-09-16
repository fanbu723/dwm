# dwm - dynamic window manager
# See LICENSE file for copyright and license details.

include config.mk

SRC = drw.c dwm.c util.c
OBJ = ${SRC:.c=.o}

# 附加目标（dwmblocks / 会话文件 / 自启脚本）使用的路径
DWMBLOCKS_DIR  = dwmblocks
XSESSIONS_DIR  = /usr/share/xsessions
AUTOSTART_DIR ?= ${HOME}/.dwm
AUTOSTART_FILE = autostart.sh

all: options dwm

options:
	@echo dwm build options:
	@echo "CFLAGS   = ${CFLAGS}"
	@echo "LDFLAGS  = ${LDFLAGS}"
	@echo "CC       = ${CC}"

.c.o:
	${CC} -c ${CFLAGS} $<

${OBJ}: config.h config.mk

config.h:
	cp config.def.h $@

dwm: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

clean:
	rm -f dwm ${OBJ} dwm-${VERSION}.tar.gz

dist: clean
	mkdir -p dwm-${VERSION}
	cp -R LICENSE Makefile README.md config.def.h config.mk install.sh\
		autostart.sh scripts patches dwm.1 drw.h util.h ${SRC} dwm.png\
		transient.c dwm-${VERSION}
	tar -cf dwm-${VERSION}.tar dwm-${VERSION}
	gzip dwm-${VERSION}.tar
	rm -rf dwm-${VERSION}

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f dwm ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/dwm
	mkdir -p ${DESTDIR}${MANPREFIX}/man1
	sed "s/VERSION/${VERSION}/g" < dwm.1 > ${DESTDIR}${MANPREFIX}/man1/dwm.1
	chmod 644 ${DESTDIR}${MANPREFIX}/man1/dwm.1

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/dwm\
		${DESTDIR}${MANPREFIX}/man1/dwm.1

# ---- dwmblocks ------------------------------------------------------------
install-dwmblocks:
	${MAKE} -C ${DWMBLOCKS_DIR} install PREFIX=${PREFIX}

uninstall-dwmblocks:
	${MAKE} -C ${DWMBLOCKS_DIR} uninstall PREFIX=${PREFIX}

# ---- XSession 会话文件（写入 /usr/share，需要 root）-----------------------
install-session:
	mkdir -p ${DESTDIR}${XSESSIONS_DIR}
	cp -f dwm.desktop ${DESTDIR}${XSESSIONS_DIR}/dwm.desktop
	chmod 644 ${DESTDIR}${XSESSIONS_DIR}/dwm.desktop

uninstall-session:
	rm -f ${DESTDIR}${XSESSIONS_DIR}/dwm.desktop

# ---- 自启脚本与状态栏脚本（部署到 ~/.dwm，blocks.h 中路径与此对应）-------
install-scripts:
	mkdir -p ${AUTOSTART_DIR}/scripts
	cp -f ${AUTOSTART_FILE} ${AUTOSTART_DIR}/${AUTOSTART_FILE}
	chmod 755 ${AUTOSTART_DIR}/${AUTOSTART_FILE}
	cp -f scripts/*.sh ${AUTOSTART_DIR}/scripts/
	chmod 755 ${AUTOSTART_DIR}/scripts/*.sh

uninstall-scripts:
	rm -rf ${AUTOSTART_DIR}

# ---- 组合目标（通常用 ./install.sh 代替）----------------------------------
# install-all 需要 root：sudo make install-all
install-all: install install-dwmblocks install-session install-scripts

uninstall-all: uninstall uninstall-dwmblocks uninstall-session uninstall-scripts

.PHONY: all options clean dist install uninstall \
	install-dwmblocks uninstall-dwmblocks \
	install-session uninstall-session \
	install-scripts uninstall-scripts \
	install-all uninstall-all
