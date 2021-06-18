-- Begin of initialization

local IDENTIFIER_PATTERN = '[%w_.:-]+'
local RAW_ATTRIBUTE
local IS_LABEL_SET_BY_PANDOC
local LABEL_TEMPLATE
local NOTELABEL_TEMPLATE

local function define_raw_attribute()
  if FORMAT == 'native' then
    RAW_ATTRIBUTE = pandoc.system.environment().TESTED_FORMAT
  elseif FORMAT == 'docx' then
    RAW_ATTRIBUTE = 'openxml'
  elseif FORMAT == 'odt' or FORMAT == 'opendocument' then
    RAW_ATTRIBUTE = 'opendocument'
  elseif FORMAT == 'context' or FORMAT == 'latex' then
    RAW_ATTRIBUTE = FORMAT
  else
    error(FORMAT ..
          ' output not supported by text-crossrefs.lua.')
  end
end

local function define_label_template()
  if RAW_ATTRIBUTE == 'opendocument' or RAW_ATTRIBUTE == 'openxml' then
    IS_LABEL_SET_BY_PANDOC = true
  elseif RAW_ATTRIBUTE == 'context' then
    LABEL_TEMPLATE = '\\pagereference[{{label}}]'
  elseif RAW_ATTRIBUTE == 'latex' then
    LABEL_TEMPLATE = '\\label{{{label}}}'
  end
end

define_raw_attribute()
define_label_template()

-- End of initialization

-- Configuration

local config = {
  page_prefix = 'p. ',
  pages_prefix = 'p. ',
  note_prefix = 'n. ',
  pagenote_order = 'pagefirst',
  pagenote_separator = ', ',
  pagenote_at_end = '',
  references_range_separator = '>',
  range_separator = '-',
  only_explicit_labels = 'false',
  default_ref_type = 'page',
  filelabel_ref_separator = '::'
}

local function format_config_to_openxml()
  to_format = { 'page_prefix',
                'pages_prefix',
                'note_prefix',
                'pagenote_separator',
                'pagenote_at_end',
                'range_separator' }
  for i = 1, #to_format do
    config[to_format[i]] = '<w:r><w:t xml:space="preserve">' ..
      config[to_format[i]] .. '</w:t></w:r>'
  end
end

local function set_configuration_item_from_metadata(item, metamap)
  metakey = 'tcrf-' .. string.gsub(item, '_', '-')
  if metamap[metakey] then
    -- The metadata values are Str in MetaInlines.
    config[item] = metamap[metakey][1].c
  end
end

local function configure(metadata)
  for item, _ in pairs(config) do
    set_configuration_item_from_metadata(item, metadata)
  end
  if RAW_ATTRIBUTE == 'openxml' then
    format_config_to_openxml()
  end
end

-- End of configuration

-- Extensions for the output document's format

