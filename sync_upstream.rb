require 'json'
require 'digest'
require 'open3'
require 'time'
ROOT = __dir__
URL = 'https://github.com/Shalasere/bc250-vcn-research.git'
def git(*args)
 out, err, status = Open3.capture3('git', '--git-dir='+ROOT+'/upstream/cache.git', *args)
 abort(err) unless status.success?
 out
end
Dir.mkdir(ROOT+'/upstream') unless Dir.exist?(ROOT+'/upstream')
File.open(ROOT+'/upstream/sync.lock','w') do |lock|
 abort('Another refresh is running') unless lock.flock(File::LOCK_EX|File::LOCK_NB)
 unless Dir.exist?(ROOT+'/upstream/cache.git')
  _,err,s=Open3.capture3('git','clone','--bare','--depth','1',URL,ROOT+'/upstream/cache.git');abort(err) unless s.success?
 end
 git('fetch','--depth','1','--no-tags',URL,'HEAD') unless ARGV.include?('--offline')
 cached_ref=File.exist?(ROOT+'/upstream/cache.git/FETCH_HEAD') ? 'FETCH_HEAD' : 'HEAD'
 commit=git('rev-parse',ARGV.include?('--offline') ? cached_ref : 'FETCH_HEAD').strip
 files=git('ls-tree','-r','-z',commit).split("\0").map{|row|meta,path=row.split("\t",2);mode,type,oid=meta.split;{path:path,object:oid,mode:mode,type:type}}
 inventory=files.to_h{|f|[f[:path],f[:object]]}
 state_path=ROOT+'/upstream/state.json'
 old=File.exist?(state_path) ? JSON.parse(File.read(state_path)) : {}
 if old['commit'] != commit
  previous=old.fetch('inventory',{})
  changed=(inventory.keys|previous.keys).sort.filter_map{|path|next if inventory[path]==previous[path];{path:path,change:!previous.key?(path) ? 'added' : !inventory.key?(path) ? 'removed' : 'modified',before:previous[path],after:inventory[path]}}
  report={commit:commit,previous_commit:old['commit'],detected_at:Time.now.utc.iso8601,status:'pending',changes:changed}
  File.write(ROOT+'/upstream/'+commit+'.json',JSON.pretty_generate(report)+"\n")
 end
 # Never execute upstream code or promote claims automatically. Read only regular Markdown blobs.
 snapshots=ROOT+'/upstream/snapshots/'+commit
 require 'fileutils'
 files.select{|f|f[:type]=='blob'&&f[:mode]=='100644'&&(f[:path]=='README.md'||f[:path].start_with?('research/'))&&f[:path].end_with?('.md')}.each do |f|
  path=snapshots+'/'+f[:path];FileUtils.mkdir_p(File.dirname(path));File.binwrite(path,git('show',commit+':'+f[:path]))
 end
 binary=files.find{|f|f[:path]=='firmware/vangogh_smu_full.bin'}
 bytes=binary ? git('show',commit+':'+binary[:path]).b : nil
 pending=Dir.glob(ROOT+'/upstream/*.json').reject{|p|p.end_with?('/state.json')}.map{|p|JSON.parse(File.read(p))}.count{|r|r['status']=='pending'}
 state={repository:URL.delete_suffix('.git'),commit:commit,checked_at:Time.now.utc.iso8601,commit_date:git('show','-s','--format=%cI',commit).strip,inventory:inventory,pending_revisions:pending,firmware:bytes ? {path:binary[:path],bytes:bytes.bytesize,sha256:Digest::SHA256.hexdigest(bytes)} : nil}
 File.write(state_path,JSON.pretty_generate(state)+"\n")
 public_state=state.reject{|k,v|k==:inventory}
 File.write(ROOT+'/assets/upstream.js','window.VCN_UPSTREAM = '+JSON.generate(public_state).gsub('<','\\u003c')+";\n")
 puts "Checked #{commit}; #{pending} revision(s) awaiting review. Evidence states unchanged."
end
