# -*- coding: utf-8 -*-
require 'rubygems'
require 'erb'
require 'uv'

module OrgParse

  module VisitorBase

    def execute(node)
      puts "not implimented => #{node.inspect}"
    end

    def exec_list(nodes)
      ret = ''
      # p nodes
      nodes.each{|n| ret += execute(n) }
      ret
    rescue
      STDERR.puts "---"
      STDERR.puts nodes.inspect
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

    def initialize(root, template = nil, cm_opt = {})
      image_exts = ['jpeg', 'jpg', 'png', 'gif', 'bmp', 'tiff', 'srg']
      make_image_regs image_exts
      @body = @title = @add_to_head = ''
      @root = root
      @ul_stack = []
      template = TEMPLATE unless template
      @erb = ERB.new(::File.read(template))
      @p_tag_flag = true
      @list_level = 0
      @indent_stack = [0]
      @body = ''
      @curr_level = 0
      @para_level = 0
      @options = cm_opt
    end

    def make_image_regs(exts)
      @image_file_reg = /\.(#{exts.join('|')})$/
    end

    # remove HTML tags
    def rm_html_tag(str)
      str.sub!(/<[^<>]*>/,"") while /<[^<>]*>/ =~ str
      str
    end

    # build the HTML string
    def build
      @options = @root.options
      @title = exec_list @root.options[:title]
      @language = @root.options[:language]
      @charset = @root.options[:charset]
      @body = ''
      @footnotes = []
      @footnote_idxs = []
      @before_text = ''
      @before_text = exec_list @options[:text] # .each {|n| @before_text += execute(n)}
      @add_to_head = @options[:style]
      start_flag = true
      @root.children.each do |node|
        if start_flag and node.kind != :SECTION
          @before_text += execute(node)
        else
          start_flag = false
          @body += execute(node)
        end
      end
      @language = @root.options[:language]
      @erb.result(binding)
    end

    def section_indent(level = nil)
      level = @curr_level if level.nil?
      '    ' * level
    end

    def get_indent
      base = section_indent
      base += ('  ' * @list_level)
      base += ('  ' * @para_level)
    end

    def close_ul_sec(level)
      str = ''
      while @ul_stack.last and @ul_stack.last > level
        indent = section_indent(@ul_stack.last - 1)
        @ul_stack.pop
        str += "#{indent}</ul>\n"
      end
      str
    end

    def table_of_contents
      toc = "<ul>\n"
      @root.children.each {|node|
        if node.kind == :SECTION
          toc += toc_out node
        end
      }
      toc += "</ul>\n"
      return '' if toc == "<ul>\n</ul>\n"
      ret =<<"EOS"
<div id="table-of-contents">
  <h2>Table of Contents</h2>
  <div id="text-table-of-contents">
#{toc}
  </div>
</div>
EOS
    end

    def toc_out(node)
      curr_level = node.headline.level
      idx_no = node.section_no
      str = toc_headline node.headline
      ret = %Q|<li><a href="#sec-#{idx_no}">#{idx_no} #{str}</a>|
      has_child = false
      node.children.each {|node|
        if node.kind == :SECTION
          ret += "\n<ul>\n" unless has_child
          has_child = true
          ret += toc_out node
        end
      }
      if has_child
        ret += "</ul>\n"
        ret += "</li>\n"
      end
      ret
    end

    def toc_headline(node)
      str = ''
      node.children.each do |item|
        unless item.kind == :FN_LINK
          str += execute item
        end
      end
      str
    end

    def section(node)
      curr_level = node.headline.level

      @curr_level = curr_level
      indent = section_indent(curr_level - 1)
      idx_no = node.section_no
      if curr_level > @options[:H]
        str = close_ul_sec(curr_level)
        if @ul_stack.last and @ul_stack.last == curr_level
          str += %Q|#{indent}  <li id="sec-#{idx_no}">#{exec_children node}</li>\n|
        else
          str += "#{indent}<ul>\n"
          @ul_stack << curr_level
          str += %Q|#{indent}  <li id="sec-#{idx_no}">#{exec_children node}</li>\n|
        end
        str
      else
        %Q|#{close_ul_sec(curr_level).chomp}
#{indent}<div id="outline-container-#{idx_no}" class="outline-#{curr_level+1}">
#{indent}  #{headline node.headline}
#{indent}  <div class="outline-text-#{@curr_level+1}" id="text-#{idx_no}">
#{exec_children node}
#{close_ul_sec(curr_level).chomp}
#{indent}  </div>
#{indent}</div>
|
      end
    end

    def headline(node)
      level = node.level+1
      index_str = node.parent.section_no
      %Q|<h#{level} id="sec-#{index_str}"><span class="section-number-#{level}">#{index_str}</span> #{exec_children(node).chomp} </h#{level}>|
    end

    # paragraph 
    # if @p_tag_flag == false then we do'nt output <p></p> tags.
    def textblock(node)
      if node.verse? or node.example? or node.html? or node.src?
        exec_children node
      elsif @p_tag_flag
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

    def textline(node)
      if node.example? or (node.src? and !@options[:uv])
        indent = ' ' * @indent_stack.last 
        return h node.value.sub(/^#{indent}/,'')
      elsif node.src? and @options[:uv]
        return node.value
      elsif node.html?
        return node.value
      else
        indent = get_indent
        str = exec_children(node).sub(/^\s*/, '')
        if node.verse?
          n = node.indent - @indent_stack.last
          n = 0 if n < 0
          indent = '&nbsp;&nbsp;' * n
          indent + str.gsub(/\n/, "<br/>\n")
        else
          indent + str
        end
      end
    end

    def verse(node)
      pre = get_indent + %Q|<p class="verse">\n|
      post = get_indent + "</p>\n"
      @indent_stack << node.indent
      body = exec_children node
      @indent_stack.pop
      pre + body.chomp + "\n" + post
    end

    def example(node)
      indent = get_indent
      this_indent = 0
      this_indent = node.children[0].children[0].indent
      @indent_stack << this_indent
      body = exec_children(node)
      @indent_stack.pop
      %Q|<pre class="example">\n#{ body.chomp }\n</pre>\n|
    end

    def src(node)
      if @options[:uv]
        text = exec_children(node)
        syntax = node.syntax
        syntax = 'lisp' if syntax == 'emacs-lisp'
        theme = node.syntax_theme
        theme = 'amy' if theme.empty?
        begin
          Uv.parse( text, "xhtml", syntax, true, theme)
        rescue
          "uv can't parse #{syntax}/#{theme} <br>\n" + example(node)
        end
      else
        example node
      end
    end

    def html_quote(node)
      indent = get_indent
      @indent_stack << node.children[0].children[0].indent
      body = exec_children(node)
      @indent_stack.pop
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
          src node
        else
          puts "not implimented block=>[#{node.block_name}](#{node.inspect})"
          exec_children(node)
        end
    end

    def image_tag(uri, attr = '')
      %Q|<img src="#{uri.sub(/^file:/,'')}"#{attr}/>|
    end

    def link(node)
      if node.caption.nil?
        mk_link(node)
      else
        %Q|<div class="figure">
  <p>#{mk_link(node)}</p>
  <p>#{node.caption}</p>
</div>
|
      end
    end

    def mk_link(node)
      a_attrs = ['href', 'name', 'target', 'charset', 'hreflang', 'type', 'rel', 'rev', 
                 'tabindex', 'accesskey', 'shape', 'coords']
      a_attr = ''
      img_attr = ''
      node.html_options.each do |k, v|
        if a_attrs.include? k
          a_attr = ' ' if a_attr.empty?
          a_attr += "#{k}=#{v}"
        else
          img_attr = ' ' if img_attr.empty?
          img_attr += "#{k}=#{v} "
        end
      end
      
      desc = ''
      desc = exec_children node

      if desc.empty?
        if node.uri =~ @image_file_reg
          image_tag(node.uri, a_attr+img_attr)
        else
          %Q|<a href="#{node.uri.sub(/^file:/,'')}"#{a_attr+img_attr}>node.uri</a>|
        end
      else
        if desc =~ @image_file_reg
          desc = image_tag desc, img_attr
        else
          a_attr += img_attr
        end
        %Q|<a href="#{node.uri.sub(/^file:/,'')}"#{a_attr+img_attr}>#{desc}</a>|
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

    def lists(node)
      tags = { :UNORDERED_LIST => ['<ul>', '</ul>'],
        :ORDERED_LIST => ['<ol>', '</ol>'],
        :DEFINITION_LIST => ['<dl>', '</dl>'],
      }
      indent = get_indent
      @list_level += 1
      body = exec_children node
      @list_level -= 1
      "#{indent}#{tags[node.kind][0]}\n#{body.chomp}\n#{indent}#{tags[node.kind][1]}\n"
    end

    # list_item 
    def list_item(node)
      indent = get_indent
      if node.children.empty?
        if node.type == :DL_START
          "#{indent}<dt>#{exec_list(node.dt)}</dt>\n#{indent}<dd>#{exec_list(node.value).chomp}</dd>\n"
        else
          "#{indent}<li>#{exec_list(node.value).chomp}</li>\n"
        end
      else
        @list_level += 1
        @p_tag_flag = false
        str = get_indent + exec_list(node.value)
        str += exec_children node
        if node.type == :DL_START
          str = "#{indent}<dt>#{exec_list(node.dt)}</dt>\n#{indent}<dd>\n#{str.chomp}\n#{indent}</dd>\n"
        else
          str = "#{indent}<li>\n#{str.chomp}\n#{indent}</li>\n"
        end
        @p_tag_flag = true
        @list_level -= 1
        str
      end
    end

    def footnote_link(node)
      idx = @footnote_idxs.index node.value
      unless idx
        idx = @footnote_idxs.size
        @footnote_idxs << node.value
      end
      idx += 1
      %Q|<sup><a class="footref" name="fnr.#{idx}" href="#fn.#{idx}">#{idx}</a></sup> |
    end

    def footnote_define(node)
      idx = @footnote_idxs.index node.value
      unless idx
        idx = @footnote_idxs.size
        @footnotes_idxs << node.value
      end
      @footnotes[idx] = exec_children(node)
      ''
    end

    def footnotes
      ret = ''
      @footnotes.each_index{|idx|
        n = idx+1
        val = @footnotes[idx]
        ret += %Q|<p class="footnote"><sup><a class="footnum" name="fn.#{n}" href="#fnr.#{n}">#{n}</a></sup> #{val}</p>\n|
      }
      ret
    end

    def execute(node)
      # puts "node:#{node.kind} [#{node.value}]\n"
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
        @p_tag_flag = true
        if node.verse?
          "<br>\n" * node.value
        else
          "\n" * node.value
        end
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
      when :UNORDERED_LIST, :ORDERED_LIST, :DEFINITION_LIST
        lists node
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
      when :FN_LINK
        footnote_link node
      when :FN_DEFINE
        footnote_define node
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
