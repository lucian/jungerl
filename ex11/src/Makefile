### --------------------------------------------------------------------
### Created: 15 Feb 1999 by Tobbe tobbe@cslab.ericsson.se
###
### $Id: Makefile,v 1.1 2003/02/25 20:08:55 vladdu Exp $
### --------------------------------------------------------------------

include ../../../support/include.mk

# Change path if not the default compiler shall be used
ERLC = erlc
ERLC_FLAGS += -I ../include

MODNAME    = ex11
ERL_FILES  = ex11.erl ex11_client.erl ex11_proto.erl ex11_utils.erl ex11_xauth.erl \
             ex11_db.erl rcube.erl matrix44.erl
BEAM_FILES = $(ERL_FILES:.erl=.beam)

RELEASE_FILES = Makefile $(ERL_FILES) ex11.hrl ex11.pub README README.developers


.SUFFIXES: .3 .html .sgml .beam .hrl .erl

.erl.beam:
	-$(ERLC) $(ERLC_FLAGS) -W -o ../ebin $< 

all: beam

beam: $(BEAM_FILES)
	@echo " *** Compilation finished ***"

sgml: 
	-sgml_transform -m 3 m.sgml
	-sgml_transform -html m.sgml
	@echo " *** SGML processing finished ***"

clean:
	rm -f *.jam *.beam *sgmls*

$(ERL_FILES): ../include/ex11.hrl

#release:
#	$(CVS_CHECKED_IN) .. $(MODNAME)
#	@echo "*** Specify a release tag name (M-N), e.g 2-5 : "; read tag; \
#	$(MAKE) do_release "FREEZE_TAG=$$tag" DOT_TAG=`echo $$tag | sed -e 's/-/\./'`
#
#do_release:
#	cvs tag $(MODNAME)-$(FREEZE_TAG)
#	@tar -cf $(MODNAME)-$(DOT_TAG).tar $(RELEASE_FILES) 
#	@mkdir $(MODNAME)-$(DOT_TAG)
#	@mv $(MODNAME)-$(DOT_TAG).tar $(MODNAME)-$(DOT_TAG)
#	@(cd $(MODNAME)-$(DOT_TAG); \
#	 tar -xf $(MODNAME)-$(DOT_TAG).tar; rm -f $(MODNAME)-$(DOT_TAG).tar)
#	@tar -cf $(MODNAME)-$(DOT_TAG).tar $(MODNAME)-$(DOT_TAG)
#	@gzip $(MODNAME)-$(DOT_TAG).tar
#	@mv $(MODNAME)-$(DOT_TAG).tar.gz $(MODNAME)-$(DOT_TAG).tgz
#	@uuencode $(MODNAME)-$(DOT_TAG).tgz $(MODNAME)-$(DOT_TAG).tgz > $(MODNAME)-$(DOT_TAG).tgz.uu
#	@rm -fr $(MODNAME)-$(DOT_TAG)
#	@echo "*** Created file: $(MODNAME)-$(DOT_TAG).tgz"
#	@echo "***     and file: $(MODNAME)-$(DOT_TAG).tgz.uu"

