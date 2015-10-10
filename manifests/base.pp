# ネットワーク設定
file { "/etc/sysconfig/network":
ensure  => present,
content =>
  "NETWORKING=yes
  HOSTNAME=$myfqdn"
}

# ホスト名設定
exec { "hostname":
command => "hostname $myfqdn",
path    => "/bin:/sbin:/usr/bin:/usr/sbin"
}

# hosts設定
file { "/etc/hosts":
ensure  => present,
content =>
"127.0.0.1 localhost.vagrantup.com localhost
$myaddr $myfqdn $myname"
}

# Firewall無効化
service { "iptables":
  provider   => "redhat",
  enable     => false,
  ensure     => stopped,
  hasrestart => false
}
service { "iptables6":
  provider   => "redhat",
  enable     => false,
  ensure     => stopped,
  hasrestart => false
}

# SELinux無効化
exec { "SELinux":
  command => '/bin/sed -i -e "s|^SELINUX=.*$|SELINUX=disabled|" /etc/sysconfig/selinux'
}

exec { "setenforce":
  command => '/usr/sbin/setenforce 0'
}

# 起動オプション設定
exec { "grub":
  command => '/bin/sed -i -e "s|quiet.*$|quiet enforcing=0|" /etc/grub.conf'
}

# MACアドレスの自動保存無効化
exec { "ignore mac":
  command => "/bin/sed -i -e 's|/etc/udev/rules.d/70-persistent-net.rules|/dev/null|g' /lib/udev/write_net_rules"
}

# TimeZone設定
exec { "timezone":
  command => '/bin/cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime'
}

# Locale設定
exec { "locale":
  command => "/bin/sed -i -e 's/LANG.*$/LANG=\"ja_JP.utf8\"/' /etc/sysconfig/i18n"
}

# パッケージインストール
package { "httpd":        provider => "yum", ensure => "installed"}
package { "mysql-server": provider => "yum", ensure => "installed"}
package { "mysql":        provider => "yum", ensure => "installed"}
package { "php":          provider => "yum", ensure => "installed"}
package { "php-mbstring": provider => "yum", ensure => "installed"}
package { "php-mysql":    provider => "yum", ensure => "installed"}

# httpd.conf設定
#exec { "httpd.conf_1":
#command => "/bin/sed -i -e 's/^ServerAdmin.*$/ServerAdmin $admin/' /etc/httpd/conf/httpd.conf"
#}
#exec { "httpd.conf_2":
#command => "/bin/sed -i -e 's/^#ServerName.*$/ServerName $myfqdn:$httpport/' /etc/httpd/conf/httpd.conf"
#}

# サービス起動と自動起動設定
service { "httpd":
  name       => "httpd",
  enable     => true,
  ensure     => running,
  require    => Package["httpd"],
  hasrestart => true
}
service { "mysqld":
  name       => "mysqld",
  enable     => true,
  ensure     => running,
  require    => Package["mysql-server"],
  hasrestart => true
}

# 設定ファイル置換
file { "/etc/httpd/conf/httpd.conf":
  owner  => "root",
  group  => "root",
  mode   => "0644",
  ensure => file,
  before => Service["httpd"],
  source => "puppet:///modules/puppet/httpd.conf",
}
file { "/etc/php.ini":
  owner  => "root",
  group  => "root",
  mode   => "0644",
  ensure => file,
  before => Service["httpd"],
  source => "puppet:///modules/puppet/php.ini",
}
file { "/var/lib/mysql/my.cnf":
  owner   => "mysql",
  group   => "mysql",
  source  => "puppet:///modules/puppet/my.cnf",
  notify  => Service["mysqld"],
  require => Package["mysql-server"],
}
file { "/etc/my.cnf":
  require => File["/var/lib/mysql/my.cnf"],
  ensure  => "/var/lib/mysql/my.cnf",
}

# MySQL接続設定
exec { "set-mysql-password":
  unless  => "mysqladmin -uroot -p$mysql_password status",
  path    => ["/bin", "/usr/bin"],
  command => "mysqladmin -uroot password $mysql_password",
  require => Service["mysqld"],
}
define mysqldb( $user, $password ) {
  exec { "create-${name}-db":
    unless  => "/usr/bin/mysql -u${user} -p${password} ${name}",
    command => "/usr/bin/mysql -uroot -p$mysql_password -e \"create database ${name}; grant all on ${name}.* to ${user}@localhost identified by '$password';\"",
    require => Service["mysqld"],
  }
}
mysqldb { "myapp":
  user     => "myappuser",
  password => "myapppass",
}

# テストページ作成
file { '/var/www/html/index.html':
  mode    => '0644',
  owner   => 'root',
  group   => 'root',
  content => 'hello puppet world!!!!',
  require => Package['httpd'],
}
# phpinfo.php作成
file { '/var/www/html/info.php':
  ensure  => file,
  content => '<?php  phpinfo(); ?>',    # phpinfo code
  require => Package['httpd'],          # require 'apache2' package before creating
}
