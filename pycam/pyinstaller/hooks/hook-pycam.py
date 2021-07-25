# keysyms does not seem to be recognized by pyinstaller
# There will be exceptions after any keypress without this line.
hiddenimports = ["gtk.keysyms"]
