# export SVN_REPO_BASE=. if you want to use the local version instead of trunk
# from the subversion repository.

PYTHON_EXE ?= python3
# use something like "VERSION=0.2 make" to override the VERSION on the command line
VERSION = $(shell $(PYTHON_EXE) -c 'import pycam; print(pycam.VERSION)')
VERSION_FILE = pycam/Version.py
REPO_TAGS ?= https://pycam.svn.sourceforge.net/svnroot/pycam/tags
DIST_DIR = dist
DIST_PREFIX = pycam-
DIST_TGZ = $(DIST_DIR)/$(DIST_PREFIX)$(VERSION).tar.gz
DIST_WIN32 = $(DIST_DIR)/$(DIST_PREFIX)$(VERSION).win32.exe
# check if the local version of python's distutils support "--plat-name"
# (introduced in python 2.6)
DISTUTILS_PLAT_NAME = $(shell $(PYTHON_EXE) setup.py --help build_ext \
		      | grep -q -- "--plat-name" && echo "--plat-name win32")
PYTHON_CHECK_STYLE_TARGETS = pycam pyinstaller/hooks/hook-pycam.py setup.py
SPELLING_PATHS = \
	Changelog \
	docs \
	INSTALL.md \
	LICENSE.TXT \
	Makefile \
	man \
	pycam \
	README.md \
	release_info.txt \
	scripts \
	setup.py \
	technical_details.txt

# default location of mkdocs' build process
MKDOCS_SOURCE_DIR = docs
MKDOCS_EXPORT_DIR = site
MKDOCS_SOURCE_FILES = Makefile mkdocs.yml Changelog $(shell find "$(MKDOCS_SOURCE_DIR)" -type f)
MKDOCS_BUILD_STAMP = $(MKDOCS_EXPORT_DIR)/.build-stamp
# specify the remote user (e.g. for sourceforge: user,project) via ssh_config or directly on the
# commandline: "make upload-docs SF_USER=foobar"
ifdef SF_USER
WEBSITE_UPLOAD_PREFIX ?= $(SF_USER),pycam@
endif
WEBSITE_UPLOAD_LOCATION ?= web.sourceforge.net:/home/project-web/pycam/htdocs

RM = rm -f

.PHONY: build clean dist tgz win32 clean \
	docs man upload-docs \
	check-style pylint-relaxed pylint-strict test \
	update-version update-deb-changelog

info:
	@echo "Available targets:"
	@echo "    build"
	@echo "    clean"
	@echo "    dist"
	@echo "    docs"
	@echo "    man"
	@echo "    upload-docs"
	@echo
	@echo "Style checks:"
	@echo "    check-spelling"
	@echo "    check-style"
	@echo "    pylint-relaxed"
	@echo "    pylint-strict"

build: man update-version
	$(PYTHON_EXE) setup.py build

archive: tgz win32
	@# we can/should remove the version file in order to avoid a stale local version
	@$(RM) "$(VERSION_FILE)"

clean:
	@$(RM) -r build
	@$(RM) -r "$(MKDOCS_EXPORT_DIR)"
	@$(RM) "$(VERSION_FILE)"
	$(MAKE) -C man clean

man:
	@$(MAKE) -C man man

$(DIST_DIR):
	@mkdir -p "$@"

tgz: $(DIST_TGZ)

$(DIST_TGZ): $(DIST_DIR) build
	$(PYTHON_EXE) setup.py sdist --format gztar --dist-dir "$(DIST_DIR)"

win32: $(DIST_WIN32)

$(DIST_WIN32): $(DIST_DIR) build
	# this is a binary release
	$(PYTHON_EXE) setup.py bdist_wininst --user-access-control force \
		--dist-dir "$(DIST_DIR)" $(DISTUTILS_PLAT_NAME)

update-deb-changelog:
	@# retrieve the log of all commits since the latest release and add it to the deb changelog
	if ! grep -qFw "$(VERSION)" debian/changelog; then \
		git log --pretty=format:%s v$(shell dpkg-parsechangelog | sed --quiet -re 's/Version: (.*)/\1/ p').. | \
			DEBFULLNAME="PyCAM Builder" DEBEMAIL="builder@pycam.org" \
			xargs -r -d '\n' -n 1 -- debchange --newversion "$(subst -,.,$(VERSION))"; \
	fi

update-version:
	@echo 'VERSION = "$(VERSION)"' >| "$(VERSION_FILE)"

test: check-spelling check-style pytest check-yaml-flow

# The "make pytest" target calls pytest via the obsolete `py.test` name,
# instead of the modern `pytest` name.  This is in order to support
# older versions of pytest, specifically version 2.5 on Ubuntu Trusty.
# Once the oldest supported platform has pytest 3.0 or newer we can
# switch to the new `pytest` name.
pytest:
	/usr/bin/py.test-3 -v .

check-style:
	scripts/run_flake8 $(PYTHON_CHECK_STYLE_TARGETS)

check-yaml-flow:
	$(RM) test.ngc
	pycam/run_cli.py yaml_flow_working.yml
	grep -q "Z" test.ngc

pylint-strict:
	pylint $(PYTHON_CHECK_STYLE_TARGETS)

pylint-relaxed:
	pylint -d missing-docstring,invalid-name,pointless-string-statement,fixme,no-self-use \
		-d global-statement,unnecessary-pass,too-many-arguments,too-many-branches \
		-d too-many-instance-attributes,too-many-return-statements \
		-d too-few-public-methods,too-many-locals,using-constant-test \
		-d attribute-defined-outside-init,superfluous-parens,too-many-nested-blocks \
		-d too-many-statements,unused-argument,too-many-lines \
		-d too-many-boolean-expressions,too-many-public-methods \
		$(PYTHON_CHECK_STYLE_TARGETS)

PHONY: check-spelling
check-spelling:
	find $(SPELLING_PATHS) -type f \
			-not -name "*.pyc" \
			-not -name "*.png" \
			-not -name "*.stl" \
			-not -name "favicon.ico" \
		-print0 | xargs -0 codespell --exclude .codespell.exclude

## Building the documentation/website
docs: man $(MKDOCS_BUILD_STAMP)
	@$(MAKE) -C man html
	install -d "$(MKDOCS_EXPORT_DIR)/manpages/"
	install --target-directory="$(MKDOCS_EXPORT_DIR)/manpages/" man/*.html

$(MKDOCS_BUILD_STAMP): $(MKDOCS_SOURCE_FILES)
	sed 's/^Version/# Version/; s/^  \*/    */' Changelog \
		>"$(MKDOCS_SOURCE_DIR)/release-notes.md"
	mkdocs build
	touch "$@"
	
upload-docs: docs
	rsync -axz --delete --exclude=.DS_Store --exclude="$(notdir $(MKDOCS_BUILD_STAMP))" -e ssh \
		"$(MKDOCS_EXPORT_DIR)/" "$(WEBSITE_UPLOAD_PREFIX)$(WEBSITE_UPLOAD_LOCATION)/"
