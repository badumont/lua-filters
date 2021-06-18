# text-crossrefs: getting references to page and note numbers in Pandoc

This filters aims at extending Pandoc's cross-referencing
capacities by enabling automatic references to any piece of text
by either its page or, whenever it applies, its note number. It
currently supports the following target formats:

  * context
  * docx
  * latex
  * odt
  * opendocument

It doesn't permit to refer to references in other files: if you want to do this, use text-extrefs.

N.-B.: When opening for the first time a DOCX or ODT/Opendocument file produced by Pandoc with text-crossrefs, you probably will have to refresh the fields in order to get the correct values. In LibreOffice, press `F9`; in Word, a dialog box should appear when the file opens.

## Usage

### Basics

Mark the span of text you want to refer to later with an
identifier composed of alphanumeric characters, periods, colons, underscores and hyphens:

``` markdown
Émile Gaboriau published [_L'Affaire Lerouge_ in
1866]{#publication}.[^1]

[^1]: It is a very [fine piece of literature]{#my-evaluation}.

[It was very popular.]{#reception}
```

You can refer to it using another span with class `ref` containing
the target's identifier. If the targetted span is part of a
footnote, you can refer to it either by page or by note number according to
the value of the `type` attribute (defaults to `page`). For instance, this:

``` markdown
See [publication]{.ref} for the publication date. I gave my
opinion in [my-evaluation]{.ref type=note}, [my-evaluation]{.ref}.
```

will render in LaTeX output:

``` tex
See p. \pageref{publication} for the publication date. I expressed
my thoughts about it in \ref{my-evaluation},
p. \pageref{my-evaluation}.
```

If you want to give a reference by note and page number like in the example above, you can also use the following shorthand:

```md
[my-evaluation]{.ref type=pagenote}
```

You can refer to headers as well using either explicit or automatically generated identifiers (see Pandoc user’s guide).

### Page ranges

You can refer to a page range like this:

``` markdown
If you want to know more about _L'Affaire Lerouge_, see [publication>reception]{.ref}.
```

The separator (here `>`) can be set to any string composed of characters other than alphanumeric, period, colon, underscore, hyphen and space.

In LaTeX and ConTeXt output, the page range will be printed as a simple page reference if the page numbers are identical. You can provide your own definition of the macro `\tcrfpagerangeref{<label1>}{<label2>}` in the preamble. In DOCX and ODT/Opendocument output, the same result can be achieved in a word processor by the means of automatic search and replace with regular expressions.

## Customization

The following metadata fields can be set as strings:

  * `tcrf-page-prefix`: 
    * “page” prefix; 
    * defaults to `p. `.
  * `tcrf-pages-prefix`: 
    * “pages” prefix;
    * defaults to `p. `.
  * `tcrf-note-prefix`: 
    * “note” prefix;
    * defaults to `n. `.
  * `tcrf-pagenote-separator`:
    * the separator between the references when `type` is set to `pagenote`;
    * defaults to `, `.
  * `tcrf-pagenote-at-end`:
    * the string printed at the end of a pagenote reference;
    * defaults to an empty string, can be used to achieve something like *n. 3 (p. 5)*.
  * `tcrf-pagenote-order`:
    * the order in which the references to note and page are printed;
    * defaults to `pagefirst`, can be set to `notefirst`.
  * `tcrf-references-range-separator`:
    * the string used to separate two references in a reference span; can be composed of any character not authorized in an identifier other than space or tab;
    * defaults to `>`.
  * `tcrf-range-separator`:
    * the character inserted between to page numbers in a range;
    * defaults to `-`.
  * `tcrf-only-explicit-labels`:
    * set it to `true` if you want that _tcrf_ handle only spans with class `label`;
    * defaults to `false`.
  * `tcrf-default-ref-type`:
    * default value for the `type` attribute (`note`, `page` or `pagenote`);
    * defaults to `page`.
  * `tcrf-filelabel-ref-separator`:
    * only useful in conjunction with the text-exrefs filter;
    * separator between external files' labels and references;
    * defaults to `::`.

## Compatibility with other filters

Text-crossrefs must be run after all other filters that can create, delete or move
footnotes, like citeproc.

In order to give and identifier to a note produced by a citation inside square brackets, the span should not include the citation key, the locator or the `;`
delimiter. If it is placed immediatly after the locator, this should be surrounded by curly brackets. So this should work:
 
 ``` markdown
 [@Jones1973, p. 5-70; @Doe2004[]{#jones-doe}]
 
 [@Jones1973, p. 5-70; [it was elaborated upon]{#further-elaboration} by @Doe2004]
 
 [@Jones1973, {p. 5-70}[]{#ref-to-jones}; @Doe2004]
 ```
 
not that:
 
 ``` markdown
 [[@Jones1973, p. 5-70]{#ref-to-jones}; @Doe2004]
 
 [[@Jones1973, p. 5-70; @Doe2004]{#jones-doe}]
 
 [@Jones1973, p. 5-70[]{#ref-to-jones}; @Doe2004]
 ```
 
You can set classes and attributes to your spans other than those defined by text-crossrefs (for instance `[some text]{#to-be-referred-to .highlighted color=red}` or `[reference]{.ref color=red}`). No span is removed.

Text-crossrefs is fully compatible with text-extrefs. Whenever possible, when a metadata is not set for text-extrefs, its value is taken from its text-crossrefs equivalent, so that you don't need to duplicate similar variables.
