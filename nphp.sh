#/bin/bash
#NGINX+PHP8.0

function System-version(){
    systemver=`cat /etc/*release* 2>/dev/null | awk 'NR==1{print}' |sed -r 's/.* ([0-9]+)\..*/\1/'`
    if [[ $systemver = "6" ]];then
        echo "当前是CentOS6系统"
        echo "此脚本仅支持CentOS7系统！！！"
        exit 1
    elif [[ $systemver = "7" ]];then
        echo "当前是CentOS7系统，开始安装..."
    else    
        echo "此脚本仅支持CentOS7系统！！！"
        exit 1
    fi
}
function echo_green {
        echo -e "\033[32m$1\033[0m"
}
System-version


# 配置系统环境
setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --reload
tar -czvf /etc/yum.repos.d/repos.tgz /etc/yum.repos.d/
rm -f /etc/yum.repos.d/*.repo /etc/yum.repos.d/*/*.repo
curl -o /etc/yum.repos.d/Centos-7.repo http://mirrors.aliyun.com/repo/Centos-7.repo
yum -y install epel-release wget vim
curl -o /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum -y install aria2   #aira2c -x8 -o epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
yum -y install yum-utils net-tools ntpdate gcc unzip zlib zlib-devel pcre-devel openssl openssl-devel
cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && ntpdate time1.aliyun.com


# 安装Nginx及PHP8.0
cat > /etc/yum.repos.d/Remi-7.repo << EOF
[Remi]
name=Remi's RPM repository for Enterprise Linux 7 - $basearch
baseurl=https://mirrors.aliyun.com/remi/enterprise/7/safe/\$basearch/
failovermethod=priority
enabled=1
gpgcheck=1
gpgkey=http://rpms.remirepo.net/RPM-GPG-KEY-remi

[remi-php80]
name=Remi's PHP 8.0 RPM repository for Enterprise Linux 7 - $basearch
baseurl=https://mirrors.aliyun.com/remi/enterprise/7/php80/\$basearch/
#mirrorlist=http://cdn.remirepo.net/enterprise/7/php80/mirror
enabled=1
gpgcheck=1
gpgkey=http://rpms.remirepo.net/RPM-GPG-KEY-remi

EOF
#yum --showduplicates list nginx | expand   #查看nginx可用的安装包
yum remove -y php-common
yum install -y nginx php-cli php-fpm php-mysqlnd php-zip php-devel php-gd php-mbstring php-curl php-xml php-pear php-bcmath php-json php-redis php-ldap php-fileinfo php-intl php-opcache php-mcrypt php-xmlrpc php-sysvsem php-soap php-posix
systemctl start nginx && systemctl enable nginx
systemctl start php-fpm && systemctl enable php-fpm



# 修改PHP配置
sed -i 's#;date.timezone =#date.timezone = Asia/Shanghai#' /etc/php.ini
sed -i 's#upload_max_filesize = 2M#upload_max_filesize = 20M#' /etc/php.ini
sed -i 's/;listen.owner = php/listen.owner = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/;listen.group = php/listen.group = nginx/' /etc/php-fpm.d/www.conf
sed -i 's/;listen.mode = 0660/listen.mode = 0660/' /etc/php-fpm.d/www.conf
sed -i 's#user = apache#user = nginx#' /etc/php-fpm.d/www.conf
sed -i 's#group = apache#group = nginx#' /etc/php-fpm.d/www.conf
#sed -i 's#listen = 127.0.0.1:9000#listen = /dev/shm/php-fpm.sock#' /etc/php-fpm.d/www.conf
systemctl restart php-fpm && systemctl restart nginx


# 询问是否继续部署网站
echo_green "基础软件安装完毕，是否部署网站页面？(y/n)："
read answer
if [ "$answer" == "y" ]; then
    echo_green "开始部署***网站"    #以PHP探针为例
else
    echo_green "拜拜了"
    exit
fi


# 部署网站业务系统
mkdir /www
curl -o /www/index.php https://www.itca.cc/file/tz.php1
chown -R nginx:nginx /www
cat > /etc/nginx/conf.d/TZ.conf << EOF
    server {
        listen       80;
        server_name  localhost;
        client_max_body_size 20M;

        location / {
            root   /www;
            index index.php index.html index.htm;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        location ~ \.php\$ {
            root           /www;
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
EOF
systemctl restart nginx
