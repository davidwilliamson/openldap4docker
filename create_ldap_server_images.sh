# index is used to create unique usernames.
# user000001, user000002, etc.
start_index=1
# how many users to create per LDAP server. Right now, we will create
# two LDAP servers, both with this many users.
num_users=20

build_ldap_server_image() {
    local FIRST_LDAP_USER=$1
    local NUM_LDAP_USERS=$2
    LDAP_MASTER_PASSWORD=$(tail -1 files/master-password.txt)
    git checkout files/init.ldif
    ./add_users.sh --start=$FIRST_LDAP_USER --num_users=${NUM_LDAP_USERS}
    tail -10 files/init.ldif
    local last=$(( FIRST_LDAP_USER + NUM_LDAP_USERS - 1 ))
    IMAGE=davidw135/openldap4docker:${LDAP_MASTER_PASSWORD}_${FIRST_LDAP_USER}_to_${last}
    docker build -t $IMAGE .
}

dump_readme() {
    local image=$1
    echo "----------"
    echo "Configuration for $image"
    docker run --rm -i $image sh <<'EOF'
/ldap/README.sh
exit
EOF
}

set_ldap_password() {
    local new_password=$1
    if [[ -z "$new_password" ]]; then
        echo "missing new passowrd"
        return
    fi
    local current_password=$(tail -1 files/master-password.txt)
    sed -i -e 's/'$current_password'/'$new_password'/' files/master-password.txt
    local updated_password=$(tail -1 files/master-password.txt)
    echo "changed password from '$current_password' to '$updated_password'"
}

set_ldap_domain() {
    local new_domain=$1
    if [[ -z "$new_domain" ]]; then
        echo "missing new domain"
        return
    fi
    local current_domain=$(tail -1 files/domain-name.txt)
    sed -i -e 's/'$current_domain'/'$new_domain'/' files/domain-name.txt
    local updated_domain=$(tail -1 files/domain-name.txt)
    echo "changed domain from '$current_domain' to '$updated_domain'"
}

start_ldap_server() {
    local image=$1
    local PORT=$2
    if [[ -z "$PORT" ]]; then
        echo "missing PORT"
        return
    fi
    if [[ -z "$image" ]]; then
        echo "missing image"
        return
    fi
    docker run \
    --rm \
    --name ldap-server-${PORT} \
    -d \
    -p ${PORT}:389 \
    $image
}

docker pull ry4nz/openldap4docker

IMAGES=''
set_ldap_password secret1
set_ldap_domain domain-${start_index}
build_ldap_server_image ${start_index} ${num_users}
IMAGES="${IMAGES} $IMAGE"

start_index=$(( start_index + num_users ))
set_ldap_password secret2
set_ldap_domain domain-${start_index}
build_ldap_server_image ${start_index} ${num_users}

IMAGES="${IMAGES} $IMAGE"
for i in $IMAGES; do
    dump_readme $i
done
exposed_port=389
for i in $IMAGES; do
    start_ldap_server $i $exposed_port
    echo "LDAP server URL: ldap://${CONTROLLER_PRIVATE_ADDRESS}:${exposed_port}"
    exposed_port=$(( exposed_port + 1 ))
done
docker ps
popd

exit 0

#docker push davidw135/openldap4docker:${NUM_LDAP_USERS}
#docker pull davidw135:openldap4docker:${NUM_LDAP_USERS}

#docker run --rm --name ldap-server-1 -d -p 389:389 ry4nz/openldap4docker
node_dump

cat <<EOF
----------- LDAP configuration -----------
LDAP server   : ldap://${CONTROLLER_PRIVATE_ADDRESS}:${PORT}
Reader DN     : cn=Manager,dc=my-domain,dc=com
Reader Pass   : ${LDAP_MASTER_PASSWORD}
Skip TLS      : false
Use Start TLS : false
Just in time  : true
Base DN       : ou=Users,dc=my-domain,dc=com
Username attr : cn
Full name attr: cn
user/password : bob/bobpassword
user/password : user000001/userpass000001
EOF

# Test connection. On UCP cluster:
echo curl -k -u 'admin:<admin-password>' https://$CONTROLLER_HOST_ADDRESS/enzi/v0/conf/auth/ldap
