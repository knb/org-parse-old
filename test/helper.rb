require 'rubygems'
require 'test/unit'
require 'shoulda'
require 'nokogiri'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'org-parse'

class Test::Unit::TestCase
  @@data_dir = File.join(File.dirname(__FILE__), 'data')
  
  def load_data(fname)
    f = File.open(File.join(@@data_dir,fname))
    str = f.read
    f.close
    str
  end

  def do_parse(str, title)
    @parser = OrgParse::StructParser.new(str, title)
    @parser.parse
  end

  def to_html(str, title)
    @root = do_parse str, title
    @visitor = OrgParse::HtmlVisitor.new(@root)
    @visitor.build
  end

end
