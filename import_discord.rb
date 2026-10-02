# Reads an authorized DiscordChatExporter-style JSON export; no network or credentials.
require 'json'
require 'digest'
input=ARGV[0] or abort 'Usage: ruby import_discord.rb /path/to/channel-export.json'
d=JSON.parse(File.read(File.join(__dir__,'data.json')))
export=JSON.parse(File.read(input))
channel=export.dig('channel','id').to_s
guild=(export.dig('guild','id')||'1315924807128449065').to_s
abort 'Export must identify channel 1537956545881444382' unless channel=='1537956545881444382'
messages=export['messages'];abort 'Expected messages array' unless messages.is_a?(Array)
existing=d['contributions'].map{|r|r['id']};added=0
messages.each do |m|
 id=m['id'].to_s;abort 'Invalid message ID' unless id.match?(/\A\d+\z/)
 record_id="discord-#{id}";next if existing.include?(record_id)
 links=(m['attachments']||[]).map{|a|{'filename'=>a['fileName']||a['filename'],'url'=>a['url']}}.select{|a|a['url'].to_s.match?(/\Ahttps:\/\//)}
 d['contributions'] << {id:record_id,type:'discord-message',status:'pending',source:nil,claims:[],message_url:"https://discord.com/channels/#{guild}/#{channel}/#{id}",author:m.dig('author','name')||m.dig('author','nickname')||'unknown',author_id:m.dig('author','id'),timestamp:m['timestamp'],edited_timestamp:m['timestampEdited'],content:m['content'].to_s,attachments:links,reply_to:m.dig('reference','messageId'),export_sha256:Digest::SHA256.file(input).hexdigest,summary:m['content'].to_s[0,180]}
 existing << record_id;added+=1
end
File.write(File.join(__dir__,'data.json'),JSON.pretty_generate(d)+"\n")
puts "Imported #{added} messages; duplicates skipped. All remain pending. Attachment URLs retained; binaries not downloaded."
load File.join(__dir__,'build.rb')
