SBIN_DIR ?= /usr/sbin
USR_DIR ?= /usr

mkfile_path := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

test_local:
	( for f in $$(ls -t t/environ/*.sh); do bash -x $$f && continue; echo FAIL $$f; exit 1 ; done )

# test_container:
#	( cd t/environ; for f in *.sh; do ./$$f && continue; echo FAIL $$f; exit 1 ; done )

test_system:
	( cd t/system; for f in *.sh; do ./$$f && continue; echo FAIL $$f; exit 1 ; done )

install:
	for i in lib script; do \
		mkdir -p "${DESTDIR}"/usr/share/sypper/$$i ;\
		[ ! -e $$i ] || cp -a $$i/* "${DESTDIR}"/usr/share/sypper/$$i ;\
	done
	chmod +x "${DESTDIR}"/usr/share/sypper/script/*
	# install -d -m 755 "${DESTDIR}"/usr/lib/systemd/system
	# for i in dist/systemd/*.service; do \
	#	install -m 644 $$i "${DESTDIR}"/usr/lib/systemd/system ;\
	# done
	install -D -m 755 -d "${DESTDIR}"/etc/sypper

