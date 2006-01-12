#
# $Id: Makefile,v 1.3 2006/01/12 19:23:33 asergey Exp $
#

include ../vsn.mk
include ../../../support/include.mk
ERLC_FLAGS  += -I../include
ERL_OBJECTS += $(EBIN_DIR)/lama.app

all: $(ERL_OBJECTS)

clean:
	-rm $(ERL_OBJECTS)
