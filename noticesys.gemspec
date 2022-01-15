Gem::Specification.new do |s|
  s.name = 'noticesys'
  s.version = '0.5.1'
  s.summary = 'A small part of an experimental microblogging system.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/noticesys.rb', 'data/microblog.txt','data/css.txt']
  s.add_runtime_dependency('down', '~> 5.2', '>=5.2.4')
  s.add_runtime_dependency('weblet', '~> 0.3', '>=0.3.5')
  s.add_runtime_dependency('dynarex', '~> 1.8', '>=1.8.27')
  s.add_runtime_dependency('unichron', '~> 0.4', '>=0.4.0')
  s.add_runtime_dependency('ogextractor', '~> 0.1', '>=0.1.4')
  s.add_runtime_dependency('recordx_sqlite', '~> 0.3', '>=0.3.3')
  s.signing_key = '../privatekeys/noticesys.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/noticesys'
end
