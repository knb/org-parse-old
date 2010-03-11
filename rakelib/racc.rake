namespace "racc" do
  srcs = FileList["lib/**/*.ry"]
  tabs = srcs.ext("tab.rb")

  desc "Generate tab files"
  file :gen => tabs do |t|
    #
  end

  tabs.each do |t|
    s = t.sub('.tab.rb', '.ry')
    file t => s do
      sh "racc -v #{s}"
    end
  end
end
