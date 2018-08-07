#!/usr/bin/env bash

# add users to the LDAP config file.
# revert the config file via:
# git checkout files/init.ldif
#
# Can instead create a second file from the defaults, and add these users to 
# a live LDAP server via:
# ldapadd -x -c -H ldap://localhost -D "cn=Manager,dc=my-domain,dc=com" -w secret -f <new_file.ldif>
# and verify the new users via
# ldapsearch -H ldap://localhost -D "cn=Manager,dc=my-domain,dc=com" -w secret -b dc=my-domain,dc=com

# TODO: 
# 1. have ability to set LDAP server password
# 2. have ability to set DOMAIN (Required to run multiple instances.
#     Need to modify Dockerfile)
#     in /etc/openldap/slapd.conf , change 'my-domain' 
#suffix          "dc=my-domain,dc=com"
#rootdn          "cn=Manager,dc=my-domain,dc=com"
# 3. have ability to add created users to team(s)
# 4. build docker image based on this config
# 5. insert a /README file into image, giving LDAP config for this image
#  ----------- LDAP configuration -----------
# docker run \
#  --rm \
#  --name ldap-server-3 \
#  -d \
#  -p 390:389 \
#  davidw135/openldap4docker:secret2_10001_to_10100

#  LDAP server   : ldap://${CONTROLLER_PRIVATE_ADDRESS}:${PORT}
#  Reader DN     : cn=Manager,dc=my-domain,dc=com
#  Reader Pass   : ${LDAP_MASTER_PASSWORD}
#  Skip TLS      : false
#  Use Start TLS : false
#  Just in time  : true
#  Base DN       : ou=Users,dc=my-domain,dc=com
#  Username attr : cn
#  Full name attr: cn
#  user/password : bob/bobpassword
#  user/password : user000001/userpass000001
#  user/password : user010001/userpass010001
#  


DOMAIN=$(tail -1 files/domain-name.txt)
DC='com'
CONFIG_FILE='files/init.ldif'
START_USER=1
USERS_TOCREATE=10
BASE_PASSWORD='userpass'

usage() {
cat <<EOF
usage: $0 \\
  --start=<NUM> \\
  --num_users=<NUM> \\
  --base_password='mySecr3t'

Will populate the file '$CONFIG_FILE' with users by appending to the file.
That is, this script is NOT idempotent. Running multiple times will result
in the file '$CONFIG_FILE' increasing in size each time.

Use 'git checkout $CONFIG_FILE' to revert the file to its original state.

Usernames are of the form : 'user000001',     'user000002'      ... 'userNNNNNN'
Corresponding passwords   : '${BASE_PASSWORD}000001', '${BASE_PASSWORD}000002', ...

Options:

    --start           : Integer. First user defined will have this number.
                                 Default is $START_USER
   --num_users        : Integer. How many users to define.
                                 Default is $USERS_TOCREATE
   --base_password    : string.  Base string for user passwords.
                                 Default is '${BASE_PASSWORD}'
                                 Note: if specifying this parameter, use
                                 single quotes to avoid shell expansion.
EOF
}


process_inputs() {
    while [ "$#" -gt 0 ]; do
    case "$1" in
        --help) usage; exit 1;;
        --start=*) START_USER="${1#*=}"; shift 1;;
        --num_users=*) USERS_TOCREATE="${1#*=}"; shift 1;;
        --base_password=*) BASE_PASSWORD="${1#*=}"; shift 1;;
        --start|--num_users|--base_password) echo "$1 requires an argument" >&2; exit 1;;
        -*) echo "unknown option: $1" >&2; usage; exit 1;;
        *) usage; exit 1;;
    esac
    done
}

validate_inputs() {
    case $START_USER in
        ''|*[!0-9]*) echo "invalid param '$START_USER' expected int"; usage ;;
        *) echo verified START_USER=$START_USER ok > /dev/null ;;
    esac
    case $USERS_TOCREATE in
        ''|*[!0-9]*) echo "invalid param '$USERS_TOCREATE' expected int"; usage ;;
        *) echo verified USERS_TOCREATE=$USERS_TOCREATE ok > /dev/null ;;
    esac
}

generate_user_record() { local id=$1
    user_name="user"$(printf '%06d' $id)
    surnam="Surname"$(printf '%06d' $id)
    user_pass="${BASE_PASSWORD}"$(printf '%06d' $id)
    read -r -d '' new_record <<EOF
dn: cn=$user_name,ou=Users,dc=${DOMAIN},dc=${DC}
sn: $surnam
cn: $user_name
userPassword: $user_pass
objectclass: person

EOF
}

write_readme() {
    local DOMAIN=$(tail -1 files/domain-name.txt)
    local LDAP_MASTER_PASSWORD=$(tail -1 files/master-password.txt)
    local user_name="user"$(printf '%06d' $START_USER)
    local user_pass="${BASE_PASSWORD}"$(printf '%06d' $START_USER)
    cat > files/README.sh <<EOF
echo "Domain        : dc=${DOMAIN},dc=com"
echo "Reader DN     : cn=Manager,dc=${DOMAIN},dc=com"
echo "Reader Pass   : ${LDAP_MASTER_PASSWORD}"
echo "Skip TLS      : false"
echo "Use Start TLS : false"
echo "Just in time  : true"
echo "Base DN       : ou=Users,dc=${DOMAIN},dc=com"
echo "Username attr : cn"
echo "Full name attr: cn"

echo "user/password : ${user_name}/${user_pass}"
echo "number of users: ${USERS_TOCREATE}"
echo " "
echo "To start the LDAP server:"
echo "docker run --rm --name ldap-server -d -p 389:389 <this-image>:<this-tag}"
echo " "
echo "Each image tag has a different set of users and a different domain, so UCP"
echo "can be configured to use multiple LDAP servers.  To run multiple LDAP"
echo "servers, start a different image and expose a different port:"
echo "docker run --rm --name ldap-server2 -d -p 390:389 <this-image>:<different-tag}"

EOF
    chmod 755 files/README.sh
}

process_inputs $@
validate_inputs

end_user=$(( START_USER + USERS_TOCREATE - 1))
if (( $end_user < $START_USER )); then
    end_user=$START_USER
fi
for i in `seq $START_USER $end_user`; do
    if (( $i % 100 == 0 )); then
        echo "Created user $i"
    fi
    generate_user_record $i
    echo "$new_record"$'\n' >> ${CONFIG_FILE}
done

write_readme
cat files/README.sh
ls -Flag  $CONFIG_FILE
