# frozen_string_literal: true
##
# Subclass of the RDoc::Markup::ToHtml class that supports looking up method
# names, classes, etc to create links.  RDoc::CrossReference is used to
# generate those links based on the current context.

class RDoc::Markup::ToHtmlCrossref < RDoc::Markup::ToHtml

  # :stopdoc:
  ALL_CROSSREF_REGEXP = RDoc::CrossReference::ALL_CROSSREF_REGEXP
  CLASS_REGEXP_STR    = RDoc::CrossReference::CLASS_REGEXP_STR
  CROSSREF_REGEXP     = RDoc::CrossReference::CROSSREF_REGEXP
  METHOD_REGEXP_STR   = RDoc::CrossReference::METHOD_REGEXP_STR
  # :startdoc:

  ##
  # RDoc::CodeObject for generating references

  attr_accessor :context

  ##
  # Should we show '#' characters on method references?

  attr_accessor :show_hash

  ##
  # Creates a new crossref resolver that generates links relative to +context+
  # which lives at +from_path+ in the generated files.  '#' characters on
  # references are removed unless +show_hash+ is true.  Only method names
  # preceded by '#' or '::' are linked, unless +hyperlink_all+ is true.

  def initialize(options, from_path, context, markup = nil)
    raise ArgumentError, 'from_path cannot be nil' if from_path.nil?

    super options, markup

    @context       = context
    @from_path     = from_path
    @hyperlink_all = @options.hyperlink_all
    @show_hash     = @options.show_hash

    @cross_reference = RDoc::CrossReference.new @context
  end

  # :nodoc:
  def init_link_notation_regexp_handlings
    add_regexp_handling_RDOCLINK

    # The crossref must be linked before tidylink because Klass.method[:sym]
    # will be processed as a tidylink first and will be broken.
    crossref_re = @options.hyperlink_all ? ALL_CROSSREF_REGEXP : CROSSREF_REGEXP
    @markup.add_regexp_handling crossref_re, :CROSSREF

    add_regexp_handling_TIDYLINK
  end

  ##
  # Creates a link to the reference +name+ if the name exists.  If +text+ is
  # given it is used as the link text, otherwise +name+ is used.

  def cross_reference(name, text = nil, code = true, rdoc_ref: false)
    lookup = name

    name = name[1..-1] unless @show_hash if name[0, 1] == '#'

    if !(name.end_with?('+@', '-@')) and name =~ /(.*[^#:])?@/
      text ||= [CGI.unescape($'), (" at <code>#{$1}</code>" if $~.begin(1))].join("")
      code = false
    else
      text ||= name
    end

    link lookup, text, code, rdoc_ref: rdoc_ref
  end

  ##
  # We're invoked when any text matches the CROSSREF pattern.  If we find the
  # corresponding reference, generate a link.  If the name we're looking for
  # contains no punctuation, we look for it up the module/class chain.  For
  # example, ToHtml is found, even without the <tt>RDoc::Markup::</tt> prefix,
  # because we look for it in module Markup first.

  def handle_regexp_CROSSREF(target)
    name = target.text

    return name if @options.autolink_excluded_words&.include?(name)

    return name if name =~ /@[\w-]+\.[\w-]/ # labels that look like emails

    unless @hyperlink_all then
      # This ensures that words entirely consisting of lowercase letters will
      # not have cross-references generated (to suppress lots of erroneous
      # cross-references to "new" in text, for instance)
      return name if name =~ /\A[a-z]*\z/
    end

    cross_reference name, rdoc_ref: false
  end

  ##
  # Handles <tt>rdoc-ref:</tt> scheme links and allows RDoc::Markup::ToHtml to
  # handle other schemes.

  def handle_regexp_HYPERLINK(target)
    url = target.text

    case url
    when /\Ardoc-ref:/
      cross_reference $', rdoc_ref: true
    else
      super
    end
  end

  ##
  # +target+ is an rdoc-schemed link that will be converted into a hyperlink.
  # For the rdoc-ref scheme the cross-reference will be looked up and the
  # given name will be used.
  #
  # All other contents are handled by
  # {the superclass}[rdoc-ref:RDoc::Markup::ToHtml#handle_regexp_RDOCLINK]

  def handle_regexp_RDOCLINK(target)
    url = target.text

    case url
    when /\Ardoc-ref:/
      cross_reference $', rdoc_ref: true
    else
      super
    end
  end

  ##
  # Generates links for <tt>rdoc-ref:</tt> scheme URLs and allows
  # RDoc::Markup::ToHtml to handle other schemes.

  def gen_url(url, text)
    if url =~ /\Ardoc-ref:/
      name = $'
      cross_reference name, text, name == text, rdoc_ref: true
    else
      super
    end
  end

  ##
  # Creates an HTML link to +name+ with the given +text+.

  def link(name, text, code = true, rdoc_ref: false)
    if !(name.end_with?('+@', '-@')) and name =~ /(.*[^#:])?@/
      name = $1
      label = $'
    end

    ref = @cross_reference.resolve name, text if name

    case ref
    when String then
      if rdoc_ref && @options.warn_missing_rdoc_ref
        puts "#{@from_path}: `rdoc-ref:#{name}` can't be resolved for `#{text}`"
      end
      ref
    else
      path = ref ? ref.as_href(@from_path) : +""

      if code and RDoc::CodeObject === ref and !(RDoc::TopLevel === ref)
        text = "<code>#{CGI.escapeHTML text}</code>"
      end

      if label
        # Convert label to GitHub-style anchor format
        # First convert + to space (URL encoding), then apply GitHub-style rules
        formatted_label = RDoc::Text.to_anchor(label.tr('+', ' '))

        # Case 1: Path already has an anchor (e.g., method link)
        #   Input:  C1#method@label -> path="C1.html#method-i-m"
        #   Output: C1.html#method-i-m-label
        if path =~ /#/
          path << "-#{formatted_label}"

        # Case 2: Label matches a section title
        #   Input:  C1@Section -> path="C1.html", section "Section" exists
        #   Output: C1.html#section (uses section.aref for GitHub-style)
        elsif (section = ref&.sections&.find { |s| label.tr('+', ' ') == s.title })
          path << "##{section.aref}"

        # Case 3: Ref has an aref (class/module context)
        #   Input:  C1@heading -> path="C1.html", ref=C1 class
        #   Output: C1.html#class-c1-heading
        elsif ref.respond_to?(:aref)
          path << "##{ref.aref}-#{formatted_label}"

        # Case 4: No context, just the label (e.g., TopLevel/file)
        #   Input:  README@section -> path="README_md.html"
        #   Output: README_md.html#section
        else
          path << "##{formatted_label}"
        end
      end

      "<a href=\"#{path}\">#{text}</a>"
    end
  end

  def convert_flow(flow_items, &block)
    res = []

    i = 0
    while i < flow_items.size
      item = flow_items[i]

      case item
      when RDoc::Markup::AttrChanger
        if !tidy_link_capturing? && (text = convert_tt_crossref(flow_items, i))
          text = block.call(text, res) if block
          append_flow_fragment res, text
          i += 3
          next
        end

        off_tags res, item
        on_tags  res, item
        i += 1
      when String
        text = convert_string(item)
        text = block.call(text, res) if block
        append_flow_fragment res, text
        i += 1
      when RDoc::Markup::RegexpHandling
        text = convert_regexp_handling(item)
        text = block.call(text, res) if block
        append_flow_fragment res, text
        i += 1
      else
        raise "Unknown flow element: #{item.inspect}"
      end
    end

    res.join('')
  end

  private

  ##
  # Detects <tt>...</tt> spans that contain a single cross-reference candidate.
  # When the candidate occupies the whole span (aside from trailing
  # punctuation), the tt markup is replaced by the resolved cross-reference.

  def convert_tt_crossref(flow_items, index)
    opener = flow_items[index]
    return unless tt_tag?(opener.turn_on)

    string = flow_items[index + 1]
    closer = flow_items[index + 2]

    return unless String === string
    return unless RDoc::Markup::AttrChanger === closer
    return unless tt_tag?(closer.turn_off, true)

    crossref_regexp = @options.hyperlink_all ? ALL_CROSSREF_REGEXP : CROSSREF_REGEXP
    match = crossref_regexp.match(string)
    return unless match
    return unless match.begin(1).zero?

    trailing = match.post_match
    # Only convert when the remainder is punctuation/whitespace so other tt text stays literal.
    return unless trailing.match?(/\A[[:punct:]\s]*\z/)

    text = cross_reference(string)
    return if text == string

    text
  end
end
