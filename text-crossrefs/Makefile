.PHONY: test

PANDOC_COMMAND = pandoc -L text-crossrefs.lua -t native sample.md

test:
	TESTED_FORMAT=context $(PANDOC_COMMAND) -o tests/output.context \
		&& diff tests/output.context tests/expected.context
	TESTED_FORMAT=latex $(PANDOC_COMMAND) -o tests/output.latex  \
		&& diff tests/output.latex tests/expected.latex
	TESTED_FORMAT=opendocument $(PANDOC_COMMAND) -o tests/output.opendocument \
		&& diff tests/output.opendocument tests/expected.opendocument
	TESTED_FORMAT=openxml $(PANDOC_COMMAND) -o tests/output.docx \
		&& diff tests/output.docx tests/expected.docx
	rm tests/output.*

