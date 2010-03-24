# -*- coding: utf-8 -*-

module OrgParse

  # syntax tree node
  #
  # _children_  is Node array
  #
  # === Node kind
  # - _ROOT_ :: RootNode
  #
  # lines (StructParser)
  # - _SECTION_ :: SectionNode
  # - _HEADLINE_ :: HeadlineNode
  # - _FN_DEFINE_ :: footnote definition
  # - _VARIABLE_ :: VarNode
  # - _WHITELINE_ :: WhitelineNode
  # - _TEXTBLOCK_ :: TextlineNode's list will become paragraph
  # - _TEXTLINE_  :: TextlineNode
  # - _QUOTE_ :: HTML quoted text
  # - _BLOCK_    :: BlockNode (verse, example, src, html, ...)
  # - _UNORDERED_LIST_ :: Unorderd list <UL>
  # - _ENUMLIST_ :: Ordered list <OL>
  # - _DESCLIST_ :: Description list <DL>
  # - _LISTITEM_ :: ListitemNode
  # - _TABLE_ :: TableNode
  # - _TABLE_SEP_ :: separator between th and td
  # - _TABLE_ROW_ :: TableRowNode
  #
  #  inlines (InlineParser)
  # - _BOLD_     :: bold
  # - _ITALIC_   :: italic
  # - _UNDER_LINE_ :: under line
  # - _VERBATIM_ :: verbatim
  # - _STRIKE_THROUGH_ :: strike through
  # - _CODE_     :: code
  # - _LINK_     :: LinkNode 参照
  # - _QUOTE_    :: @<br/> , #+HTML ... 等
  #
  class Node
    # Node type
    attr_accessor :kind
    # child nodes
    attr_accessor :children   
    # Node value
    attr_accessor :value 
    # Parent node
    attr_accessor :parent

    def initialize(kind = nil, children = [], value = nil)
      @kind = kind
      @children = children
      @value = value
      @done = false
      @parent = nil
      @verse = false
      @example = false
      @html = false
      @src = false
    end

    def set_verse
      @verse = true
    end

    def verse?
      @verse
    end

    def set_example
      @example = true
    end

    def example?
      @example
    end

    def set_src
      @src = true
    end

    def src?
      @src
    end

    def set_html
      @html = true
    end

    def html?
      @html
    end

    def done?
      @done
    end

    def done
      @done = true
    end

    def is_leaf?
      @children.empty?
    end

    #def is_container?
    #  [:SECTION, :TEXTBLOCK, :LISTITEM, :UNORDERED_LIST, :ENUMLIST, :DESCLIST, :BLOCK].include? @kind
    #end

    def inspect
      c = ''
      c  = @children.collect{|i| indent2(i.inspect)}.join("\n") if @children
      val = @value ? @value.to_s : '(nil)'
      val = val.is_a?( Array) ? val.join(",") : val.gsub("\n", ' ')
      "<#{self.class.name} #{@kind}:#{val}>" + (c.empty? ? "" : "\n") + c
    end

    def section_no_array
      if @section_no
        @section_no.split('.')
      else
        nil
      end
    end

    def set_to_descendant(method, val=nil)
      @children.each{|node|
        if val
          node.send method, *val
        else
          node.send method
        end
        node.set_to_descendant method, val
      }
    end

    private

    def indent2(str)
      buf = ''
      str.each_line{|i| buf << "  " << i }
      buf
    end
  end

  # Root
  #
  # 
  class RootNode < Node
    # options
    attr_reader :options
    attr_accessor :section_no

    def initialize(opts)
      super(:ROOT)
      @options = opts
      @section_no = "0"
    end

    def add(nodes)
      @children += nodes
    end
  end

  # セクション保持用
  #
  # _children[0]_ には、必ず Headline Nodeが入る
  #
  class SectionNode < Node
    attr_accessor :section_no

    # コンストラクタ
    # [_headline_] セクション開始の Headline
    # [_bodyitems_] セクションに含まれるブロック要素
    def initialize(headline, bodyitems)
      @section_no = "0"
      headline.parent = self
      super(:SECTION, bodyitems, headline)
    end

    # Headline のノードを返す
    def headline
      @value
    end
  end

  # Headline を保持するクラス
  class HeadlineNode < Node
    attr_reader :is_comment, :level

    def initialize(children, level)
      @is_comment = false
      @level = level.size
      super(:HEADLINE, children)
    end
  end

  # Whiteline
  class WhitelineNode < Node
    attr_reader :count
    def initialize
      super(:WHITELINE)
      @value = 1
    end
    def increment
      @value += 1
    end
    def count
      @value
    end
  end


  class TextlineNode < Node
    attr_reader :indent

    def initialize(children, vals)
      @indent = vals[1]
      super(:TEXTLINE, children, vals[0])
    end

  end

  # リストアイテム
  class ListitemNode < Node
    attr_reader :dt, :type

    def initialize(type, children, value, dt)
      @type = type
      @dt = dt
      super(:LIST_ITEM, children, value)
    end
  end

  # BLOCK の情報を保持
  class BlockNode < Node
    attr_reader :indent, :block_name, :syntax, :syntax_theme, :filename, :type
    def initialize(vals, children)
      @block_name = vals[0].upcase
      @line = vals[1]
      @indent = vals[2]
      @syntax = ''
      @syntax_theme = ''
      super(:BLOCK, children, vals[1])
      case @block_name
      when 'VERSE'
        set_to_descendant :set_verse
      when 'EXAMPLE'
        set_to_descendant :set_example
      when 'SRC'
        set_to_descendant :set_src
        if vals[1] =~ /SRC\s*([^\s]+)\s+([^\s]+)\s*$/i
          @syntax = $1.downcase
          @syntax_theme = $2.downcase
        elsif vals[1] =~ /SRC\s*(.+)\s*$/i
          @syntax = $1.downcase
        end
      when 'DOT'
        set_to_descendant :set_src
        if vals[1] =~ /DOT\s+(.+)\s+-T(.*)$/
          @filename = $1
          @type = $2
        else
          @block_name = 'SRC'
          @syntax = 'dot'
        end
      when 'HTML'
        set_to_descendant :set_html
      end
    end

    def line
      @value
    end
  end

  class TableNode < Node
    attr_reader :hrows

    def initialize(hrows, drows)
      hrows.each{|h| h.is_head = true }
      @hrows = hrows
      super(:TABLE, drows)
    end
  end

  # table row
  class TableRowNode < Node
    def initialize(cols, head = false)
      super(:TABLE_ROW, cols, head)
    end

    def is_head?
      @value
    end

    def is_head=(val)
      @value = val
    end
  end

  # Link保持
  #
  class LinkNode < Node
    attr_reader :html_options, :caption
    
    def initialize(uri, children = [], vars = [])
      @html_options = {}
      @caption = nil
      vars.each do |v|
        if v =~ /^CAPTION:(.+)$/
          @caption = $1.chomp
        else
          while v =~ /([^ =]+)=("[^"]+")/
            @html_options[$1] = $2
            v = $'
          end
        end
      end
      super(:LINK, children, uri)
    end

    # href
    def uri
      @value
    end
  end

  # オプション変数
  class VarNode < Node
    attr_reader :name

    def initialize(name, val)
      @name = val
      super(:VARIABLE, [], val)
    end
  end

end
