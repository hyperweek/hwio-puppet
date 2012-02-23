# Credits: http://nuknad.com/2011/02/11/self-classifying-puppet-nodes/
# To deploy, use http://docs.puppetlabs.com/guides/custom_facts.html#Loading Custom Facts
# eg. export FACTERLIB="/usr/share/local/hwio-server/modules/custom/plugins"
require 'facter'

if File.exist?("/etc/node.facts")
  File.readlines("/etc/node.facts").each do |line|
    if line =~ /^(.+)=(.+)$/
      var = $1.strip;
      val = $2.strip

      Facter.add(var) do
        setcode { val }
      end
    end
  end
end
