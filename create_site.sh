#!/usr/bin/env bash
shopt -s extglob

# Default paths
ROOT_PATH="/usr/www"
TEMPLATE_PATH=$ROOT_PATH

# Other default variables
DOMAIN="example.com"
TEMPLATE_NAME="template.tar"

# Boolean variables
GIT=false
TEMPLATE=false

# Global variables
SITE=""
SUB_PATH=""
SITE_PATH=""
APACHE_SERVER_NAME=""

# Print usage syntax
function print_syntax() {
    echo "Usage: create_site SITE_NAME [SUBPATH|OPTIONAL] [OPTION]"
    echo "Try create_site --help' for more information."
    exit
}

function print_help() {
cat << EOF
Usage: create_site SITE_NAME [SUBPATH|OPTIONAL] [OPTION]
Creates a folder folder /usr/www and adds a new website to apache

Mandatory arguments to long options are mandatory for short options too.
    -g, --git                           create git repository for the new site
    -h, --help                          displays this help and exit
    -t, --template TEMPLATE_NAME        adds template to new folder,
                                            defaults to template.tar
                                            if no TEMPLATE_NAME is provided.
                                            supported template extentains:
                                            tar.bz2|tar.gz|bz2|rar|gz|
                                            tar|tbz2|tgz|zip|Z|7z
                                            provided that the correct programs
                                            are installed.
                                            looks by default in /usr/www
    -tp, --template-path PATH           where to look for templates

Example usage:
    create_site new_site
        creates folder /usr/www/new_site
        adds the site to apache with serverName new_site.domain

    create_site new_site dev -t -g
        creates folder /usr/www/dev/new_site
        extracts template.tar to that folder
        initializes git and makes a first commit
        adds the site to apache with serverName new_site.dev.domain

    create_site new_site dev/play -t new_template.zip -tp /home/user -g
        creates folder /usr/www/dev/play/new_site
        extracts new_template.zip from /home/user to that folder
        initializes git and makes a first commit
        adds the site to apache with serverName new_site.play.dev.domain
EOF
}

# Extract file
function extract() {
    if [ -f $1 ] ; then
        case $1 in
            *.tar.bz2)   tar xvjf $1    ;;
            *.tar.gz)    tar xvzf $1    ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar x $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xvf $1     ;;
            *.tbz2)      tar xvjf $1    ;;
            *.tgz)       tar xvzf $1    ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)           echo "Unknown file extention for file $1" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Checks if syntax is valid and if a subpath is provided
function init() {
    if [ $# -lt 1 ]; then
        print_syntax
    fi

    __shift_nr=0

    case "$1" in
        -h | --help)
            print_help
            exit
            ;;
        -* | *- | *[^a-zA-Z0-9-_]*)
            print_syntax
            ;;
        *)
            SITE=$1
            let __shift_nr+=1
    esac

    if [ $2 ] && [[ $2 != -* ]]; then
        SUB_PATH=$2
        let __shift_nr+=1
    fi
}

# Handle option parameters
function setup_options() {
    while [[ $1 ]]; do
        case "$1" in

            # Template option
            # Sets template to true
            # Sets new template name if provided
            -t | --template)
                TEMPLATE=true
                shift

                if [ $1 ] && [[ $1 != -* ]]; then
                    TEMPLATE_NAME=$1
                    shift
                fi
                ;;

            # Template path option
            # Sets the Template path if provided else discard
            -tp | -template-path)
                shift

                if [ $1 ] && [[ $1 != -* ]]; then
                    TEMPLATE_PATH=$1
                    shift
                fi
                ;;

            # GIT option
            -g | --git) GIT=true; shift ;;

            # Unknown option
            *) echo "Unknown paramater: $1"; shift ;;
        esac
    done
}

# Setup full site path and create and cd to dir
function setup_site_path() {
    SITE_PATH=$ROOT_PATH/$SUB_PATH/$SITE
    SITE_PATH=${SITE_PATH//\/*(\/)/\/}  # Remove multiple / if exists
    SITE_PATH=${SITE_PATH%/}    # Remove last / if exists
    mkdir -p $SITE_PATH
}

# Setup server name site.subpath.domain
function setup_apache_server_name() {
    APACHE_SERVER_NAME=$DOMAIN
    for i in $(echo "$SUB_PATH/$SITE" | tr "/" "\n")
    do
      APACHE_SERVER_NAME=$i.$APACHE_SERVER_NAME
    done
}

# Add and enable site apache
function add_site_to_apache() {
cat << EOF >> /etc/apache2/sites-available/$SITE
<VirtualHost *:80>
    ServerName $APACHE_SERVER_NAME
    DocumentRoot $SITE_PATH

    <Directory $SITE_PATH/>
        Option Indexes FollowSymLinks MultiViews
        AllowOverride None
        Order allow,deny
        allow from all
    </Directory>
</VirtualHost>
EOF
a2ensite
service apache2 restart
}


# Main
init $@    # Call init and shit array
shift $__shift_nr

setup_options $@
setup_site_path
setup_apache_server_name
add_site_to_apache
cd $SITE_PATH



# Add template to site if true
if $TEMPLATE; then
    # TODO add support for http/ftp files, if TEMPLATE_NAME is webfile wget and extract
    extract $TEMPLATE_PATH/$TEMPLATE_NAME
fi

# GIT
if $GIT; then
    git init
    git add .
    git commit -m "Project created"
fi

echo
echo "----"
echo "Root path: "$ROOT_PATH
echo "Sub path: "$SUB_PATH
echo "Site: "$SITE
echo "Site path: "$SITE_PATH
echo "Apache serverName: "$APACHE_SERVER_NAME
echo "Template: $TEMPLATE, $TEMPLATE_PATH/$TEMPLATE_NAME"
echo "Git: $GIT"