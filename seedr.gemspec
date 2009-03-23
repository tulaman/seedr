# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{seedr}
  s.version = "0.1.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Ilya Lityuga"]
  s.date = %q{2009-03-23}
  s.default_executable = %q{seedr}
  s.description = %q{a command line interface and api for seeding viral video}
  s.email = %q{ilya.lityuga@gmail.com}
  s.executables = ["seedr"]
  s.extra_rdoc_files = ["CHANGELOG", "bin/seedr", "lib/multipart_post_request.rb", "lib/seedr/cli.rb", "lib/seedr/ext.rb", "lib/seedr/video.rb", "lib/seedr/bot.rb", "lib/seedr/version.rb", "lib/seedr/sites/rutube_ru.rb", "lib/seedr/sites/youtube_com.rb", "lib/seedr/sites/yandex_ru.rb", "lib/seedr/sites/smotri_com.rb", "lib/seedr.rb", "README.rdoc"]
  s.files = ["CHANGELOG", "Rakefile", "bin/seedr", "Manifest", "seedr.gemspec", "lib/multipart_post_request.rb", "lib/seedr/cli.rb", "lib/seedr/ext.rb", "lib/seedr/video.rb", "lib/seedr/bot.rb", "lib/seedr/version.rb", "lib/seedr/sites/rutube_ru.rb", "lib/seedr/sites/youtube_com.rb", "lib/seedr/sites/yandex_ru.rb", "lib/seedr/sites/smotri_com.rb", "lib/seedr.rb", "test/seedr_test.rb", "License", "README.rdoc"]
  s.has_rdoc = true
  s.homepage = %q{}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Seedr", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{seedr}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{a command line interface and api for seeding viral video}
  s.test_files = ["test/seedr_test.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, ["> 0.1"])
    else
      s.add_dependency(%q<nokogiri>, ["> 0.1"])
    end
  else
    s.add_dependency(%q<nokogiri>, ["> 0.1"])
  end
end
