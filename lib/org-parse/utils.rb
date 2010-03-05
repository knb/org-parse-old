# -*- coding: utf-8 -*-

module OrgParse

  module Utils
    # とりあえず
    def get_indent(str)
      return 0 if str.empty?
      str =~ /^(\s*)/
      $1.gsub(/([^\t]{8})|([^\t]*)\t/n){ [$+].pack("A8") }.size
    end
  end

end
    
