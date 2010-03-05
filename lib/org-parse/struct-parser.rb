# -*- coding: utf-8 -*-
require 'racc/parser'
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'struct-parser.tab.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'utils.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'inline-parser.rb')

module OrgParse

  # パーサー
  # 
  # 構造レベルの構文解析を行う。
  # 各行の中身については、InlineParserを、内部的に呼び出して解析している。
  #
  # ROOT--+-- ブロック要素
  #       |      +--- ブロック要素
  #       +-- ブロック要素
  #    の様な形式の構文木を作成する。
  # Node クラスを参照
  #
  class StructParser < Racc::Parser
    include Utils
    include InlineUtils

    # コンストラクタ
    def initialize(src, title = '(non title)')
      @scanner = StructScanner.new(src, title)
      @yydebug = true
    end

    # 構文解析を実行し、構文木を返す
    def parse
      @scanner.scan
      do_parse
    end

    def next_token
      @scanner.next_token
    end

    # def line_parse(str)
    #  @inline_parser.parse(str)
    # end

    # def line_index
    #   @scanner.line_index
    # end

    # def on_error(et, ev, values)
    #  message = " #{et} #{ev ? ev : ''} #{values}\n"
    #  raise ParseError, message
    # end
  end
end
