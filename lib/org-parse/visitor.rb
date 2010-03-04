# -*- coding: utf-8 -*-
require 'erb'

module OrgParse

  module VisitorBase

    def execute(node)
      puts "not implimented => #{node.inspect}"
    end

    def exec_list(nodes)
      ret = ''
      nodes.each{|n| ret += execute(n) }
      ret
    end

    def exec_children(node)
      exec_list node.children
    end
  end

  # todo: 
  # \\-    &shy;      \\-　
  # --    &ndash;    --
  # ---   &mdash;    ---
  # ...   &hellip;   \ldots

  # output HTML format
  class HtmlVisitor
    include VisitorBase
    TEMPLATE = ::File.join(OrgParse::LIBPATH , 'org-parse', 'templates', 'single.html.erb')
    attr_reader :body

    def initialize(root)
      image_exts = ['jpeg', 'jpg', 'png', 'gif', 'bmp', 'tiff']
      make_image_regs image_exts
      @body = @title = @add_to_head = ''
      @root = root
      @section_counts = [0,0,0,0,0,0,0,0,0]
      @erb = ERB.new(::File.read(TEMPLATE))
      @verse = false
      @p_tag_flag = true
      @list_level = 0
      @indent_stack = [0]
      @body = ''
      @curr_level = 0
      @para_level = 0
      @example = false
      @html = false
      @flash_vars = {}
      @options = {}
    end

    def make_image_regs(exts)
      @image_file_reg = /\.(#{exts.join('|')})$/
    end

    # section number
    #   like "1.1"
    def section_number(level)
      ret = @section_counts[0].to_s
      (level - 1).times do |i|
        ret += ".#{@section_counts[i+1]}"
      end
      ret
    end

    # update section number buffer
    def update_section_number(level)
      @section_counts[level - 1] += 1
      (level..(@section_counts.size - 1)).each {|i| @section_counts[i] = 0}
    end

    # remove all HTML tags
    def rm_html_tag(str)
      str.sub!(/<[^<>]*>/,"") while /<[^<>]*>/ =~ str
      str
    end

    # build the HTML string
    def build
      @title = @root.options[:title]
      @language = @root.options[:language]
      @charset = @root.options[:charset]
      @body = ''
      @root.children.each do |node|
        @body += execute(node)
      end
      @language = @root.options[:language]
      @erb.result(binding)
    end

    def section_indent(level = nil)
      level = @curr_level if level.nil?
      '    ' * level
    end

    def section(node)
      @curr_level = node.headline.level
      update_section_number @curr_level
      indent = section_indent(@curr_level - 1)
      %Q|#{indent}<div id="outline-container-#{@curr_level+1}" class="outline-#{@curr_level+1}">
#{indent}  #{headline node.headline}
#{indent}  <div class="outline-text-#{@curr_level+1}" id="text-#{@curr_level+1}">
#{exec_children node}
#{indent}  </div>
#{indent}</div>
|
    end

    def headline(node)
        level = node.level+1
        index_str = section_number(node.level)
      %Q|<h#{level} id="sec-#{index_str}"><span class="section-number-#{level}">#{index_str}</span> #{exec_children(node).chomp}</h#{level}>|
    end

    def get_indent
      base = section_indent
      base += ('  ' * @list_level)
      base += ('  ' * @para_level)
    end

    # paragraph 
    # if @p_tag_flag == false then we do'nt output <p></p> tags.
    def textblock(node)
      if @p_tag_flag
        indent = get_indent
        @para_level += 1
        str = "#{indent}<p>\n#{exec_children(node).chomp}\n#{indent}</p>\n"
        @para_level -= 1
        str
      else
        str = exec_children node
        @p_tag_flag = true  # next paragraph has <p>
        str
      end
    end

    # list_item 
    def list_item(node)
      indent = get_indent
      if node.children.empty?
        "#{indent}<li>#{exec_list(node.value).chomp}</li>\n"
      else
        @list_level += 1
        @p_tag_flag = false
        str = get_indent + exec_list(node.value)
        str += exec_children node
        str = "#{indent}<li>\n#{str.chomp}\n#{indent}</li>\n"
        @p_tag_flag = true
        @list_level -= 1
        str
      end
    end

    def verse(node)
      pre = get_indent + %Q|<p class="verse">\n|
      post = get_indent + "</p>\n"
      @indent_stack << node.indent
      @verse = true
      @para_level += 1
      @p_tag_flag = false
      body = exec_children node
      @p_tag_flag = true
      @verse = false
      @para_level -= 1
      @indent_stack.pop
      pre + body.chomp + "\n" + post
    end

    def example(node)
      @example = true
      indent = get_indent
      # STDERR.puts "-->" + node.children[0].inspect
      this_indent = 0
      if node.children[0].kind == :TEXTBLOCK
        this_indent = node.children[0].children[0].indent
      elsif node.children[0].kind == :TEXTLINE
        this_indent = node.children[0].indent
      end
      @indent_stack << this_indent
      @p_tag_flag = false
      body = exec_children(node)
      @p_tag_flag = true
      @indent_stack.pop
      @example = false
      %Q|#{indent}<pre class="example">\n#{ body.chomp }\n#{indent}</pre>\n|
    #rescue
    #  ''
    end

    def html_quote(node)
      @html = true
      indent = get_indent
      @indent_stack << node.children[0].children[0].indent
      @p_tag_flag = false
      body = exec_children(node)
      @p_tag_flag = true
      @indent_stack.pop
      @html = false
      body
    end

    def blockquote(node)
      indent = get_indent
      # @p_tag_flag = false
      @para_level += 1
      body = exec_children(node)
      @para_level -= 1
      %Q|#{indent}<blockquote>\n#{body.chomp}\n#{indent}</blockquote>\n|
    end

    def blocks(node)
        case node.block_name
        when 'VERSE'
          verse node
        when 'EXAMPLE'
          example node
        when 'QUOTE'
          blockquote node
        when 'HTML'
          html_quote node
        when 'COMMENT'
          ''
        when 'SRC'
          example node
        else
          puts "not implimented block=>[#{node.block_name}](#{node.inspect})"
          exec_children(node)
        end
    end

    def textline(node)
      # p node
      if @example
        indent = ' ' * @indent_stack.last 
        return h node.value.sub(/^#{indent}/,'')
      elsif @html
        return node.value
      else
        indent = get_indent
        str = exec_children(node).sub(/^\s*/, '')
        if @verse
          n = node.indent - @indent_stack.last
          n = 0 if n < 0
          indent = '&nbsp;&nbsp;' * n
          indent + str.sub(/\n/, "<br/>\n")
        else
          indent + str
        end
      end
    end

    def image_tag(uri, attr = '')
      %Q|<img src="#{uri.sub(/^file:/,'')}#{attr}">|
    end

    def link(node)
      attr = ''
      attr = " #{@flash_vars['ATTR_HTML']}" if @flash_vars['ATTR_HTML']
      
      desc = nil
      desc = exec_children node unless node.is_leaf?
      if desc and desc =~ @image_file_reg
        desc = image_tag desc, attr
      end

      link = nil
      if node.uri =~ @image_file_reg 
        link = image_tag node, attr unless desc
      else
        desc = ''
        if node.is_leaf?
          desc = node.value
        else
          desc = exec_children node 
        end
        if desc =~ @image_file_reg
          desc = %Q|<img src="#{desc.sub(/^file:/,'')}">|
        end
        %Q|<a href="#{node.uri.sub(/^file:/, '')}">#{ desc }</a>|
      end
    end

    def table(node)
      indent = get_indent
      ret = indent + %Q|<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">\n|
      ret += indent + '  ' + %Q|<caption></caption>\n|
      #ret += indent + '  ' + %Q|<colgroup><col align="left" /><col align="left" /><col align="left" /></colgroup>\n|
      ret += indent + '  ' + "<tbody>\n"
      ret += exec_list node.hrows
      ret += exec_children node
      ret += indent + '  ' + "</tbody>\n"
      ret += indent + "</table>"
    end
      
    def table_row(node)
      indent = get_indent + "    "
      ret = ""
      s = node.is_head? ? '<th>' : '<td>'
      e = node.is_head? ? '</th>' : '</td>'
      node.children.each {|col|
        ret += s + exec_list(col) + e
      }
      indent + "<tr>\n  " + indent + ret + "\n" + indent + "</tr>\n"
    end

    def variable(node)
      fvs = ['CAPTION', 'ATTR_HTML', 'TEXT']
      if fvs.include? node.name
        @flash_vars[node.name] = node.value
      else
        @options[node.name] = node.value
      end
    end

    def clear_vars
      @flash_vars.clear
    end

    # unordered list
    def itemlist(node)
      indent = get_indent
      @list_level += 1
      body = exec_children node
      @list_level -= 1
      "#{indent}<ul>\n#{body.chomp}\n#{indent}</ul>\n"
    end

    def execute(node)
      # puts "node:#{node.kind} #{node.value}\n"
      # STDERR.puts "-----[#{@example}/#{@verse}]-----"
      # STDERR.puts node.inspect
      return '' if node.done?
      case node.kind
      when :SECTION
        section node
      when :HEADLINE
        headline node
      when :TEXTBLOCK
        textblock node
      when :WHITELINE, :WHITELINES
        "\n" * node.value
      when :STRING
        h node.value
      when :QUOTE
        if node.value == "\n"
          '<br/>'
        else
          node.value
        end
      when :TEXTLINE
        textline node
      when :EMPHASIS
        "<b>#{ exec_children node }</b>"
      when :ITALIC
        "<i>#{ exec_children node }</i>"
      when :UNDER_LINE
        %Q|<span style="text-decoration: underline;">#{exec_children node}</span>|
      when :STRIKE_THROUGH
        "<del>#{ exec_children node}</del>"
      when :CODE, :VERBATIM
        "<code>#{ exec_children node }</code>"
      when :VARIABLE
        variable node
      when :ITEMLIST
        itemlist node
      when :LIST_ITEM
        list_item node
      when :LINK
        link node
      when :BLOCK
        blocks node
      when :TABLE
        table node
      when :TABLE_ROW
        table_row node
      else
        puts "not implimented=>[#{node.kind}](#{node.inspect})"
        ''
      end
    end

    # HTML escape
    def html_escape(s)
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    alias h html_escape

  end

end
