# -*- coding: utf-8 -*-
require 'racc/parser'
require 'forwardable'
require 'strscan'
require 'uri'
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'inline-parser.tab.rb')
require ::File.join(OrgParse::LIBPATH , 'org-parse', 'node.rb')

module OrgParse

  # 行単位の要素を解析する
  class InlineParser < Racc::Parser
    attr_reader :token_que
    attr_accessor :structp

    def initialize(bp = nil)
      @structp = bp
      @token_que = []
      @footnote_idx = 0
      @footnotes = {}

      # Set up the emphasis regular expression.
      @pre_emphasis = " \t\\('\""
      @post_emphasis = "- \t.,:!?;'\"\\)"
      @border_forbidden = " \t\r\n,\"'"
      @body_regexp = ".*?"
      @markers = "*/_=~+"
      @org_quote_regexp = /@<[^>]+>/
      @org_br_regexp = /\\\\$/
      @org_footnote_regexp = /\[fn:(.+)\]/

      build_org_emphasis_regexp
      build_org_link_regexp
    end

    def parse(src)
      return [] if src.empty?
      @src = src
      @token_que = []
      @yydebug = true
      scan(src)
      do_parse
    end

    # 文字列をトークンに分解し、@token_que にセットする
    # 
    def scan(str, verb = false)
      symbols = { 
        '*' => [:EM_OPEN, :EM_CLOSE], 
        '/' => [:IT_OPEN, :IT_CLOSE],
        '=' => [:CODE_OPEN, :CODE_CLOSE], 
        '~' => [:VERB_OPEN, :VERB_CLOSE], 
        '+' => [:ST_OPEN, :ST_CLOSE], 
        '_' => [:UL_OPEN, :UL_CLOSE], 
      }
      while !str.empty?
        # puts "str:\"#{str}\""
        matches = []
        matches << [:em, Regexp.last_match] if @org_emphasis_regexp =~ str
        matches << [:lt, Regexp.last_match] if @org_link_text_regexp =~ str
        matches << [:ln, Regexp.last_match] if @org_link_regexp =~ str
        matches << [:quote, Regexp.last_match] if @org_quote_regexp =~ str
        matches << [:br, Regexp.last_match] if @org_br_regexp =~ str
        matches << [:fn, Regexp.last_match] if @org_footnote_regexp =~ str

        if matches.empty?
          @token_que << [:OTHER, str]
          str = ''
        else
          # p matches
          m = matches[0]
          matches.each {|i| m = i if m[1].pre_match.size > i[1].pre_match.size }
          # puts '--------------------'
          # p m[1]
          # puts '--------------------'
          lm = m[1]
          case m[0]
          when :em
            if verb
              pre = lm.pre_match + lm[1] + lm[2]
              @token_que << [:OTHER, pre]
              # puts "#{str};#{pre};#{pre.size}"
              str = str[pre.size..-1]
            else
              str = lm[4]+lm.post_match
              symbol = symbols[lm[2]]
              pre = lm.pre_match + lm[1]
              @token_que << [:OTHER, pre] unless pre.empty?
              @token_que << [symbol[0], symbol[0]]
              v = ['=', '~'].include?(lm[2])
              scan(lm[3], v)
              @token_que << [symbol[1], symbol[1]]
            end
          when :lt
            str = lm.post_match
            pre = lm.pre_match
            @token_que << [:OTHER, pre] unless pre.empty?
            @token_que << [:LINK_START, lm[1]]
            scan lm[2], verb
            @token_que << [:LINK_END, :LINK_END]
          when :ln
            str = lm.post_match
            pre = lm.pre_match
            @token_que << [:OTHER, pre] unless pre.empty?
            @token_que << [:LINK_URI, lm[1]]
          when :quote
            str = lm.post_match
            pre = lm.pre_match
            @token_que << [:OTHER, pre] unless pre.empty?
            @token_que << [:QUOTE, lm[0].sub(/^@/,'')]
          when :br
            str = "\n"
            pre = lm.pre_match
            @token_que << [:OTHER, pre] unless pre.empty?
            @token_que << [:QUOTE, "\n"]
          when :fn
            match, nstr = balanced?(lm[1]+']'+lm.post_match, ['[', ']'])
            pre = lm.pre_match
            if match.empty?
              @token_que << [:OTHER, pre + "[fn:"]
              str = lm[1]+']'+lm.post_match
            else
              str = nstr
              @token_que << [:OTHER, pre] unless pre.empty?
              footnote match
            end
          end
        end
        # p str
        # return if str.nil?
      end
    end

    def next_token
      return [false, false] if @token_que.empty?
      # p @token_que[0]
      @token_que.shift
    end

    def on_error(et, ev, values)
      message = " #{et} #{ev ? ev : ''} #{values}\n"
      raise ParseError, message
    end

    private

    def balanced?(str, pair)
      idx = 0;
      cnt = 1;
      str.each_byte{|c|
        cnt += 1 if c == pair[0][0]
        cnt -= 1 if c == pair[1][0]
        break if cnt == 0
        idx += 1
      }
      return ['', str] if cnt != 0
      rest = str[idx+1, str.size]
      rest = '' unless rest
      [str[0, idx], rest] 
    end

    # [n] -- not impliment
    #   org-source               str
    # a  [fn:name]                name
    # b  [fn:: definition]        : definition
    # c  [fn:name: definition]    name: definition
    def footnote(str)
      case str
      when /^:\s*(.+)$/      # b
        @token_que << [:FN_LINK,  @footnote_idx]
        @token_que << [:FN_START, @footnote_idx]
        @footnote_idx += 1
        scan $1
        @token_que << [:FN_END, '']
      when /^([^:]+):\s*(.+)$/  # c
        @token_que << [:FN_LINK, $1]
        @token_que << [:FN_START, $1]
        scan $2
        @token_que << [:FN_END, '']
      else                   # a
        @token_que << [:FN_LINK, str]
      end
    end

    def build_org_emphasis_regexp
      @org_emphasis_regexp = Regexp.new("([#{@pre_emphasis}]|^)\n" +
                                        "(  [#{@markers}]  )\n" + 
                                        "(  [^#{@border_forbidden}]  | " +
                                        "  [^#{@border_forbidden}]#{@body_regexp}[^#{@border_forbidden}]  )\n" +
                                        "\\2\n" +
                                        "([#{@post_emphasis}]|$)\n", Regexp::EXTENDED)
      # @logger.debug "Just created regexp: #{@org_emphasis_regexp}"
    end

    def build_org_link_regexp
      @org_link_regexp = /\[\[([^\]]*)\]\]/          # $1 is the URL
      
      @org_img_regexp = /\[\[
          ([^\]]*\.(jpg|jpeg|gif|png)) # Like a normal URL, but must end with a specified extension
        \]\]/xi
      @org_link_text_regexp = /\[\[([^\]]*)\]\[([^\]]*)\]\]/ # $1 is the URL、$2 is the friendly text
    end
  end

  module InlineUtils
    def line_parse(str)
      @@inline_parser = InlineParser.new if @inline_parser.nil?
      @@inline_parser.parse(str)
    end
  end

end
