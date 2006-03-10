# Makefile for the LAMA application maintained in Jungerl
#
# $Id: Makefile,v 1.3 2006/03/10 18:59:34 asergey Exp $
# $Url$
#

#include ../../support/subdir.mk
APP_NAME=lama

all:
	(cd src;$(MAKE))

clean:
	(cd src;$(MAKE) clean)

release: clean appfile
	sh ../../support/create_release.sh

appfile:
	(cd src;$(MAKE) ../ebin/$(APP_NAME).app)

docs:
	erl -noshell -run edoc_run application "'$(APP_NAME)'" \
       '"."' '[{def,{vsn,"$(VSN)"}}]' -s init stop
