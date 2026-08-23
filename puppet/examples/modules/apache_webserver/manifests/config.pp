# @summary Manages Apache configuration files and index document
class apache_webserver::config {
  $conf_dir = $facts['os']['family'] ? {
    'RedHat' => '/etc/httpd/conf.d',
    'Debian' => '/etc/apache2/sites-available',
    default  => '/etc/httpd/conf.d',
  }

  # Document Root Directory
  file { $apache_webserver::doc_root:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Virtual Host Configuration from EPP Template
  file { "${conf_dir}/custom_vhost.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('apache_webserver/vhost.conf.epp', {
      'port'         => $apache_webserver::http_port,
      'doc_root'     => $apache_webserver::doc_root,
      'server_admin' => $apache_webserver::server_admin,
      'server_name'  => $facts['networking']['fqdn'],
    }),
  }

  # Static Landing Page from Module Files directory
  file { "${apache_webserver::doc_root}/index.html":
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/apache_webserver/index.html',
  }
}
