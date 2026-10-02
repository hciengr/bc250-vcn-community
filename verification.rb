require 'json'
require 'digest'
module Verification
  def self.check(data, root)
    errors=[]
    legacy=JSON.parse(File.read(File.join(root,'legacy-claims.json')))
    records=data.fetch('verifications',[])
    errors << 'Duplicate verification IDs' unless records.map{|v|v['id']}.uniq.size==records.size
    required=%w[id author_principal reviewer_principal kind scope method expected actual controls limitations environment artifacts independent_reproduction review_url]
    records.each do |v|
      required.each{|k|errors << "#{v['id']}: missing #{k}" if v[k].nil? || v[k].respond_to?(:empty?) && v[k].empty?}
      errors << "#{v['id']}: self review" if v['author_principal'].to_s.downcase==v['reviewer_principal'].to_s.downcase
      %w[author_principal reviewer_principal].each{|k|errors << "#{v['id']}: invalid human principal" unless v[k].to_s.match?(/\A[A-Za-z0-9-]+\z/)}
      errors << "#{v['id']}: artifacts must be arrays" unless v['artifacts'].is_a?(Array) && v.dig('independent_reproduction','artifacts').is_a?(Array)
      errors << "#{v['id']}: invalid evidence kind" unless %w[static model offline-crypto hardware].include?(v['kind'])
      errors << "#{v['id']}: invalid review URL" unless v['review_url'].to_s.match?(%r{\Ahttps://github\.com/[\w.-]+/[\w.-]+/pull/\d+#pullrequestreview-\d+\z})
      reproduction=v['independent_reproduction'] || {}
      %w[principal method actual artifacts].each{|k|errors << "#{v['id']}: missing reproduction #{k}" if reproduction[k].nil? || reproduction[k].respond_to?(:empty?) && reproduction[k].empty?}
      errors << "#{v['id']}: reproduction identity mismatch" unless reproduction['principal']==v['reviewer_principal']
      artifacts=Array(v['artifacts'])+Array(reproduction['artifacts'])
      artifacts.each do |a|
        unless a.is_a?(Hash) && a['path'].to_s.start_with?('evidence/') && !a['path'].split('/').include?('..') && a['sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
          errors << "#{v['id']}: unsafe/unhashed artifact"; next
        end
        path=File.join(root,a['path'])
        errors << "#{v['id']}: artifact missing or changed #{a['path']}" unless File.file?(path) && File.realpath(path).start_with?(File.realpath(File.join(root,'evidence'))+'/') && Digest::SHA256.file(path).hexdigest==a['sha256']
      end
      if v['kind']=='hardware'
        %w[board boot_id bios_sha256 kernel firmware_sha256 timestamps address_space].each{|k|errors << "#{v['id']}: hardware provenance missing #{k}" if v.fetch('environment',{})[k].to_s.empty?}
      end
    end
    data['claims'].each do |c|
      if c['review']=='seeded'
        errors << "#{c['id']}: seeded claim changed or forged" unless legacy[c['id']]==Digest::SHA256.hexdigest(JSON.generate(c))
      end
      if c['state']=='proven' && c['review']!='seeded' || c['review']=='accepted'
        v=records.find{|r|r['id']==c['verification_id']}
        errors << "#{c['id']}: proof needs independent verification" unless c['review']=='accepted' && v && Array(v['supports']).include?(c['id']) && v['kind']==c['kind'] && v['scope']==c['scope'] && Array(c['reviewers']).include?(v['reviewer_principal'])
      end
    end
    data['tasks'].each do |t|
      t['attempts'].select{|a|a['review']=='accepted'}.each do |a|
        v=records.find{|r|r['id']==a['verification_id']}
        errors << "#{t['id']}: accepted attempt needs independent verification" unless v && Array(v['supports']).include?(t['id']) && a['author_principal']==v['author_principal']
        errors << "#{t['id']}: completion criterion not verified" unless v && v.fetch('task_criteria',{})[t['id']]==t['done_when']
      end
    end
    data['stages'].each do |s|
      errors << "#{s['id']}: green stage contains unresolved claims" if s['state']=='proven' && s['claims'].any?{|id|data['claims'].find{|c|c['id']==id}&.fetch('state')!='proven'}
    end
    errors
  end
end
