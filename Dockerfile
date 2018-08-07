FROM alpine:3.4

MAINTAINER Ryan Zhang <ryan.zhang@docker.com>

RUN apk add --no-cache busybox musl libldap libltdl libsasl libuuid openldap openldap-clients

ADD files /ldap

RUN cat /ldap/tls.conf >> /etc/openldap/slapd.conf
RUN master_pass=$(tail -1 /ldap/master-password.txt) && \
    sed -i 's/rootpw.*$/rootpw     '${master_pass}'/' /etc/openldap/slapd.conf
RUN domain_name=$(tail -1 /ldap/domain-name.txt) && \
    sed -i 's/=my-domain,/='${domain_name}',/' /etc/openldap/slapd.conf && \
    sed -i 's/=my-domain,/='${domain_name}',/' /ldap/init.ldif && \
    sed -i 's/dc: my-domain/dc: '${domain_name}'/' /ldap/init.ldif

RUN cat /etc/openldap/slapd.conf
RUN slapadd -v -l /ldap/init.ldif 

EXPOSE 389

CMD slapd -d 256