local function define_tex_macros(document)
  if RAW_ATTRIBUTE == 'context' then
    local footnote_redefinition = '\\let\\oldfootnote\\footnote\n' ..
      '\\define[2]\\footnote{\\oldfootnote[#2]{#1}%\n' ..
      '\\expandafter\\edef\\csname #2pagenumber\\endcsname{\\userpage}}\n'
    local predefined_strings =
      '\\define\\tcrfpage{' .. config.page_prefix .. '}\n' ..
      '\\define\\tcrfpages{' .. config.pages_prefix .. '}\n' ..
      '\\define\\tcrfrangesep{' .. config.range_separator .. '}\n'
    local range_ref = '\\ifdefined\\tcrfpagerangeref\\else\n' ..
      '\\define[2]\\tcrfpagerangeref{' ..
      '\\if' ..
      '\\csname #1pagenumber\\endcsname' .. 
      '\\csname #2pagenumber\\endcsname\n' ..
      '\\tcrfpage\\at[#1]\n' ..
      '\\else\n' ..
      '\\tcrfpages\\at[#1]\\tcrfrangesep\\at[#2]\\fi}\n' ..
      '\\fi\n'
    local macros_block = pandoc.RawBlock('context',
                                         footnote_redefinition ..
                                         predefined_strings ..
                                         range_ref)
    table.insert(document.blocks, 1, macros_block)
  elseif RAW_ATTRIBUTE == 'latex' then
    local predefined_strings =
      '\\newcommand*{\\tcrfpage}{' .. config.page_prefix .. '}\n' ..
      '\\newcommand*{\\tcrfpages}{' .. config.pages_prefix .. '}\n' ..
      '\\newcommand*{\\tcrfrangesep}{' .. config.range_separator .. '}\n'
    local label_redefinition = '\\let\\oldlabel\\label\n' ..
      '\\renewcommand*{\\label}[1]{\\oldlabel{#1}%\n' ..
      '\\expandafter\\xdef\\csname #1pagenumber\\endcsname{\\thepage}}\n'
    local range_ref = '\\ifdefined\\tcrfpagerangeref\\else\n' ..
      '\\newcommand*{\\tcrfpagerangeref}[2]{%\n' ..
      '\\if' ..
      '\\csname #1pagenumber\\endcsname' ..
      '\\csname #2pagenumber\\endcsname\n' ..
      '\\tcrfpage\\pageref{#1}\n' ..
      '\\else\n' ..
      '\\tcrfpages\\pageref{#1}\\tcrfrangesep\\pageref{#2}\\fi}\n' ..
      '\\fi\n'
    local macros_block = pandoc.RawBlock('latex',
                                         predefined_strings ..
                                         label_redefinition ..
                                         range_ref)
    table.insert(document.blocks, 1, macros_block)
  end
  return document
end

-- End of the extensions for the output document's format

-- Identifiers

local spans_to_note_labels = {}
local current_odt_note_index = 0
local is_first_span_in_note = true
local current_note_label

local function map_span_to_label(span)
  if RAW_ATTRIBUTE == 'opendocument' then
    spans_to_note_labels[span.identifier] = 'ftn' .. current_odt_note_index
  elseif RAW_ATTRIBUTE == 'openxml' or RAW_ATTRIBUTE == 'context' then
    if is_first_span_in_note then
      current_note_label = span.identifier
      is_first_span_in_note = false
    end
    spans_to_note_labels[span.identifier] = current_note_label
  end
end

local function map_spans_to_labels(container)
  for i = 1, #container.content do
    -- The tests must be separate in order to support spans inside spans.
    if container.content[i].t == 'Span'
      and container.content[i].identifier ~= ''
    then
      map_span_to_label(container.content[i])
    end
    if container.content[i].content then
      map_spans_to_labels(container.content[i])
    end
  end
end

local function map_spans_to_notelabels(note)
  if RAW_ATTRIBUTE == 'opendocument'
    or RAW_ATTRIBUTE == 'openxml'
    or RAW_ATTRIBUTE == 'context'
  then
    is_first_span_in_note = true
    map_spans_to_labels(note)
    current_odt_note_index = current_odt_note_index + 1
  end
end

local function make_label(label)
  if IS_LABEL_SET_BY_PANDOC then
    return pandoc.Str('')
  else
    label_rawcode = string.gsub(LABEL_TEMPLATE, '{{label}}', label)
    return pandoc.RawInline(RAW_ATTRIBUTE, label_rawcode)
  end
end

local function labelize_span(span)
  if span.identifier ~= '' then
    local label = span.identifier
    local label_begin = make_label(label, 'begin')
    return { label_begin, span }
  end
end

local function has_class(elem, class)
  if elem.classes then
    for i = 1, #elem.classes do
      if elem.classes[i] == class then
        return true
      end
    end
    return false
  else
    error('function has_class used on an element of type ' ..
          elem.t .. ' that cannot have classes.')
  end
end

local current_note_labels = {}

local collect_note_labels = {
  Span = function(span)
    if span.identifier ~= '' and
      (config.only_explicit_labels == 'false' or has_class(span, 'label')) 
    then
      table.insert(current_note_labels, span.identifier)
    end
  end
}

