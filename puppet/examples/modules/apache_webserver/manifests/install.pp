# @summary Installs the Apache package via RAL
class apache_webserver::install {
  package { $apache_webserver::package_name:
    ensure => installed,
  }
}
