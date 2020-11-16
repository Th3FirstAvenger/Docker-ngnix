#!/bin/bash

if [[ $(docker network ls | grep web) ]]; then 
  echo -e "[i]  Eliminant network web..."
  docker network rm web
fi 
# Create network 
echo -e "[i]  Creant network web"
docker network create web

# Exportar credencials
echo -e "[i] Exportant credencials.. \n\tusuari: profe \n\tpasswd: chequejant"
export ADMIN_USER=profe
export ADMIN_PASSWORD=chequejant
export HASHED_PASSWORD=$(openssl passwd -apr1 $ADMIN_PASSWORD)

echo -e "[i] Assignant els permissos..."
sudo chown -R $USER:$USER *

# Creant la infraestuctura
echo -e "[i]  Creant la infraestuctura..."
docker-compose build
# Aixecant la infraestuctura
echo -e "[i]  Aixecant la infraestuctura..."
docker-compose up -d 

#Docke-compose -f ftp_server.yml up -d 
