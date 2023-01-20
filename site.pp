#  Puppet Challange #1

# - [x] Create a proxy to redirect requests for https://domain.com to 10.10.10.10 and redirect requests for https://domain.com/resoure2 to 20.20.20.20.
# - [x] Create a forward proxy to log HTTP requests going from the internal network to the Internet including: request protocol, remote IP and time take to serve the request.
# - [ ] (Optional) Implement a proxy health check.

node default {
  # include nginx # Not used as I have to set some things manually.
  class { 'nginx':
    manage_repo    => true,
    package_source => 'nginx-stable',
    # Setting a special logging fromat to include request protocol, remote IP and time take to serve the request
    log_format     => {
      special => '[$remote_addr] - $remote_user [$time_local] -> [$request_time] <$ssl_protocol> "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"',
    },
  }

  nginx::resource::server { 'domain.com':
    ensure     => present,
    proxy      => 'https://10.10.10.10', #redirect to another server. As required 10.10.10.10, tested with a real internal IP in my testing env.
    format_log => 'special', # just to have the logs in the same format as the proxy to external resources..
    access_log => '/var/log/nginx/cusotm-access.log',
    error_log  => '/var/log/nginx/custom-error.log',
    ssl        => true, # don`t know if was required, but I saw that all requirements were using "https" so I did that.
    ssl_cert   => '/opt/certs/server.crt', # generated some self signed certs/keys for this test..
    ssl_key    => '/opt/certs/server.key',
  }

  nginx::resource::location { '/resource2':
    # redirect requests for https://domain.com/resoure2 to 20.20.20.20
    ensure => present,
    proxy  => 'https://20.20.20.20',
    server => 'domain.com',
  }

  nginx::resource::upstream { 'proxytoext':
    # Used for the external resources trough proxy.
    members => {
      '142.250.185.238:80' => { # one of google`s ip-s
        server => '142.250.185.238',
        port   => 80,
        weight => 1,
      },
      '172.217.167.174:80' => { # one of google`s ip-s
        server => '172.217.167.174',
        port   => 80,
        weight => 2,
      },
    },
  }
  nginx::resource::server { 'ext.domain.com':
    # Create a forward proxy to log HTTP requests going from the internal network to the Internet including: request protocol, remote IP and time take to serve the request.
    proxy      => 'http://proxytoext',
    format_log => 'special', # Set the proxy logging format as required.
    access_log => '/var/log/nginx/ext-cusotm-access.log', # Costum path to diferenciate from the other logs.
    error_log  => '/var/log/nginx/ext-custom-error.log', # same as above
  }
}
