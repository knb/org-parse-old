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
    def initialize(src, opts)
      @scanner = StructScanner.new(src, opts)
      @variables = []
      @yydebug = true
      set_struct_parser self
    end

    # 構文解析を実行し、構文木を返す
    def parse
      @scanner.scan
      root = do_parse
      update_nodes root
      root
    end

    def update_nodes(node, opt = {})
      cnt = 1;

      section_no = node.section_no if node.kind == :SECTION
      node.children.each do |n|
        if n.is_a? Array
          n.each {|a|
            a.parent = node
            update_nodes a, opt
          }
          next
        end
        n.parent = node
        if n.kind == :SECTION
          if node.kind == :ROOT
            n.section_no = cnt.to_s
          else
            n.section_no = section_no + "." + cnt.to_s
          end
          cnt += 1
        end
        update_nodes n, opt
      end
    end

    def next_token
      (token, variables) = @scanner.next_token
      @variables = variables unless variables.empty?
      token
    end

    def variables
      ret = @variables.dup
      @variables.clear
      ret
    end

  end
end
