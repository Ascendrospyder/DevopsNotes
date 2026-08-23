# @summary Enterprise Apache Webserver Module Entrypoint
#
# @param package_name The name of the Apache package on this OS
# @param service_name The name of the Apache daemon service
# @param http_port The listening TCP port for HTTP traffic
# @param doc_root The document root path for website files
# @param server_admin Contact email for the web administrator
class apache_webserver (
  String  $package_name = $facts['os']['family'] ? {
    'RedHat' => 'httpd',
    'Debian' => 'apache2',
    default  => 'httpd',
  },
  String  $service_name = $facts['os']['family'] ? {
    'RedHat' => 'httpd',
    'Debian' => 'apache2',
    default  => 'httpd',
  },
  Integer $http_port    = 80,
  String  $doc_root     = '/var/www/html',
  String  $server_admin = 'webmaster@localhost',
) {
  # Enforce the Trifecta Execution Order: Install -> Config ~> Service
  contain apache_webserver::install
  contain apache_webserver::config
  contain apache_webserver::service

  Class['apache_webserver::install']
  -> Class['apache_webserver::config']
  ~> Class['apache_webserver::service']
}
