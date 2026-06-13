#!/usr/bin/env ruby
# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'json'
require 'base64'
require 'pathname'

package_root = Pathname.new(__dir__)
package_name = 'WhatsappOutboundTemplates'
version = '1.0.14'
output = package_root.join("#{package_name}-#{version}.zpm")

ignore = %w[
  .git
  .gitignore
  build.rb
  README.md
  spec
  WhatsappOutboundTemplates.szpm
]

files = []
package_root.find do |path|
  next if path.directory?

  relative = path.relative_path_from(package_root).to_s
  next if ignore.any? { |entry| relative == entry || relative.start_with?("#{entry}/") }
  next if relative.end_with?('.zpm')

  files << {
    'permission' => '644',
    'location'   => relative,
    'content'    => Base64.strict_encode64(path.read),
  }
end

package = {
  'name'        => package_name,
  'version'     => version,
  'vendor'      => 'Zammad Community',
  'license'     => 'MIT',
  'url'         => 'https://github.com/zammad/zammad',
  'description' => [
    {
      'language' => 'en',
      'text'     => 'Adds outbound WhatsApp Business API template messaging to Zammad.',
    },
    {
      'language' => 'es',
      'text'     => 'Agrega mensajería saliente con plantillas de WhatsApp Business API a Zammad.',
    },
  ],
  'files'       => files.sort_by { |file| file['location'] },
}

output.write(JSON.pretty_generate(package))
puts "Built #{output}"
