# Copyright (C) 2012-2016 Zammad Foundation, http://zammad-foundation.org/

require 'ldap'
require 'ldap/group'

module Import
  class Ldap < Import::IntegrationBase
    include Import::Mixin::Sequence

    private

    def sequence_name
      'Import::Ldap::Users'
    end
  end
end
