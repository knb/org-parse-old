# -*- coding: utf-8 -*-

module OrgParse

  # syntax tree node
  #
  # [_kind_] Node kind
  # [_children_] Child Nodes
  # [_value_] Value of Node
  #
  # _children_  is Node array
  #
  # === Node kind
  # - _ROOT_ :: RootNode
  #
  # lines
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
  #  inline's
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
    attr_accessor :kind, :children, :value

    def initialize(kind = nil, children = [], value = nil)
      @kind = kind
      @children = children
      @value = value
      @done = false
    end

    def done?
      @done
    end

    def done
      @done = true
    end

    # 葉ノードか？
    def is_leaf?
      @children.empty?
    end

    # コンテナノードか？
    def is_container?
      [:SECTION, :TEXTBLOCK, :LISTITEM, :UNORDERED_LIST, :ENUMLIST, :DESCLIST, :BLOCK].include? @kind
    end

    # 見やすく表示
    def inspect
      c = ''
      c  = @children.collect{|i| indent2(i.inspect)}.join("\n") if @children
      val = @value ? @value.to_s : '(nil)'
      val = val.is_a?( Array) ? val.join(",") : val.gsub("\n", ' ')
      "<#{self.class.name} #{@kind}:#{val}>" + (c.empty? ? "" : "\n") + c
    end

    def indent2(str)
      buf = ''
      str.each_line{|i| buf << "  " << i }
      buf
    end
    private :indent2
  end

  # 構文木の先頭ノード
  #
  # 全体に関するオプションも保持する
  class RootNode < Node
    attr_reader :options

    def initialize(opts)
      super(:ROOT)
      @options = opts
    end

    def add(nodes)
      @children += nodes
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

  # セクション保持用
  #
  # _children[0]_ には、必ず Headline Nodeが入る
  #
  # _kind_ が、:COMMENT_SECTION の場合には出力されない。
  class SectionNode < Node

    # コンストラクタ
    # [_headline_] セクション開始の Headline
    # [_bodyitems_] セクションに含まれるブロック要素
    # [_is_comment_] コメントセクションなら true をセットする
    def initialize(headline, bodyitems)
      # kind = headline.is_comment ? :COMMENT_SECTION : :SECTION
      super(:SECTION, bodyitems, headline)
    end

    # Headline のノードを返す
    def headline
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
    attr_reader :indent, :block_name
    def initialize(vals, children)
      @block_name = vals[0].upcase
      @indent = vals[2]
      super(:BLOCK, children, vals[1])
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
    
    def initialize(uri, children = [])
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
