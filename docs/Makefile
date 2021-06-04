all: req doc examples
req:
	python3 -m pip -q install scikit-image numpy
	which cabextract || sudo yum install -q -y curl cabextract xorg-x11-font-utils fontconfig
	[ -e /usr/share/fonts/msttcore/ ] || sudo yum install -q -y https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
	go build -o render render.go
doc:
	PYTHONPATH=.. python3 render.py
examples:
	cd ../examples; for p in *.py; do echo $$p; [ -s $${p%.py}.stl ] || PYTHONPATH=.. python3 $$p; done
	for f in $$( cd ../examples; ls -1 *.stl); do echo $$f; [ -s images/$${f%.stl}.png ] || go run render.go ../examples/$$f images/$${f%.stl}.png; done
