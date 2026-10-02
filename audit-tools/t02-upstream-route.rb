#!/usr/bin/env ruby
# Inspect pinned Git objects; never build or execute upstream code.
require 'json'
require 'digest'
require 'open3'
abort 'Usage: ruby t02-upstream-route.rb UPSTREAM_GIT_REPOSITORY' unless ARGV.size == 1
repo = File.expand_path(ARGV[0])
commit = '4a91ceb86275fbceeaf1fb3062f2f086e7f780c5'
paths = %w[research/SESSION_SUMMARY_2026_09_30.md research/CORRECTIONS_2026_09_30.md code/direct-load/PATCHES.md code/direct-load/amdgpu_vcn.c code/direct-load/vcn_v2_0.c code/direct-load/amdgpu_drv.c]
objects = paths.map do |path|
  text, err, status = Open3.capture3('git', '-C', repo, 'show', "#{commit}:#{path}")
  abort "Missing pinned input #{path}: #{err}" unless status.success?
  {path:path,sha256:Digest::SHA256.hexdigest(text),bytes:text.bytesize,text:text}
end
source = objects.find{|o|o[:path].end_with?('/amdgpu_vcn.c')}[:text]
start = source.index('void amdgpu_vcn_setup_ucode(') or abort 'Missing setup function'
finish = source.index("\n}",start) or abort 'Missing function terminator'
setup = source[start..finish+1]
return_offset = setup.index("\n\treturn;") or abort 'Missing unconditional return'
registration = setup.index('if (adev->firmware.load_type == AMDGPU_FW_LOAD_PSP)') or abort 'Missing PSP registration block'
abort 'Unexpected source layout' unless return_offset < registration
prefix = setup[0...return_offset]
abort 'Unexpected guard before return; inspect manually' if prefix.match?(/\bif\s*\(/)
vcn = objects.find{|o|o[:path].end_with?('/vcn_v2_0.c')}[:text]
uses = vcn.lines.each_with_index.filter_map{|line,i|{line:i+1,text:line.strip} if line.include?('amdgpu_vcn_direct')}
abort 'Unexpected numeric mode guard; inspect manually' if vcn.match?(/amdgpu_vcn_direct\s*(?:==|>=|<=|>|<)\s*[235678]/)
summary = objects.find{|o|o[:path].end_with?('/SESSION_SUMMARY_2026_09_30.md')}[:text]
correction = objects.find{|o|o[:path].end_with?('/CORRECTIONS_2026_09_30.md')}[:text]
abort 'Changed reported payload size' unless summary.include?('bytes=405696') && correction.include?('405,952')
puts JSON.pretty_generate({upstream:'Shalasere/bc250-vcn-research',commit:commit,kind:'static source inspection and attributed report comparison',inputs:objects.map{|o|o.reject{|k,_|k==:text}},setup_function:setup,direct_mode_uses:uses,observations:{registration_return_precedes_psp_block_without_if_guard:true,numeric_mode_skip_guards_found:false,reported_firmware_file_bytes:405952,reported_payload_bytes:405696,reported_payload_offset:256},limitations:'No compilation, board access or identification of the module actually used by the author. Published source gaps are not contradictions of raw board observations.'})
