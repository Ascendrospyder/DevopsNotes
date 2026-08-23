# @summary Manages the Apache daemon running state
class apache_webserver::service {
  service { $apache_webserver::service_name:
    ensure     => running,
    enable     => true,
    hasrestart => true,
    hasstatus  => true,
  }
}
