# Let's Encrypt Nginx
# == Class: letsencrypt_nginx
#
# @summary Let's Encrypt base configuration and hiera interface.
#
# === Parameters
#
#  @param default_server_name
#    name of nginx server that catches all requests that do not match any other server_name
#
#  @param webroot
#    This directory is configured as webroot for the webroot authentication
#    locations added to the server to allow renewals
#
#  @param firstrun_webroot
#    Use different webroot on first run.
#    Set this to the default webroot of the webserver if the service
#    starts automatically when installed.
#    E.g. For Nginx on Ubuntu: /var/www/html
#
#  @param firstrun_standalone
#    Use standalone mode on first run.
#    Set this to true if the webserver does not start automatically when installed.
#    letsencrypt will use standalone mode to get the certificate
#    before the webserver is started the first time.
#
#  @param locations
#    These Parameters can be used to create instances of these defined types through hiera
#  @param servers
#    These Parameters can be used to create instances of these defined types through hiera
#
class letsencrypt_nginx (
  String $default_server_name        = 'default',
  String $webroot                    = '/var/lib/letsencrypt/webroot',
  Optional[String] $firstrun_webroot = undef, # For Debian & Nginx: /var/www/html
  Boolean $firstrun_standalone       = false,
  Hash $locations                    = {},
  Hash $servers                      = {},
  String $cron_success_command       = '/bin/systemctl reload nginx.service',
) {
  include nginx
  require ::letsencrypt

  Exec { path => ['/bin/', '/sbin/' , '/usr/bin/', '/usr/sbin/'] }

  # define webroot directory for letsencrypt challenge
  if $webroot == '/var/lib/letsencrypt/webroot' {
    file { ['/var/lib/letsencrypt','/var/lib/letsencrypt/webroot']:
      ensure => directory,
      owner  => root,
      group  => root,
      mode   => '0644';
    }
  }

  # configure default nginx server if not defined yet
  if $default_server_name == 'default' {
    unless defined(Nginx::Resource::Server['default']) {
      nginx::resource::server { 'default':
        listen_options => default_server,
        server_name    => ['default'],
        www_root       => $webroot,
      }
    }
  }

  exec { 'set letsencrypt_nginx_firstrun fact':
    command     => 'mkdir -p /etc/facter/facts.d/ && echo "letsencrypt_nginx_firstrun=SUCCESS" > /etc/facter/facts.d/letsencrypt_nginx.txt',
    refreshonly => true,
  }

  create_resources('letsencrypt_nginx::location', $locations)
  create_resources('letsencrypt_nginx::server',   $servers)

  # configure location for letsencrypt challenge path for default server
  if $default_server_name != false {
    ensure_resource('letsencrypt_nginx::location', $default_server_name)
  }
}
