source $PROJECTS/ddc-tools2/tools-lib.sh
source ~/.ssh/davidw135_hub_creds.txt
source ~/.ssh/docker-core-aws-creds.sh
open_firewall() {
    echo "firewall_ports:" > fw-ports.yaml
    echo "- 389-393/tcp" >> fw-ports.yaml
    echo "- 8000-8100/tcp" >> fw-ports.yaml
    echo "- 9090/tcp" >> fw-ports.yaml
    echo "- 30101-34999/tcp" >> fw-ports.yaml
}


# AWS types: https://aws.amazon.com/ec2/instance-types/
#            https://aws.amazon.com/ec2/pricing/on-demand/
# Type      vCPU   RAM-GB  Drive       bandwidth-mBPS
# m3.medium    ?    3.75   SSD         moderate      $0.067 per Hour
# m3.large     ?    7.5    SSD         moderate      $0.133 per Hour
# c5.xlarge    4    8.0    EBS-Only    2,250         $0.170 per Hour
# t2.xlarge    4   16.     EBS             ?         $0.186 per Hour
# m5.xlarge    4   16.     EBS         2,120         $0.192 per Hour
# c4.xlarge    4    7.5    EBS-Only      750         $0.199 per Hour
# m4.large     2    8.0    EBS-only      450         $0.200 per Hour
# i3.xlarge    4   30.5    SSD                       $0.312 per Hour
# c4.2xlarge   8   15.0                              $0.398 per Hour


export AWS_ACCT="docker-core"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_USERNAME="dwilliamson"
export NUM_LINUX_HOSTS="1"
export NUM_WINDOWS_HOSTS="0"
export TESTKIT_AWS_INSTANCE_TYPE_LINUX="c4.xlarge"
export TESTKIT_AWS_KEYNAME="davidw"
export TESTKIT_AWS_REGION="us-east-1"
export TESTKIT_AWS_SECURITY_GROUP="sg-65ebb41a"
export TESTKIT_CERTS_DIR="/Users/davidwilliamson/.testkit/certs"
export TESTKIT_DRIVER="aws"
export TESTKIT_ENGINE="ee-test-17.06.2"
export TESTKIT_INSTALL_TIMEOUT="60m"
export TESTKIT_MACHINE_PREFIX="davidw-ldap-srv"
export TESTKIT_PLATFORM_LINUX="ubuntu_16.04"
export TESTKIT_PRESERVE_TEST_MACHINE="1"
export TESTKIT_SKIP_SELINUX="1"
export TESTKIT_SSH_KEYPATH="/Users/davidwilliamson/.ssh/docker_qa_private_key-id_rsa"
export TESTKIT_SSH_USER_LINUX="docker"

testkit create 1 0 --no-swarm

allocate_nodes $NUM_LINUX_HOSTS $NUM_WINDOWS_HOSTS
eval "$(testkit machine env $CONTROLLER_NODE --no-ucp)"
export CONTROLLER_HOST_ADDRESS=$(testkit_ip $CONTROLLER_NODE)
export CONTROLLER_PUBLIC_ADDRESS=$CONTROLLER_HOST_ADDRESS
export CONTROLLER_PRIVATE_ADDRESS=$(asw_ec2_get_private_ip $CONTROLLER_NODE)
export CONTROLLER_HOST_ADDRESS=$CONTROLLER_PRIVATE_ADDRESS
export STACK_NAME=$(testkit system ls --quiet | grep $TESTKIT_MACHINE_PREFIX)

for node in $ALL_NODES; do disable_login $node ; done

for node in $ALL_NODES; do fix_ntp $node; done

testkit_controller
