#
# $Id: Makefile,v 1.4 2006/03/10 18:59:35 asergey Exp $
#

include ../vsn.mk
include ../../../support/include.mk
ERLC_FLAGS  += -I../include
ERL_OBJECTS += $(EBIN_DIR)/lama.app

all: $(ERL_OBJECTS)

clean:
	-rm $(ERL_OBJECTS)
