# -*- coding: utf-8 -*-
require 'rubygems'
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'visitor.rb')

module OrgParse

  # todo: 
  # \\-    &shy;      \\-　
  # --    &ndash;    --
  # ---   &mdash;    ---
  # ...   &hellip;   \ldots

  # output HTML format
  class TextileVisitor < OrgVisitor
    include VisitorUtils

    def initialize(root, cm_opts = {})
      @body = @title = @add_to_head = ''
      @root = root
      @ul_stack = []
      @list_level = 0
      @body = ''
      @options = cm_opts
      super()
    end

    # build the textile
    def build
      @options = @root.options
      @before_text = exec_list @options[:text]
      title = exec_list @root.options[:title]
      body = "h1. " + title + "\n\n" + @before_text
      @footnotes = []
      @footnote_idxs = []
      start_flag = true
      @root.children.each do |node|
        if start_flag and node.kind != :SECTION
          @before_text += execute(node)
        else
          start_flag = false
          body += execute(node)
        end
      end
      body += footnotes
    end

    def headline(node)
      level = node.level+1
      %Q|\nh#{level}. #{exec_children(node).chomp}\n\n|
    end

    # paragraph 
    # if @p_tag_flag == false then we don't output <p></p> tags.
    def textblock(node)
      if node.verse? or node.example? or node.html? or node.src?
        exec_children node
      elsif @p_tag_flag
        "p. #{exec_children(node).sub(/^\s*/,'').chomp}\n"
      else
        str = exec_children node
        @p_tag_flag = true  # next paragraph has <p>
        str
      end
    end

    def textline(node)
      str = exec_children(node)
      str = h str unless node.verse? or node.example? or node.html? or node.src?
      str
    end

    def example(node)
      body = exec_children(node)
      %Q|<pre>\n#{ body.chomp }\n</pre>\n|
    end

    def src(node)
      if @options[:redmine]
        text = exec_children(node)
        syntax = node.syntax
        %Q|<pre><code class="#{syntax}">\n#{ body.chomp }\n</code></pre>\n|
      else
        example node
      end
    end

    def blockquote(node)
      body = exec_children(node)
      body.sub(/\n/, '<br/>')
      %Q|\nbq.#{body.sub(/^\s*/,'').chomp}\n\n|
    end

    def blocks(node)
      case node.block_name
      when 'VERSE'
        example node
      when 'EXAMPLE'
        example node
      when 'QUOTE'
        blockquote node
      when 'HTML'
        textblock node
      when 'COMMENT'
        ''
      when 'SRC'
        src node
      else
        puts "not implimented block=>[#{node.block_name}](#{node.inspect})"
        exec_children(node)
      end
    end

    def link(node)
      desc = exec_children node
      if desc.empty?
        if node.uri =~ @image_file_reg
          " !#{node.uri.sub(/^file:/, '')}! "
        else
          " #{node.uri.sub(/^file:/, '')} "
        end
      else
        %Q| "#{desc}":#{node.uri.sub(/^file:/, '')} |
      end
    end

    def table(node)
      ret = ''
      ret += exec_list node.hrows
      ret += exec_children node
    end
      
    def table_row(node)
      ret = ''
      s = node.is_head? ? '|_.' : '|'
      node.children.each {|cols|
        cols.each{|col|
          ret += s + execute(col)
        }
      }
      ret += "|\n"
    end

    def variable(node)
      fvs = ['CAPTION', 'ATTR_HTML', 'TEXT']
      if fvs.include? node.name
        @flash_vars[node.name] = node.value
      else
        @options[node.name] = node.value
      end
      ''
    end

    def clear_vars
      @flash_vars.clear
    end

    def lists(node)
      tags = { :UNORDERED_LIST => ['<ul>', '</ul>'],
        :ORDERED_LIST => ['<ol>', '</ol>'],
        :DEFINITION_LIST => ['<dl>', '</dl>'],
      }
      @list_level += 1
      body = exec_children node
      @list_level -= 1
      if node.kind == :DEFINITION_LIST
        "#{tags[node.kind][0]}\n#{body.chomp}\n#{tags[node.kind][1]}\n"
      else
        body
      end
    end

    # list_item 
    def list_item(node)
      marks = { :UL_START => '*', :OL_START => '#' }
      if node.children.empty?
        if node.type == :DL_START
          "  <dt>#{exec_list(node.dt)}</dt>\n  <dd>#{exec_list(node.value).chomp}</dd>\n"
        else
          mark = marks[node.type] * @list_level
          "#{mark} #{exec_list(node.value).chomp}\n"
        end
      else
        @list_level += 1
        @p_tag_flag = false
        str = exec_list(node.value)
        str += exec_children node
        str.sub(/\n/, '<br/>')
        if node.type == :DL_START
          str = "  <dt>#{exec_list(node.dt)}</dt>\n  <dd>\n#{str.chomp}</dd>\n"
        else
          mark = marks[node.type] * @list_level
          str = "#{mark} #{str.chomp}\n"
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
      "[#{idx}]"
    end

    def footnote_define(node)
      idx = @footnote_idxs.index node.value
      unless idx
        idx = @footnote_idxs.size
        @footnote_idxs << node.value
      end
      @footnotes[idx] = exec_children(node)
      ''
    end

    def footnotes
      ret = ''
      @footnotes.each_index{|idx|
        n = idx+1
        val = @footnotes[idx]
        ret += "fn#{n}. #{val}\n"
      }
      ret
    end

    def execute(node)
      # puts "node:#{node.kind} [#{node.value}]\n"
      # STDERR.puts node.inspect
      return '' if node.done?
      case node.kind
      when :SECTION
        str = execute node.headline
        str += exec_children node # section node
      when :HEADLINE
        headline node
      when :TEXTBLOCK
        textblock node
      when :WHITELINE, :WHITELINES
        "\n" * node.value
      when :STRING
        node.value
      when :QUOTE
        if node.value == "\n"
          '<br/>'
        else
          node.value
        end
      when :TEXTLINE
        textline node
      when :EMPHASIS
        " *#{ exec_children node }* "
      when :ITALIC
        " _#{ exec_children node }_ "
      when :UNDER_LINE
        %Q| +#{exec_children node}+ |
      when :STRIKE_THROUGH
        " -#{ exec_children node}- "
      when :CODE, :VERBATIM
        " @#{ exec_children node }@ "
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
      s.to_s.gsub(/&/, "&amp;").gsub(/>/, "&gt;").gsub(/</, "&lt;")
    end
    alias h html_escape

  end

end
