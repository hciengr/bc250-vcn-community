# Fetches ledger data only. Never executes remote scripts or model output.
require 'json'
require 'digest'
require 'open3'
require 'fileutils'
require 'time'
task_id,worker_id,principal,dest=ARGV
abort 'Usage: ruby sync_worker.rb Txx worker-id github-human-login OUTPUT_DIRECTORY' unless [task_id,worker_id,principal,dest].all?{|x|x && !x.empty?}
abort 'Invalid task / worker identity' unless task_id.match?(/\AT\d+\z/) && worker_id.match?(/\A[\w.-]+\z/) && principal.match?(/\A[\w-]+\z/)
abort 'Output directory already exists; preserve old worker snapshots.' if File.exist?(dest)
def git(*args, raw: false)
 out,status=Open3.capture2('git',*args)
 abort "Git failed: #{args.first}" unless status.success?
 raw ? out : out.strip
end
dest=File.expand_path(dest)
Dir.chdir(__dir__)
remote=git('config','--get','remote.origin.url')
abort 'Configure origin as a GitHub HTTPS repository URL.' unless remote.match?(%r{\Ahttps://github\.com/[\w.-]+/[\w.-]+(?:\.git)?\z})
git('fetch','--no-tags','origin','main')
revision=git('rev-parse','refs/remotes/origin/main')
raw=git('show',"#{revision}:data.json",raw:true)
data=JSON.parse(raw)
packet_data=JSON.parse(git('show',"#{revision}:agent-tasks.json"))
packet=packet_data['tasks'].find{|p|p.dig('task','id')==task_id}
abort 'Unknown task in shared snapshot.' unless packet
abort 'Ledger packet hash mismatch.' unless packet['ledger_sha256']==Digest::SHA256.hexdigest(raw)
packet['worker']={id:worker_id,human_principal:principal,source_commit:revision,synced_at:Time.now.utc.iso8601}
files={ 'task.json'=>JSON.pretty_generate(packet)+"\n" }
%w[AGENTS.md CONTRIBUTING.md VERIFICATION.md].each{|path|files[path]=git('show',"#{revision}:#{path}",raw:true)}
packet.fetch('sources').each do |path,expected|
 abort 'Unsafe source path' unless path.start_with?('evidence/') && !path.split('/').include?('..')
 contents=git('show',"#{revision}:#{path}",raw:true)
 abort "Missing or changed evidence #{path}" unless Digest::SHA256.hexdigest(contents)==expected
 files[path]=contents
end
FileUtils.mkdir_p(dest)
files.each{|path,contents|target=File.join(dest,path);FileUtils.mkdir_p(File.dirname(target));File.binwrite(target,contents)}
