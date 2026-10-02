require 'json'
require 'digest'
require_relative 'verification'
root=__dir__
d=JSON.parse(File.read("#{root}/data.json"))
errors=[]
%w[claims stages tasks contributions].each {|k| errors << "Missing array #{k}" unless d[k].is_a?(Array)}
abort(errors.join("\n")) unless errors.empty?
all=d.values_at('claims','stages','tasks','contributions').flatten.map{|x|x['id']}
errors << 'Duplicate or missing IDs' unless all.all?{|id|id.is_a?(String)&&!id.empty?} && all.uniq.length==all.length
claim_ids=d['claims'].map{|c|c['id']}; stage_ids=d['stages'].map{|s|s['id']}; task_ids=d['tasks'].map{|t|t['id']}
d['claims'].each do |c|
 errors << "Bad state #{c['id']}" unless %w[proven partial unknown].include?(c['state'])
 errors << "Scope missing #{c['id']}" if c['scope'].to_s.empty?
 errors << "No sources #{c['id']}" if c['sources'].empty?
 c['sources'].each {|s|errors << "Missing/unsafe source #{s}" unless s.start_with?('evidence/') && !s.split('/').include?('..') && File.file?("#{root}/#{s}")}
 errors << "Unreviewed community proof #{c['id']}" if c['state']=='proven'&&c['kind']=='community-report'&&c['review']!='accepted'
end
d['stages'].each {|s|errors << "Unknown claim in #{s['id']}" unless (s['claims']-claim_ids).empty?}
d['edges'].each {|e|errors << "Invalid edge #{e}" unless e.length==2&&(e-stage_ids).empty?}
d['tasks'].each do |t|
 errors << "Unknown stage #{t['id']}" unless stage_ids.include?(t['stage'])
 errors << "Unknown dependency #{t['id']}" unless (t['depends_on']-task_ids).empty?
 errors << "Bad priority #{t['id']}" unless [1,2,3].include?(t['priority'])
 errors << "Bad status #{t['id']}" unless %w[open claimed paused review done].include?(t['status'])
 errors << "Claim missing owner/expiry #{t['id']}" if t['status']=='claimed'&&(t['owner'].to_s.empty?||t['claim_until'].to_s.empty?)
 errors << "Completion needs accepted attempt #{t['id']}" if t['status']=='done'&&!t['attempts'].any?{|a|a['review']=='accepted'}
end
visiting=[]; done=[]
visit=lambda{|id| if visiting.include?(id);errors << "Dependency cycle at #{id}";return;end;return if done.include?(id);visiting << id;d['tasks'].find{|t|t['id']==id}['depends_on'].each{|dep|visit.call(dep) if task_ids.include?(dep)};visiting.pop;done << id}
task_ids.each{|id|visit.call(id)}
abort(errors.join("\n")) unless errors.empty?
errors.concat(Verification.check(d,root))
abort(errors.join("\n")) unless errors.empty?
ledger_hash=Digest::SHA256.file("#{root}/data.json").hexdigest
packets=d['tasks'].map do |t|
 stage=d['stages'].find{|s|s['id']==t['stage']}
 claims=d['claims'].select{|c|stage['claims'].include?(c['id'])}
 {task:t,stage:stage,claims:claims,dependencies:d['tasks'].select{|x|t['depends_on'].include?(x['id'])},
 instructions:'Read AGENTS.md and VERIFICATION.md. Sync the repository and check issues before claiming. Workers submit evidence; a different human principal must reproduce and approve. Preserve snapshot SHA-256 in submissions.',
 sources:claims.flat_map{|c|c['sources']}.uniq.to_h{|p|[p,Digest::SHA256.file(File.join(root,p)).hexdigest]},
 ledger_sha256:ledger_hash,repository_url:d['repository_url'],baseline_date:d['baseline_date']}
end
File.write("#{root}/agent-tasks.json",JSON.pretty_generate({schema_version:2,ledger_sha256:ledger_hash,tasks:packets})+"\n")
File.write("#{root}/assets/data.js",'window.VCN_DATA = '+JSON.generate(d).gsub('<','\\u003c')+";\nwindow.VCN_TASK_PACKETS = "+JSON.generate(packets).gsub('<','\u003c')+";\n")
manifest=Dir.glob("#{root}/evidence/**/*").select{|p|File.file?(p)}.sort.map{|p|{path:p.delete_prefix(root+'/'),sha256:Digest::SHA256.file(p).hexdigest}}
File.write("#{root}/evidence-manifest.json",JSON.pretty_generate(manifest)+"\n")
puts "Validated #{d['claims'].size} claims, #{d['stages'].size} stages, #{d['tasks'].size} tasks, #{d['contributions'].size} reports; built offline dashboard."
