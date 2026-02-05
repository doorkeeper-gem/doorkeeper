# frozen_string_literal: true
require 'cgi/escape'
require 'cgi/util' unless defined?(CGI::EscapeExt)

##
# Outputs RDoc markup as HTML.

class RDoc::Markup::ToHtml < RDoc::Markup::Formatter

  include RDoc::Text

  # :section: Utilities

  ##
  # Maps RDoc::Markup::Parser::LIST_TOKENS types to HTML tags

  LIST_TYPE_TO_HTML = {
    :BULLET => ['<ul>',                                      '</ul>'],
    :LABEL  => ['<dl class="rdoc-list label-list">',         '</dl>'],
    :LALPHA => ['<ol style="list-style-type: lower-alpha">', '</ol>'],
    :NOTE   => ['<dl class="rdoc-list note-list">',          '</dl>'],
    :NUMBER => ['<ol>',                                      '</ol>'],
    :UALPHA => ['<ol style="list-style-type: upper-alpha">', '</ol>'],
  }

  attr_reader :res # :nodoc:
  attr_reader :in_list_entry # :nodoc:
  attr_reader :list # :nodoc:

  ##
  # The RDoc::CodeObject HTML is being generated for.  This is used to
  # generate namespaced URI fragments

  attr_accessor :code_object

  ##
  # Path to this document for relative links

  attr_accessor :from_path

  # :section:

  ##
  # Creates a new formatter that will output HTML

  def initialize(options, markup = nil)
    super

    @code_object = nil
    @from_path = ''
    @in_list_entry = nil
    @list = nil
    @th = nil
    @hard_break = "<br>\n"

    init_regexp_handlings

    init_tags
  end

  # :section: Regexp Handling
  #
  # These methods are used by regexp handling markup added by RDoc::Markup#add_regexp_handling.

  # :nodoc:
  URL_CHARACTERS_REGEXP_STR = /[A-Za-z0-9\-._~:\/\?#\[\]@!$&'\(\)*+,;%=]/.source

  ##
  # Adds regexp handlings.

  def init_regexp_handlings
    # external links
    @markup.add_regexp_handling(/(?:link:|https?:|mailto:|ftp:|irc:|www\.)#{URL_CHARACTERS_REGEXP_STR}+\w/,
                                :HYPERLINK)
    init_link_notation_regexp_handlings
  end

  ##
  # Adds regexp handlings about link notations.

  def init_link_notation_regexp_handlings
    add_regexp_handling_RDOCLINK
    add_regexp_handling_TIDYLINK
  end

  def handle_RDOCLINK(url) # :nodoc:
    case url
    when /^rdoc-ref:/
      CGI.escapeHTML($')
    when /^rdoc-label:/
      text = $'

      text = case text
             when /\Alabel-/    then $'
             when /\Afootmark-/ then $'
             when /\Afoottext-/ then $'
             else                    text
             end

      gen_url CGI.escapeHTML(url), CGI.escapeHTML(text)
    when /^rdoc-image:/
      # Split the string after "rdoc-image:" into url and alt.
      #   "path/to/image.jpg:alt text" => ["path/to/image.jpg", "alt text"]
      #   "http://example.com/path/to/image.jpg:alt text" => ["http://example.com/path/to/image.jpg", "alt text"]
      url, alt = $'.split(/:(?!\/)/, 2)
      if alt && !alt.empty?
        %[<img src="#{CGI.escapeHTML(url)}" alt="#{CGI.escapeHTML(alt)}">]
      else
        %[<img src="#{CGI.escapeHTML(url)}">]
      end
    when /\Ardoc-[a-z]+:/
      CGI.escapeHTML($')
    end
  end

  ##
  # +target+ is a <code><br></code>

  def handle_regexp_HARD_BREAK(target)
    '<br>'
  end

  ##
  # +target+ is a potential link.  The following schemes are handled:
  #
  # <tt>mailto:</tt>::
  #   Inserted as-is.
  # <tt>http:</tt>::
  #   Links are checked to see if they reference an image. If so, that image
  #   gets inserted using an <tt><img></tt> tag. Otherwise a conventional
  #   <tt><a href></tt> is used.
  # <tt>link:</tt>::
  #   Reference to a local file relative to the output directory.

  def handle_regexp_HYPERLINK(target)
    url = CGI.escapeHTML(target.text)

    gen_url url, url
  end

  ##
  # +target+ is an rdoc-schemed link that will be converted into a hyperlink.
  #
  # For the +rdoc-ref+ scheme the named reference will be returned without
  # creating a link.
  #
  # For the +rdoc-label+ scheme the footnote and label prefixes are stripped
  # when creating a link.  All other contents will be linked verbatim.

  def handle_regexp_RDOCLINK(target)
    handle_RDOCLINK target.text
  end

  ##
  # This +target+ is a link where the label is different from the URL
  # <tt>label[url]</tt> or <tt>{long label}[url]</tt>

  def handle_regexp_TIDYLINK(target)
    text = target.text

    if tidy_link_capturing?
      return finish_tidy_link(text)
    end

    if text.start_with?('{') && !text.include?('}')
      start_tidy_link text
      return ''
    end

    convert_complete_tidy_link(text)
  end

  # :section: Visitor
  #
  # These methods implement the HTML visitor.

  ##
  # Prepares the visitor for HTML generation

  def start_accepting
    @res = []
    @in_list_entry = []
    @list = []
  end

  ##
  # Returns the generated output

  def end_accepting
    @res.join
  end

  ##
  # Adds +block_quote+ to the output

  def accept_block_quote(block_quote)
    @res << "\n<blockquote>"

    block_quote.parts.each do |part|
      part.accept self
    end

    @res << "</blockquote>\n"
  end

  ##
  # Adds +paragraph+ to the output

  def accept_paragraph(paragraph)
    @res << "\n<p>"
    text = paragraph.text @hard_break
    text = text.gsub(/(#{SPACE_SEPARATED_LETTER_CLASS})?\K\r?\n(?=(?(1)(#{SPACE_SEPARATED_LETTER_CLASS})?))/o) {
      defined?($2) && ' '
    }
    @res << to_html(text)
    @res << "</p>\n"
  end

  ##
  # Adds +verbatim+ to the output

  def accept_verbatim(verbatim)
    text = verbatim.text.rstrip
    format = verbatim.format

    klass = nil

    # Apply Ruby syntax highlighting if
    # - explicitly marked as Ruby (via ruby? which accepts :ruby or :rb)
    # - no format specified but the text is parseable as Ruby
    # Otherwise, add language class when applicable and skip Ruby highlighting
    content = if verbatim.ruby? || (format.nil? && parseable?(text))
                begin
                  tokens = RDoc::Parser::RipperStateLex.parse text
                  klass  = ' class="ruby"'

                  result = RDoc::TokenStream.to_html tokens
                  result = result + "\n" unless "\n" == result[-1]
                  result
                rescue
                  CGI.escapeHTML text
                end
              else
                klass = " class=\"#{format}\"" if format
                CGI.escapeHTML text
              end

    if @options.pipe then
      @res << "\n<pre><code>#{CGI.escapeHTML text}\n</code></pre>\n"
    else
      @res << "\n<pre#{klass}>#{content}</pre>\n"
    end
  end

  ##
  # Adds +rule+ to the output

  def accept_rule(rule)
    @res << "<hr>\n"
  end

  ##
  # Prepares the visitor for consuming +list+

  def accept_list_start(list)
    @list << list.type
    @res << html_list_name(list.type, true)
    @in_list_entry.push false
  end

  ##
  # Finishes consumption of +list+

  def accept_list_end(list)
    @list.pop
    if tag = @in_list_entry.pop
      @res << tag
    end
    @res << html_list_name(list.type, false) << "\n"
  end

  ##
  # Prepares the visitor for consuming +list_item+

  def accept_list_item_start(list_item)
    if tag = @in_list_entry.last
      @res << tag
    end

    @res << list_item_start(list_item, @list.last)
  end

  ##
  # Finishes consumption of +list_item+

  def accept_list_item_end(list_item)
    @in_list_entry[-1] = list_end_for(@list.last)
  end

  ##
  # Adds +blank_line+ to the output

  def accept_blank_line(blank_line)
    # @res << annotate("<p />") << "\n"
  end

  ##
  # Adds +heading+ to the output.  The headings greater than 6 are trimmed to
  # level 6.

  def accept_heading(heading)
    level = [6, heading.level].min

    label = heading.label @code_object
    legacy_label = heading.legacy_label @code_object

    # Add legacy anchor before the heading for backward compatibility.
    # This allows old links with label- prefix to still work.
    if @options.output_decoration && !@options.pipe
      @res << "\n<span id=\"#{legacy_label}\" class=\"legacy-anchor\"></span>"
    end

    @res << if @options.output_decoration
              "\n<h#{level} id=\"#{label}\">"
            else
              "\n<h#{level}>"
            end

    if @options.pipe
      @res << to_html(heading.text)
    else
      @res << "<a href=\"##{label}\">#{to_html(heading.text)}</a>"
    end

    @res << "</h#{level}>\n"
  end

  ##
  # Adds +raw+ to the output

  def accept_raw(raw)
    @res << raw.parts.join("\n")
  end

  ##
  # Adds +table+ to the output

  def accept_table(header, body, aligns)
    @res << "\n<table role=\"table\">\n<thead>\n<tr>\n"
    header.zip(aligns) do |text, align|
      @res << '<th'
      @res << ' align="' << align << '"' if align
      @res << '>' << to_html(text) << "</th>\n"
    end
    @res << "</tr>\n</thead>\n<tbody>\n"
    body.each do |row|
      @res << "<tr>\n"
      row.zip(aligns) do |text, align|
        @res << '<td'
        @res << ' align="' << align << '"' if align
        @res << '>' << to_html(text) << "</td>\n"
      end
      @res << "</tr>\n"
    end
    @res << "</tbody>\n</table>\n"
  end

  # :section: Utilities

  ##
  # CGI-escapes +text+

  def convert_string(text)
    CGI.escapeHTML text
  end

  ##
  # Generates an HTML link or image tag for the given +url+ and +text+.
  #
  # - Image URLs (http/https/link ending in .gif, .png, .jpg, .jpeg, .bmp)
  #   become <img> tags
  # - File references (.rb, .rdoc, .md) are converted to .html paths
  # - Anchor URLs (#foo) pass through unchanged for GitHub-style header linking
  # - Footnote links get wrapped in <sup> tags

  def gen_url(url, text)
    scheme, url, id = parse_url url

    if %w[http https link].include?(scheme) && url =~ /\.(gif|png|jpg|jpeg|bmp)\z/
      "<img src=\"#{url}\" />"
    else
      if scheme != 'link' and %r%\A((?!https?:)(?:[^/#]*/)*+)([^/#]+)\.(rb|rdoc|md)(?=\z|#)%i =~ url
        url = "#$1#{$2.tr('.', '_')}_#$3.html#$'"
      end

      text = text.sub %r%^#{scheme}:/*%i, ''
      text = text.sub %r%^[*\^](\d+)$%,   '\1'

      link = "<a#{id} href=\"#{url}\">#{text}</a>"

      if /"foot/.match?(id)
        "<sup>#{link}</sup>"
      else
        link
      end
    end
  end

  ##
  # Determines the HTML list element for +list_type+ and +open_tag+

  def html_list_name(list_type, open_tag)
    tags = LIST_TYPE_TO_HTML[list_type]
    raise RDoc::Error, "Invalid list type: #{list_type.inspect}" unless tags
    tags[open_tag ? 0 : 1]
  end

  ##
  # Maps attributes to HTML tags

  def init_tags
    add_tag :BOLD,   "<strong>", "</strong>"
    add_tag :TT,     "<code>",   "</code>"
    add_tag :EM,     "<em>",     "</em>"
    add_tag :STRIKE, "<del>",    "</del>"
  end

  ##
  # Returns the HTML tag for +list_type+, possible using a label from
  # +list_item+

  def list_item_start(list_item, list_type)
    case list_type
    when :BULLET, :LALPHA, :NUMBER, :UALPHA then
      "<li>"
    when :LABEL, :NOTE then
      Array(list_item.label).map do |label|
        "<dt>#{to_html label}</dt>\n"
      end.join << "<dd>"
    else
      raise RDoc::Error, "Invalid list type: #{list_type.inspect}"
    end
  end

  ##
  # Returns the HTML end-tag for +list_type+

  def list_end_for(list_type)
    case list_type
    when :BULLET, :LALPHA, :NUMBER, :UALPHA then
      "</li>"
    when :LABEL, :NOTE then
      "</dd>"
    else
      raise RDoc::Error, "Invalid list type: #{list_type.inspect}"
    end
  end

  ##
  # Returns true if text is valid ruby syntax

  def parseable?(text)
    verbose, $VERBOSE = $VERBOSE, nil
    catch(:valid) do
      eval("BEGIN { throw :valid, true }\n#{text}")
    end
  rescue SyntaxError
    false
  ensure
    $VERBOSE = verbose
  end

  ##
  # Converts +item+ to HTML using RDoc::Text#to_html

  def to_html(item)
    super convert_flow @am.flow item
  end

  private

  def convert_flow(flow_items)
    res = []

    flow_items.each do |item|
      case item
      when String
        append_flow_fragment res, convert_string(item)
      when RDoc::Markup::AttrChanger
        off_tags res, item
        on_tags  res, item
      when RDoc::Markup::RegexpHandling
        append_flow_fragment res, convert_regexp_handling(item)
      else
        raise "Unknown flow element: #{item.inspect}"
      end
    end

    res.join
  end

  def append_flow_fragment(res, fragment)
    return if fragment.nil? || fragment.empty?

    emit_tidy_link_fragment(res, fragment)
  end

  def append_to_tidy_label(fragment)
    @tidy_link_buffer << fragment
  end

  ##
  # Matches an entire tidy link with a braced label "{label}[url]".
  #
  # Capture 1: label contents.
  # Capture 2: URL text.
  # Capture 3: trailing content.
  TIDY_LINK_WITH_BRACES = /\A\{(.*?)\}\[(.*?)\](.*)\z/

  ##
  # Matches the tail of a braced tidy link when the opening brace was
  # consumed earlier while accumulating the label text.
  #
  # Capture 1: remaining label content.
  # Capture 2: URL text.
  # Capture 3: trailing content.
  TIDY_LINK_WITH_BRACES_TAIL = /\A(.*?)\}\[(.*?)\](.*)\z/

  ##
  # Matches a tidy link with a single-word label "label[url]".
  #
  # Capture 1: the single-word label (no whitespace).
  # Capture 2: URL text between the brackets.
  TIDY_LINK_SINGLE_WORD = /\A(\S+)\[(.*?)\](.*)\z/

  def convert_complete_tidy_link(text)
    return text unless
      text =~ TIDY_LINK_WITH_BRACES or text =~ TIDY_LINK_SINGLE_WORD

    label = $1
    url   = CGI.escapeHTML($2)

    label_html = if /^rdoc-image:/ =~ label
                   handle_RDOCLINK(label)
                 else
                   render_tidy_link_label(label)
                 end

    gen_url url, label_html
  end

  def emit_tidy_link_fragment(res, fragment)
    if tidy_link_capturing?
      append_to_tidy_label fragment
    else
      res << fragment
    end
  end

  def finish_tidy_link(text)
    label_tail, url, trailing = extract_tidy_link_parts(text)
    append_to_tidy_label CGI.escapeHTML(label_tail) unless label_tail.empty?

    return '' unless url

    label_html = @tidy_link_buffer
    @tidy_link_buffer = nil
    link = gen_url(url, label_html)

    return link if trailing.empty?

    link + CGI.escapeHTML(trailing)
  end

  def extract_tidy_link_parts(text)
    if text =~ TIDY_LINK_WITH_BRACES
      [$1, CGI.escapeHTML($2), $3]
    elsif text =~ TIDY_LINK_WITH_BRACES_TAIL
      [$1, CGI.escapeHTML($2), $3]
    elsif text =~ TIDY_LINK_SINGLE_WORD
      [$1, CGI.escapeHTML($2), $3]
    else
      [text, nil, '']
    end
  end

  def on_tags(res, item)
    each_attr_tag(item.turn_on) do |tag|
      emit_tidy_link_fragment(res, annotate(tag.on))
      @in_tt += 1 if tt? tag
    end
  end

  def off_tags(res, item)
    each_attr_tag(item.turn_off, true) do |tag|
      emit_tidy_link_fragment(res, annotate(tag.off))
      @in_tt -= 1 if tt? tag
    end
  end

  def start_tidy_link(text)
    @tidy_link_buffer = String.new
    append_to_tidy_label CGI.escapeHTML(text.delete_prefix('{'))
  end

  def tidy_link_capturing?
    !!@tidy_link_buffer
  end

  def render_tidy_link_label(label)
    RDoc::Markup::LinkLabelToHtml.render(label, @options, @from_path)
  end
end

##
# Formatter dedicated to rendering tidy link labels without mutating the
# calling formatter's state.

class RDoc::Markup::LinkLabelToHtml < RDoc::Markup::ToHtml
  def self.render(label, options, from_path)
    new(options, from_path).to_html(label)
  end

  def initialize(options, from_path = nil)
    super(options)

    self.from_path = from_path if from_path
  end
end
