# AppVeyor Setup

We use appveyor *Environment Deployment* to upload binaries to the ftp server. This means that the deployment does not happen as part of the build process, but instead *artifacts* of succesful build get deployed to a predefined *deployment environment*.

The deployment environments are defined in https://ci.appveyor.com/environments. Currently we have 2 deployment environments: `ftp_archive` and `ftp_current`. Both simply sftp to the ftp server. 

## FTP Server

Ubuntu 16.04. First configure the firewall:

```
sudo ufw allow OpenSSH
sudo ufw allow http
sudo ufw allow https
sudo ufw allow ftp
sudo ufw allow 20/tcp
sudo ufw allow 990/tcp
sudo ufw allow 40000:50000/tcp
sudo ufw enable
sudo ufw status
```

Also `ssh-copy-id` and set `ChallengeResponseAuthentication no` in `/etc/ssh/sshd_config`.

### SSH (SFTP)

We add a special user to sftp files:

```
sudo adduser upload
```

Then setup the ftproot directory. For ssh chroot to work, directory `/ftproot` has to be owned and only writable by `root`. The `upload` user can only write within `/ftproot/archive` and `/ftproot/current`.

```
sudo mkdir -p /ftproot/archive
sudo mkdir -p /ftproot/ftproot
sudo chown root:root /ftproot
sudo chown upload:upload /ftproot/*
```

Then make user `upload` for sftp only and chroot in `/ftproot`. Edit `/etc/ssh/sshd_config` and add to the bottom.

```
Match group upload
  ChrootDirectory /ftproot
  X11Forwarding no
  AllowTcpForwarding no
  ForceCommand internal-sftp
  PasswordAuthentication yes
```

To cleanup put this script in `/home/upload/cleanup.sh`. Here `+30` refers to age in number of days.

```
find /ftproot/archive/r-devel/ /ftproot/archive/r-patched -type d -mtime +25 -exec rm -R "{}" \;
```

Then a cronjob for user `upload` with:

```
0 0 * * * /home/upload/cleanup.sh >> /home/upload/cleanup.log 2>&1
```

### HTTP

First install the server

```
sudo apt-get install apache2
```

Added a site `/etc/apache2/sites-available/ftp.conf`

```
Alias / /ftproot/
<Directory /ftproot>
    Options FollowSymLinks MultiViews Indexes
    DirectoryIndex nothing
    Require all granted
</Directory>
```

And then run `sudo a2ensite ftp` to activate. I also added letsencrypt certs using [standard instructions](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-16-04).

Add this line to `/etc/mime.types` to make utf-8 log files show properly in the browser:

```
echo "text/plain;charset=utf-8                        log"
```


### FTP

Installed `vsftpd` and edited `/etc/vsftpd.conf` with the following rules:

```
local_enable=NO
anonymous_enable=YES
anon_root=/ftproot/
no_anon_password=YES
hide_ids=YES
pasv_min_port=40000
pasv_max_port=50000
allow_anon_ssl=YES
ssl_enable=YES
ssl_tlsv1=YES
ssl_sslv3=NO
ssl_ciphers=HIGH
force_local_data_ssl=NO
force_local_logins_ssl=NO
rsa_cert_file=/etc/letsencrypt/live/ftp.opencpu.org/fullchain.pem
rsa_private_key_file=/etc/letsencrypt/live/ftp.opencpu.org/privkey.pem
```

Then `sudo service vsftpd restart`. Note we use the same apache2 letsencrypt certs for ftps.

### CRAN rsync

First did full sync with CRAN master (see [mirror-howto](https://cran.r-project.org/mirror-howto.html)). Requires a CRAN approved key in `~/.ssh/id_rsa`. Then:

```
sudo mkdir /CRAN
sudo chown jeroen:jeroen /CRAN
mkdir -p /CRAN/bin/windows
rsync -rtlzv --delete  --exclude "contrib" cran-rsync@cran.r-project.org:bin/windows/ /CRAN/bin/windows/
```

Then `crontab -e` for user `jeroen` and added a line:

```
0 6 * * * cp -fp /ftproot/current/* /CRAN/bin/windows/base/ >> /home/jeroen/copy.log 2>&1
```

This deploys r-patched and r-devel every morning at 6am GMT (builds start at 3AM).
