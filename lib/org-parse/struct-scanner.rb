# -*- coding: utf-8 -*-
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'inline-parser.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'utils.rb')
require 'yaml'


module OrgParse

  # Org-modeの文字列を、構造レベルのトークンに分解する
  # 
  # 処理は、行単位で行う
  #
  class StructScanner
    include Utils
    include InlineUtils

    GENERATOR = "OrgParse #{VERSION} Powered by Ruby #{RUBY_VERSION}"

    ListSymbols = {
      :UL_START => :UL_END, :OL_START => :OL_END,
      :DL_START => :DL_END,
    }

    # コンストラクタ
    # [_src_] ソース文字列（または、文字列の配列）
    #         ソース文字列は、1行単位の配列として @srcに保存する
    # [_title_] skip:t の場合にタイトルとして使われる
    def initialize(src, title)
      @src = (src.is_a? Array) ? src : src.to_a
      @line_idx = 0
      @outline_level = 0
      @nest_stack = []
      @token_que = []
      @section_stack = []
      @options = { :H => 3, :skip => false, :toc => true, :num => true,
        :author => nil, 
        :url => nil,
        :email => nil,
        :creator => GENERATOR, :timestamp => true,
        :title => nil, :text => [], :language => 'ja', :charset => 'utf-8',
        :default_title => title, :style => '', :uv => true,
      }
      read_options
      opt = YAML.dump @options
      File.open('dot.rc2', "w") {|f|
        f.write opt
      }
      # p @options
    end

    # http://orgmode.org/manual/Export-options.html#Export-options
    def read_options
      @src.reject! do |line|
        m = true
        case line
        when /^\s*#\+OPTIONS:\s/i
          case $'
          when /H:([0-9]+)/
            @options[:H] = $1.to_i
          when /skip:(\w)/
            @options[:skip] = $1 != 'nil'
          when /num:(\w+)/
            @options[:num] = $1 != 'nil'
          when /toc:(\w+)/
            @options[:toc] = $1 != 'nil'
          when /author:(\w+)/
            @options[:author] = $1 != 'nil'
          when /creator:(\w+)/
            @options[:creator] = $1 != 'nil'
          when /timestamp:(\w+)/
            @options[:timestamp] = $1 != 'nil'
          when /uv:(\w+)/
            @options[:uv] = $1 != 'nil'
          else
            m = false
          end
        when /^\s*#\+TITLE:\s+(.*)$/i
          @options[:title] = $1
        when /^\s*#\+TEXT:\s+(.*)$/i
          @options[:text] += line_parse($1 + "\n")
        when /^\s*#\+LANGUAGE:\s+(.*)/i
          @options[:language] = $1
        when /^\s*#\+AUTHOR:\s*(.*)/i
          @options[:author] = $1
        when /^\s*#\+EMAIL:\s*(.*)/i
          @options[:email] = $1
        when /^\s*#\+STYLE:\s*(.*)$/i
          @options[:style] += $1
        else
          m = false
        end
        m
      end
    end
    
    def next_token
      return [[false, false],[]] if @token_que.empty?
      # p @token_que[0]
      token = @token_que.shift
      vars = []

      while token[0] == :VARIABLELINE and (token[1][0] == "ATTR_HTML" or token[1][0] == "CAPTION")
        if token[1][0] == "CAPTION"
          vars << "CAPTION:" + token[1][1]
        else
          vars << token[1][1]
        end
        return [[false, false], []] if @token_que.empty?
        token = @token_que.shift
      end
      [token, vars]
    end

    # リスト開始ラインのネストをチェックする
    # @nest_stack が、空なら新規リストの開始
    # @nest_stack.last のインデントよりも、インデントが深ければ、
    # ネストしたリストの開始
    # @nest_stack.last のインデントとインデントが等しければ
    # 新規のリストアイテムの開始
    # @nest_stack.last のインデントよりインデントが浅ければ、
    # @nest_stack.last のリストの終了後、新規リストを開始
    def check_nest(kind, indent, string, dt = '')
      last = @nest_stack.last
      if @nest_stack.empty? 
        # puts "0: line: #{line.chomp}  indent: #{indent} last: #{last.inspect}"
        @nest_stack << [kind, indent]
        @token_que << [kind, string]
        @token_que << [:LI_START, [kind, string, dt]]
      elsif last[1] < indent
        # puts "1: line: #{line.chomp}  indent: #{indent} last: #{last.inspect}"
        @nest_stack << [kind, indent]
        # @token_que << [:LI_END, line]
        @token_que << [kind, string]
        @token_que << [:LI_START, [kind, string, dt]]
      elsif last[1] > indent
        # puts "2: line: #{line.chomp}  indent: #{indent} last: #{last.inspect}"
        nest = @nest_stack.pop
        @token_que << [:LI_END, string]
        @token_que << [ListSymbols[nest[0]], ListSymbols[nest[0]]]
        check_nest kind, indent, string
      else
        # puts "3: line: #{line.chomp}  indent: #{indent} last: #{last.inspect}"
        @token_que << [:LI_END, string]
        @token_que << [:LI_START, [kind, string, dt]]
      end
    end

    # if in list then exit list.
    def exit_nests(line)
      indent = get_indent line
      while @nest_stack.last and @nest_stack.last[1] >= indent
        nest = @nest_stack.pop
        @token_que << [:LI_END, line]
        @token_que << [ListSymbols[nest[0]], line]
      end
    end

    def exit_section(level)
      cnt = 0
      while @section_stack.last and @section_stack.last >= level
        @token_que << [:SEC_END, level]
        @section_stack.pop
      end
    end

    def skip_to_1st_headline
      @line_idx += 1 while @src[@line_idx] !~ /^\*\s+[^\s]/
    end

    # scan before 1st headline
    def scan_before_1st_headline
      title = nil
      if @options[:title]
        title =@options[:title]
        skip_to_1st_headline if @options[:skip]
      elsif @options[:skip]
        skip_to_1st_headline
        title = @options[:default_title]
      else
        @line_idx += 1 while @src[@line_idx] =~ /^\s*$/
        title = @src[@line_idx].chomp.sub(/^\s*/, '')
        if title =~ /^\*+\s*/
          title = @options[:default_title]
        else
          @line_idx += 1
        end
      end
      @options[:title] = line_parse title
    end

    # split to tokens from @src array and set to @token_que
    def scan
      @line_idx = 0
      scan_before_1st_headline
      example_flag = false
      @token_que << [:DOCUMENT_START, @options]
      while @line_idx < @src.size
        line = @src[@line_idx]
        if example_flag && line !~ /^\s*#\+end_(example|html|src|dot)/i
          @token_que << [:TEXTLINE, [line, get_indent(line)]]
          @line_idx += 1
          next
        end

        case line
        when /^\s*$/ # WHITELINE
          @token_que << [:WHITELINE, line]
        when /^(\*+)(\s+)COMMENT(\s)/
          @line_idx += 1
          @line_idx += 1 while @src[@line_idx] and @src[@line_idx] !~ /^\*+\s/
          @line_idx -= 1 if @src[@line_idx]
        when /^(\*+)(\s+)/
          rest = $'
          level = $1
          exit_nests('')
          exit_section(level.size)
          @section_stack << level.size
          @token_que << [:HEADLINE, [level, rest]]
        when /^(\s*)-\s(.+)\s::\s+/
          # Definition LIST
          rest = $'
          check_nest :DL_START, get_indent($1), rest, $2
        when /^(\s*)[-+*]\s/
          # Unordered LIST
          rest = $'
          check_nest :UL_START, get_indent($1), rest
        when /^(\s*)[0-9]+(\.|\))\s+/
          # Ordered LIST
          rest = $'
          check_nest :OL_START, get_indent($1), rest
        when /^\s*#\+HTML:/
          # #+HTML
          rest = $'
          @token_que << [:QUOTE, $']
        when /^\s*#\+([^ :]+):\s*(.+)$/
          @token_que << [:VARIABLELINE, [$1.upcase, $2.chomp]]
        when /^(\s*):\s(.*)$/
          @token_que << [:EXAMPLE, [$2+"\n", get_indent($1)]]
        when /^\s*#\+BEGIN_([A-Z0-9_]+)/i # BLOCK
          block_name = $1.upcase
          exit_nests line
          @token_que << [:BLOCK_START, [block_name, line, get_indent(line)]]
          example_flag = true if ['EXAMPLE', 'HTML', 'SRC', 'DOT'].include? block_name.upcase
        when /^\s*#\+END_([A-Z0-9_]+)/i # BLOCK
          block_name = $1
          exit_nests line
          @token_que << [:BLOCK_END, [block_name, line]]
          example_flag = false
        when /^\s*\|[-\|\+]*\s*$/ # table separator
          # an org-mode table separator has the first non-whitespace
          # character as a | (pipe), then consists of nothing else other
          # than pipes, hyphens, and pluses.
          exit_nests line
          @token_que << [:TABLE_SEP, line]
        when /^\s*\|/             # table_row
          # the first non-whitespace character is a | (pipe).
          exit_nests line
          @token_que << [:TABLE_ROW, line]
        when /^\s*\[fn:([^\]]+)\]\s+(.+)$/
          exit_nests line
          @token_que << [:FOOTNOTE, [$1, $2]]
        else
          exit_nests line
          @token_que << [:TEXTLINE, [line, get_indent(line)]]
        end
        @line_idx += 1
      end
      exit_nests ''
      exit_section(0)
    end
  end
end
