require 'fastlane'

api_key_path = File.expand_path("fastlane/AuthKey.p8", __dir__)
key_id = "TEZL10HKRY98"
issuer_id = "9dd4bee4-0107-4c6c-b8e3-191244666173"

puts "API Key Path: #{api_key_path}"
puts "File exists: #{File.exist?(api_key_path)}"
puts "Key ID: #{key_id}"
puts "Issuer ID: #{issuer_id}"

if File.exist?(api_key_path)
  begin
    require 'jwt'
    require 'openssl'
    
    key = OpenSSL::PKey::EC.new(File.read(api_key_path))
    puts "✅ API 키 파일 읽기 성공"
    puts "키 타입: #{key.class}"
  rescue => e
    puts "❌ API 키 파일 읽기 실패: #{e.message}"
  end
end
