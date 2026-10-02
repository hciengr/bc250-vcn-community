require 'fileutils'
root=__dir__
dest=File.join(root,'_site')
FileUtils.rm_rf(dest)
FileUtils.mkdir_p(dest)
%w[index.html map.html assets evidence submissions upstream].each do |name|
 source=File.join(root,name)
 if name=='upstream'
  FileUtils.mkdir_p(File.join(dest,name))
  %w[LICENSE state.json snapshots].each{|p|FileUtils.cp_r(File.join(source,p),File.join(dest,name)) if File.exist?(File.join(source,p))}
 else
  FileUtils.cp_r(source,dest)
 end
end
%w[README.md CONTRIBUTING.md AGENTS.md VERIFICATION.md PUBLISHING.md review-policy.json data.json agent-tasks.json evidence-manifest.json].each{|p|FileUtils.cp(File.join(root,p),dest)}
File.write(File.join(dest,'.nojekyll'),'')
puts "Prepared static public directory: #{dest}"
