# ==============================================================================
# Master Node Classification Manifest (site.pp)
# ==============================================================================

# Global Resource Defaults (Enforce safe default file ownership and PATH)
File {
  owner => 'root',
  group => 'root',
  mode  => '0644',
}

Exec {
  path => ['/usr/bin', '/usr/sbin', '/bin', '/sbin'],
}

# ==============================================================================
# Node Classification Definitions
# ==============================================================================

# 1. Primary Production Web Server
node 'web01.production.company.com' {
  class { 'apache_webserver':
    http_port    => 80,
    server_admin => 'cloudops@company.com',
  }
}

# 2. Dynamic Staging Fleet via Regex Matching
node /^web\d+\.staging\.company\.com$/ {
  class { 'apache_webserver':
    http_port    => 8080,
    server_admin => 'staging-ops@company.com',
  }
}

# 3. Default Fallback Node Definition
node default {
  notify { 'node_bootstrap_notice':
    message => "Bootstrapping node ${facts['networking']['fqdn']} with default profile.",
  }
}