local function make_notelabel(pos)
  local raw_code = ''
  if pos == 'begin' then
    if RAW_ATTRIBUTE == 'openxml' then
      raw_code = string.gsub(
        '<w:bookmarkStart w:id="{{label}}_Note" w:name="{{label}}_Note"/>',
        '{{label}}', current_note_labels[#current_note_labels])
    end
  elseif pos == 'end' then
    if RAW_ATTRIBUTE == 'context' then
      local label = current_note_labels[1] .. '_note'
      raw_code = '{' .. label .. '}'
    elseif RAW_ATTRIBUTE == 'openxml' then
      raw_code = string.gsub('<w:bookmarkEnd w:id="{{label}}_Note"/>',
                             '{{label}}', current_note_labels[1])
    end
  end
  return pandoc.RawInline(RAW_ATTRIBUTE, raw_code)
end

local function labelize_note(note)
  local label_begin = make_notelabel('begin')
  local label_end = make_notelabel('end')
  return { label_begin, note, label_end }
end

function set_notelabels(note)
  current_note_labels = {}
  pandoc.walk_inline(note, collect_note_labels)
  if #current_note_labels > 0 then
    return labelize_note(note)
  end
end

-- End of identifiers-related code

-- References

local function is_reference_valid(ref)
  if string.find(ref, '^[' .. IDENTIFIER_PATTERN .. ']') then
    error('text-crossrefs.lua: Invalid character in reference: ' .. ref ..
          '\nIdentifier and reference names can only contain' ..
          ' alphanumerical characters, periods, underscores and hyphens.\n')
  else
    return true
  end
end

local function is_ref_external(rawref)
  if string.find(rawref, config.filelabel_ref_separator, 1, true) then
    return true
  else
    return false
  end
end

local function is_ref_range(rawref)
  if string.find(rawref, config.references_range_separator, 1, true) then
    return true
  else
    return false
  end
end

function get_first_reference_end_index(range_separator_index)
  if range_separator_index then
    return range_separator_index - 1
  end
end

local function get_first_reference(rawref)
  local _, file_ref_separator_index =
    string.find(rawref, config.filelabel_ref_separator, 1, true)
  local range_separator_index, _ =
    string.find(rawref, config.references_range_separator, 1, true)
  local ref = string.sub(rawref,
                         (file_ref_separator_index or 0) + 1,
                         get_first_reference_end_index(range_separator_index))
  if is_reference_valid(ref) then return ref end
end

local function get_second_reference(rawref)
  local second_ref_begin_index
  local _, file_ref_separator_index =
    string.find(rawref, config.filelabel_ref_separator, 1, true)
  if file_ref_separator_index then
    _, file_ref_separator_index =
      string.find(rawref,
                  config.filelabel_ref_separator,
                  config.file_ref_separator_index + 1,
                  true)
    second_ref_begin_index = file_ref_separator_index + 1
  else
    local _, range_separator_index, _ =
      string.find(rawref, config.references_range_separator, 1, true)
    second_ref_begin_index = range_separator_index + 1
  end
  local ref = string.sub(rawref, second_ref_begin_index)
  if is_reference_valid(ref) then return ref end
end

local function analyze_reference_span(reference_span)
  if #reference_span.content == 1 and reference_span.content[1].t == 'Str' then
    raw_reference = reference_span.content[1].c
    analyzed_reference = {}
    analyzed_reference.is_external = is_ref_external(raw_reference)
    analyzed_reference.is_range = is_ref_range(raw_reference)
    if analyzed_reference.is_external then
      analyzed_reference.filelabel = get_extfilelabel(raw_reference)
    end
    analyzed_reference.first = get_first_reference(raw_reference)
    if analyzed_reference.is_range then
      analyzed_reference.second = get_second_reference(raw_reference)
    end
    return analyzed_reference
  else
    error('The content of a span with class ref must be a plain string.')
  end
end

local function insert_page_target_in_xml(target)
  if RAW_ATTRIBUTE == 'opendocument' then
    return '<text:bookmark-ref ' ..
      ' text:reference-format="page" text:ref-name="' ..
      target .. '">000</text:bookmark-ref>'
  elseif RAW_ATTRIBUTE == 'openxml' then
    return '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>' ..
      '<w:r><w:instrText xml:space="preserve"> PAGEREF ' ..
      target .. ' \\h </w:instrText></w:r>' ..
      '<w:r><w:fldChar w:fldCharType="separate"/></w:r>' ..
      '<w:r><w:t>000</w:t></w:r>' ..
      '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
  end
end

local function format_page_reference(target)
  if RAW_ATTRIBUTE == 'context' then
    return config.page_prefix .. '\\at[' .. target .. ']'
  elseif RAW_ATTRIBUTE == 'latex' then
    return config.page_prefix .. '\\pageref{' .. target .. '}'
  elseif RAW_ATTRIBUTE == 'opendocument' then
    return config.page_prefix .. insert_page_target_in_xml(target)
  elseif RAW_ATTRIBUTE == 'openxml' then
    return config.page_prefix .. insert_page_target_in_xml(target)
  end
end

local function format_pagerange_reference(first, second)
  if RAW_ATTRIBUTE == 'context' or RAW_ATTRIBUTE == 'latex' then
    return '\\tcrfpagerangeref{' .. first .. '}{' .. second .. '}'
  elseif RAW_ATTRIBUTE == 'opendocument' or RAW_ATTRIBUTE == 'openxml' then
    return config.pages_prefix .. insert_page_target_in_xml(first) ..
      config.range_separator .. insert_page_target_in_xml(second)
  end
end

local function format_note_reference(target)
  if RAW_ATTRIBUTE == 'context' then
    return config.note_prefix .. '\\in[' .. spans_to_note_labels[target] .. '_note' .. ']'
  elseif RAW_ATTRIBUTE == 'latex' then
    return config.note_prefix .. '\\ref{' .. target .. '}'
  elseif RAW_ATTRIBUTE == 'opendocument' then
    return config.note_prefix .. '<text:note-ref text:note-class="footnote"' ..
      ' text:reference-format="text" text:ref-name="' ..
      spans_to_note_labels[target] .. '">000</text:note-ref>'
  elseif RAW_ATTRIBUTE == 'openxml' then
    return config.note_prefix ..
      '<w:r><w:fldChar w:fldCharType="begin" w:dirty="true"/></w:r>' ..
      '<w:r><w:instrText xml:space="preserve"> NOTEREF ' ..
      target .. '_Note' .. ' \\h </w:instrText></w:r>' ..
      '<w:r><w:fldChar w:fldCharType="separate"/></w:r>' ..
      '<w:r><w:t>000</w:t></w:r>' ..
      '<w:r><w:fldChar w:fldCharType="end"/></w:r>'
  end
end

local function format_pagenote_reference(target)
  if config.pagenote_order == 'pagefirst' then
    return format_page_reference(target) .. config.pagenote_separator ..
      format_note_reference(target) .. config.pagenote_at_end
  elseif config.pagenote_order == 'notefirst' then
    return format_note_reference(target) .. config.pagenote_separator ..
      format_page_reference(target) .. config.pagenote_at_end
  else
    error('tcrf-pagenote-order must be set either to pagefirst or notefirst.')
  end
end

local function format_reference(target, reference_type)
  if reference_type == 'page' and target.is_range then
    return format_pagerange_reference(target.first, target.second)
  elseif reference_type == 'page' then
    return format_page_reference(target.first)
  elseif reference_type == 'note' then
    return format_note_reference(target.first)
  elseif reference_type == 'pagenote' then
    return format_pagenote_reference(target.first)
  else
    error('Invalid value for attribute type in span with class ref: ' ..
          reference_type)
  end
end

local function make_reference(span)
  if has_class(span, 'ref') then
    local target = analyze_reference_span(span)
    if not target.is_external then
      local reference_type = span.attributes.type or config.default_ref_type
      local formatted_reference = format_reference(target, reference_type)
      span.content[1] = pandoc.RawInline(RAW_ATTRIBUTE, formatted_reference)
      return span
    end
  end
end

-- End of references-related code

return {
  { Meta = configure },
  { Pandoc = define_tex_macros },
  { Note = set_notelabels },
  { Note = map_spans_to_notelabels },
  { Span = labelize_span },
  { Span = make_reference }
}
