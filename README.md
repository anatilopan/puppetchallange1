# Puppet NGINX Challenge

Deadline 2023-01-20T15:00:00+02:00

## IMPORTANT: Please check the site.pp file first. I've worked directly in the site.pp file because I did not have enough time due to unforeseen servers' downtime at the current workplace that impacted productivity for our customers and this README file was created afterwards.

## Tasks

- [x] Create a proxy to redirect requests for https://domain.com to 10.10.10.10 and redirect requests for https://domain.com/resoure2 to 20.20.20.20.
- [x] Create a forward proxy to log HTTP requests going from the internal network to the Internet including: request protocol, remote IP and time take to serve the request.
- [x] (Optional) Implement a proxy health check.

## Notes

- Puppet Server: 10.1.1.40 puppetserver.local.aphios.ro
- Puppet Client: 10.1.1.41 puppetclient.local.aphios.ro domain.com ext.domain.com

## NGINX proxy with module

1. In order to deploy a simple NGINX proxy on your server you need first to install the "nginx" module on your Puppet server.

    Run the following on your Puppet server (using a privileged user):

    ```bash
    puppet module install puppet-nginx
    ```
    This will fetch the module from the forge `https://forge.puppet.com/` website and will install it on your server.

    ! IMPORTANT !: if your system uses APT, you have to install the apt module too:
    ``` bash
    puppet module install puppetlabs-apt
    ```

2. Create a new directory inside `/etc/puppetlabs/code/environments/production/modules`, in this case I'll name it "nginx_proxy_w_module" with another "manifests" directory inside.

    ```bash
    mkdir -p /etc/puppetlabs/code/environments/production/modules/nginx_proxy_w_module/manifests
    ```
3. Go to the created directory and create a new file named "init.pp" and open it with your preferred editor -- in my case I'll use vim.

    ```bash
    cd /etc/puppetlabs/code/environments/production/modules/nginx_proxy_w_module/manifests
    vim init.pp
    ```
4. Now we have to install and set the NGINX proxy.
   1. First by initializing the "nginx" module, the puppet client will install the NGINX software and it's dependencies. Please check this page for more information about the dependencies and the compatible OSs: [NGINX Module README page](https://forge.puppet.com/modules/puppet/nginx/readme)
   
   As I'm usually opting for stability over fancy features on production servers I tend to use the creator/maintainer of the software or the stable and tested by other people releases. In this case I'm using the official stable release from the NGINX project directly.

   On the first lines write:

   ```puppet
    class{'nginx':
    manage_repo => true,
    package_source => 'nginx-stable'
    }
   ```

5. Next, setting up the reverse proxy in order for the client to respond to the https requests on domain.com and redirect to 10.10.10.10

    ```puppet
    nginx::resource::server { 'domain.com':
        ensure     => present,
        proxy      => 'https://10.10.10.10',
        format_log => 'special',
        access_log => '/var/log/nginx/cusotm-access.log',
        error_log  => '/var/log/nginx/custom-error.log',
        ssl        => true,
        ssl_cert   => '/opt/certs/server.crt',
        ssl_key    => '/opt/certs/server.key',
    }
    ```
    I also created self-signed certificates in order to use https.

6. Redirecting the /resource2 path to 20.20.20.20

    ```puppet
    nginx::resource::location { '/resource2':
        ensure => present,
        proxy  => 'https://20.20.20.20',
        server => 'domain.com',
    }
    ```

7. Creating the redirect logging for forward proxy.

    1. I set up a generic resource outside my network. I used two known google IPs for this setup and redirected directly to port 80 (http) in order to escape for some settings that would not have to do with this test.

        ```puppet
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
        ```
    2. I've created a special logging format in order to include the required fields. Please note that this segment is inside the root node of nginx setup.

        ```puppet
        log_format     => {
        special => '[$remote_addr] - $remote_user [$time_local] -> [$request_time] <$ssl_protocol> "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"',
        },
        ```

    3. I created a new virtual host in order to access the outside resources and also set different paths to differentiate from the other logs.
   
        ```puppet
            nginx::resource::server { 'ext.domain.com':
                proxy      => 'http://proxytoext',
                format_log => 'special',
                access_log => '/var/log/nginx/ext-custom-access.log',
                error_log  => '/var/log/nginx/ext-custom-error.log',
            }
        ```

The file location of the puppet module is in /etc/puppetlabs/code/environments/production/manifests/site.pp for ease of implementation in this short time. It could be as well a separate module inside it's own directory with the manifests subdirectory.

Added passive healthcheck.
Cannot add active healthcheck as I don't have NGINX plus. But is as easly to implement as the passive ones using the `healthceck` directive.
