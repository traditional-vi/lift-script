# Makefile for ex-vi conversion using reposurgeon
#
# Steps to using this:
# 1. Make sure reposurgeon and repotool are on your $PATH.
# 2. (Skip this step if you're starting from a stream file.) For svn, set
#    REMOTE_URL to point at the remote repository you want to convert;
#    you can use either an svn: URL or an rsync: URL for this.
#    If the repository is already in a DVCS such as hg or git,
#    set REMOTE_URL to either the normal cloning URL (starting with hg://,
#    git://, etc.) or to the path of a local clone.
# 3. For cvs, set CVS_HOST to the repo hostname and CVS_MODULE to the module,
#    then uncomment the line that builds REMOTE_URL
#    Note: for CVS hosts other than Sourceforge or Savannah you will need to
#    include the path to the CVS modules directory after the hostname.
# 4. Set any required read options, such as --user-ignores
#    by setting READ_OPTIONS.
# 5. Optionally, replace the default value of DUMPFILTER with a
#    command or pipeline that actually filters the dump rather than
#    just copying it through.  The most usual reason to do this is
#    that your Subversion repository is multiproject and you want to
#    strip out one subtree for conversion with repocutter sift and pop
#    commands.  Note that if you ever did copies across project
#    subtrees this simple stripout will not work - you are in deep
#    trouble and should find an expert to advise you
# 6. Run 'make stubmap' to create a stub author map.
# 7. Run 'make' to build a converted repository.
#
# For a production-quality conversion you will need to edit the map
# file and the lift script.  During the process you can set EXTRAS to
# name extra metadata such as a comments message-box that the final.
# conversion depends on.
#
# Afterwards, you can use the *compare productions to check your work.
#

EXTRAS =
CVS_HOST = ex-vi.cvs.sourceforge.net
CVS_MODULE = ex-vi
REMOTE_URL = cvs://$(CVS_HOST)/ex-vi\#$(CVS_MODULE)
READ_OPTIONS =
#CHECKOUT_OPTIONS = --ignore-externals
DUMPFILTER = cat
VERBOSITY = "set progress"
REPOSURGEON = reposurgeon
LOGFILE = conversion.log

# Set and uncomment these if remote access tio Subversion needs credentials.
#export RUSERNAME=
#export RPASSWORD=

# Configuration ends here

.PHONY: local-clobber remote-clobber gitk gc compare clean stubmap

default: ex-vi-git

# Build the repository from the stream dump
ex-vi-git: ex-vi.cvs ex-vi.opts ex-vi.lift ex-vi.map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) 'logfile $(LOGFILE)' 'script ex-vi.opts' "read $(READ_OPTIONS) <ex-vi.cvs" 'authors read <ex-vi.map' 'sourcetype cvs' 'prefer git' 'script ex-vi.lift' 'legacy write >ex-vi.fo' 'rebuild ex-vi-git'

# Build a stream dump from the local mirror
ex-vi.cvs: ex-vi-mirror
	(cd ex-vi-mirror/ >/dev/null; repotool export) | $(DUMPFILTER) >ex-vi.cvs

# Build a local mirror of the remote repository
ex-vi-mirror:
	repotool mirror $(REMOTE_URL) ex-vi-mirror

# Make a local checkout of the source mirror for inspection
%-checkout: %-mirror
	cd %-mirror >/dev/null; repotool checkout $(CHECKOUT_OPTIONS) $(PWD)/%-checkout

# Force rebuild of stream from the local mirror on the next make
local-clobber: clean
	rm -fr ex-vi.fi ex-vi-git

# Force full rebuild from the remote repo on the next make.
remote-clobber: local-clobber
	rm -fr ex-vi.cvs *-mirror *-checkout

# Get the (empty) state of the author mapping from the first-stage stream
stubmap: ex-vi.cvs
	$(REPOSURGEON) $(VERBOSITY) "read $(READ_OPTIONS) <ex-vi.cvs" 'authors write >ex-vi.map'

# Compare the histories of the unconverted and converted repositories at head
# and all tags.
headcompare: ex-vi-mirror ex-vi-git
	repotool compare ex-vi-mirror ex-vi-git
tagscompare: ex-vi-mirror ex-vi-git
	repotool compare-tags ex-vi-mirror ex-vi-git
branchescompare: ex-vi-mirror ex-vi-git
	repotool compare-branches ex-vi-mirror ex-vi-git
allcompare: ex-vi-mirror ex-vi-git
	repotool compare-all ex-vi-mirror ex-vi-git

# General cleanup and utility
clean:
	rm -fr *~ .rs* ex-vi-conversion.tar.gz *.cvs *.fi *.fo

#
# The following productions are git-specific
#

# Browse the generated git repository
gitk: ex-vi-git
	cd ex-vi-git; gitk --all

# Run a garbage-collect on the generated git repository.  Import doesn't.
# This repack call is the active part of gc --aggressive.  This call is
# tuned for very large repositories.
gc: ex-vi-git
	cd ex-vi-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250
