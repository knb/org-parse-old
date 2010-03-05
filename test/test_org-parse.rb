require 'helper'
require 'nokogiri'

class TestOrgParse < Test::Unit::TestCase
  
  context "titles" do

    should "inline parsed" do
      src = "title *bold*\nmay be <b>tag\n"
      ret = to_html(src, 'yyy')
      doc = Nokogiri(ret)
      assert_equal 'title <b>bold</b>', doc.search('h1').inner_html
    end

    context "no texts before 1st headline" do
      setup do
        @src = "* title\n"
               "there is no lines before 1st headline\n"
      end

      should "title is filename(default)" do
        src = @src
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">yyy</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> title ', doc.search('h2').inner_html
      end

      should "default title become title with opt skip" do
        src = @src + "#+OPTIONS: skip:t\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">yyy</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> title ', doc.search('h2').inner_html
      end

      should "TITLE set with opt title" do
        src = @src + "#+TITLE: xxxx\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">xxxx</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> title ', doc.search('h2').inner_html
      end

      should "TITLE set with opt title and skip" do
        src = @src + "#+TITLE: xxxx\n" + "#+OPTIONS: skip:t\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">xxxx</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> title ', doc.search('h2').inner_html
      end

    end

    context "text before 1st headline" do
      setup do
        @src = "- list\n- item1\n* 1st head\n"
      end

      should "1st text become title" do
        src = @src
        str = to_html(src, 'yyy')
        doc = Nokogiri(str)
        assert_equal '<h1 class="title">- list</h1>', doc.search('h1').to_s
        assert_equal '<li>item1</li>', doc.search('li').to_s
      end

      should "default title become title with opt skip" do
        src = @src + "#+OPTIONS: skip:t\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">yyy</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> 1st head ', doc.search('h2').inner_html
        assert doc.search('li').empty?
      end

      should "TITLE set with opt title" do
        src = @src + "#+TITLE: xxxx\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">xxxx</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> 1st head ', doc.search('h2').inner_html
      end

      should "TITLE set with opt title and skip" do
        src = @src + "#+TITLE: xxxx\n" + "#+OPTIONS: skip:t\n"
        ret = to_html(src, 'yyy')
        doc = Nokogiri(ret)
        assert_equal '<h1 class="title">xxxx</h1>', doc.search('h1').to_s
        assert_equal '<span class="section-number-2">1</span> 1st head ', doc.search('h2').inner_html
      end
    end
  end

  context "sections" do
    setup do
      src = load_data('sections.org')
      ret = to_html(src, 'sections')
      @doc = Nokogiri(ret)
    end
      
    should "has numbere label" do
      assert_equal 'sections', @doc.search('h1').inner_html
      labels = @doc.search('span')
      assert_equal '<span class="section-number-2">1</span>', labels[0].to_s
      assert_equal '1.1', labels[1].inner_text
      assert_equal '1.1.1', labels[2].inner_text
      assert_equal '1.1.2', labels[3].inner_text
      assert_equal '1.2', labels[4].inner_text
      assert_equal '2', labels[5].inner_text
      assert_equal '2.1', labels[6].inner_text
      assert       labels[7].nil?
      s1_1 = @doc.search("//div[@id='outline-container-1.1']")
      assert_equal '1.1', s1_1.search('span')[0].inner_text
      assert_equal 'sec-1.1', s1_1.children[1]['id']
      s1_1_2 = s1_1.search("//div[@id='outline-container-1.1.2']")
      assert_equal 'sec-1.1.2', s1_1_2.children[1]['id']
    end

    should "be <ul> outline-4" do
      parent = @doc.search("//div[@id='text-2.1']")
      ul = parent.children[1]
      assert_equal 'ul', ul.name
      assert_equal 'li', ul.children[0].name
      assert_equal 'sec-2.1.2', ul.children[2]['id']
    end
  end
end
