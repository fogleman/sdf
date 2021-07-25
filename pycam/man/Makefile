RUN_SCRIPT = ../pycam/run_gui.py
PYCAM_MAN_INCLUDE_FILE = pycam.1.inc
MAN_FILES = pycam.1
HTML_FILES = $(patsubst %,%.html,$(MAN_FILES))
RM = rm -f


.PHONY: build clean html man


man: $(MAN_FILES)

html: $(HTML_FILES)

pycam.1: $(RUN_SCRIPT) $(PYCAM_MAN_INCLUDE_FILE)
	help2man --no-info --name="Toolpath Generation for 3-Axis CNC machining" \
		--section=1 --manual="PyCAM manual" --include="$(PYCAM_MAN_INCLUDE_FILE)" \
		--output="$@" "$(RUN_SCRIPT)"

%.html: %
	man2html $* >"$@"

clean:
	$(RM) $(MAN_FILES) $(HTML_FILES)
