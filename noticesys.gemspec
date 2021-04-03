Gem::Specification.new do |s|
  s.name = 'noticesys'
  s.version = '0.1.1'
  s.summary = 'A small part of an experimental microblogging system.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/noticesys.rb']
  s.add_runtime_dependency('down', '~> 5.2', '>=5.2.0')
  s.add_runtime_dependency('ogextractor', '~> 0.1', '>=0.1.3')
  s.signing_key = '../privatekeys/noticesys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/noticesys'
end
