#!/bin/bash
set -euxo

configure_datadisk() {

    mkdir -p /mc-server

    (
        echo n
        echo p
        echo 1
        echo
        echo
        echo w
    ) | fdisk /dev/nvme1n1

    mkfs.xfs /dev/nvme1n1 -f
    mount /dev/nvme1n1 /mc-server

    # Write to file system table (FSTAB)
    echo "$(blkid -o export /dev/nvme1n1 | grep ^UUID=) /mc-server xfs defaults,noatime" >> /etc/fstab
}

setup_dependencies() {

    java_download='https://download.oracle.com/java/18/archive/jdk-18.0.2.1_linux-aarch64_bin.rpm'
    server_jar='https://piston-data.mojang.com/v1/objects/c9df48efed58511cdd0213c56b9013a7b5c9ac1f/server.jar'

    cd /mc-server
    
    # Java installation
    wget ${java_download} -O java.rpm
    rpm -ivh java.rpm

    # Server installation
    wget ${server_jar} -O mc-server.jar
    java -Xmx1024M -Xms1024M -jar mc-server.jar nogui

    # enable eula
    echo "eula=true" > eula.txt

    # Clean up...
    rm java.rpm
}

enable_minecraft_on_startup() {

    cd /etc/systemd/system

    # Creates init file
    cat > minecraft.service <<EOL
[Unit]
Description=Start Minecraft
After=network.target

[Service]
Type=simple
ExecStart=/mc-server/start_server.bash
TimeoutStartSec=0

[Install]
WantedBy=default.target
EOL

    # Makes init file executable
    chmod +x minecraft.service

    # Creates bash script that will run on startup
    cd /mc-server

    cat > start_server.bash <<EOL
#!/bin/bash
cd /mc-server
exec java -Xmx1024M -Xms1024M -jar mc-server.jar nogui    
EOL

    # Makes "start" script executable
    chmod +x start_server.bash

    # enable service
    systemctl enable minecraft.service

}

configure_datadisk
setup_dependencies
enable_minecraft_on_startup