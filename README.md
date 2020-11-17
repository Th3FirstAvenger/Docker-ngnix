# Docker-ngnix
Practica para configurar un servidor HTTP 

Per executar aquests contanidors simplament hem de descarregar el repositori i executar el `start.sh`.
```
bash start.sh
```
El codi que permet crear la infraestuctura el tenim en el docker_compose.yml
```yml
version: '3'

services:
  # [EXTRA] Em fa de reverse proxy
  traefik:
    image: traefik:1.7.6-alpine
    restart: always
    ports:
      - 80:80
      - 443:443
    networks:
      - web
    volumes:
      - $PWD/acme.json:/acme.json # Ruta SSL 
      - $PWD/traefik.toml:/traefik.toml # Fitxer de configuració
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      - "traefik.frontend.auth.basic=$ADMIN_USER:$HASHED_PASSWORD" # Demanar credencials per accedir previament exportades
      - "traefik.docker.network=web"
      - traefik.frontend.rule=Host:traefik.mhr.itb
      - traefik.port=8080

  # Monitoritzar els sistemes
  monit:
    image: pottava/docker-webui
    expose:
      - "9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - web
    labels: # Creem els nivells necessaris per traefik
      - "traefik.backend=monitor"
      - "traefik.frontend.rule=Host:$MONITOR_DOMAIN"
      - "traefik.docker.network=web"
      - "traefik.enable=true"
      - "traefik.port=9000"
      - "traefik.default.protocol=http"
      - "traefik.frontend.auth.basic=$ADMIN_USER:$HASHED_PASSWORD" # aquestes variables les exporto en el start.sh

# Servidor FTP  
  ftpd-server:
    container_name: ftpd-server
    image: stilliard/pure-ftpd
    ports:
      - "21:21" # Obro el port 21
      - "30000-30009:30000-30009"
    environment:
      PUBLICHOST: 0.0.0.0 # Per que es pugui connectar cualsevol equip
      FTP_USER_NAME: $ADMIN_USER  # user previament assignat utilitzant la variable 
      FTP_USER_PASS: $ADMIN_PASSWORD # password assignada previament en una variable 
      FTP_USER_HOME: /data/ftpd/
    restart: on-failure
    networks:
      - web
      - internal
    volumes:
      - "./web22/modificacions/:/data/ftpd/"
      
# Web utilitzant el servei nginx, proporciona la informació i descripció de la infraestuctura.
  web11:
    image: nginx
    restart: always
    volumes:
      - ./web11:/usr/share/nginx/html:ro
    labels:
      - traefik.backend=web11
      - traefik.frontend.rule=Host:$web11
      - traefik.docker.network=web
      - traefik.port=80
    networks:
      - internal
      - web

# Web utilitzant el servei nginx mostra les instruccions a seguir 
  web22:
    image: nginx
    restart: always
    volumes:
      - ./web22:/usr/share/nginx/html:ro
    labels:
      - traefik.backend=web22
      - traefik.frontend.rule=Host:$web22
      - traefik.docker.network=web
      - traefik.port=80
    networks:
      - internal
      - web
  
  # [EXTRA] Serveis per la pagina wordpress
  
  mariaDB:
    image: mariadb:latest
    restart: always
    volumes:
     - database:/var/lib/mysql:rw
    expose:
     - "3306" 
    labels:
     - "traefik.backend=mariadb"
     - "traefik.docker.network=web"
     - "traefik.enable=false" 
    environment:
     - MYSQL_ROOT_PASSWORD=$MYSQL_PASS
    networks:
      - internal
      - web

  adminer:
    image: adminer
    restart: always
    ports:
      - 8090:8080
    labels:
     - "traefik.backend=admirer"
     - "traefik.docker.network=web"
     - "traefik.frontend.rule=Host:$DB_DOMAIN"
    depends_on:
     - mariaDB
    networks:
      - internal
      - web

  wordpress:
    image: wordpress
    restart: always
    depends_on:
      - mariaDB
    environment:
     - WORDPRESS_DB_HOST=$DB_HOST
     - WORDPRESS_DB_NAME=$DB_NAME
     - WORDPRESS_TABLE_PREFIX=$DB_PREFIX
     - WORDPRESS_DB_USER=$DB_USER
     - WORDPRESS_DB_PASSWORD=$DB_PASSWORD
    volumes:
      - ./wp/config/uploads.ini:/usr/local/etc/php/conf.d/uploads.ini
      - ./wp/wp-app:/var/www/html # Full wordpress project
    labels:
      - "traefik.frontend.rule=Host:$WORDPRESS_DOMAIN"
      - "traefik.docker.network=web"
      - "traefik.backend=wordpress"
    networks:
      - internal
      - web


networks:
  web: # Xarxa bridge que em permet conectat tots els serveis per tant s'haurà de crear ( docker network create web ) 
    external: true
  internal:
    external: false
volumes: # Aquests espai son necessaris pel funcionament del servei wordpress
  portainer_data: {} 
  database:
```

Per veure la configuració que he fet per que funcioni el proxy revers es troba en el fitxer traefik.toml.
```toml
defaultEntryPoints = ["http", "https"]

[entryPoints]
  [entryPoints.dashboard]
    address = ":8080"
  [entryPoints.http]
    address = ":80"
      [entryPoints.http.redirect]
        entryPoint = "https"
  [entryPoints.https]
    address = ":443"
      [entryPoints.https.tls]

[api]
entrypoint="dashboard"

[acme]
email = "marc@mhr.itb"
storage = "acme.json"
entryPoint = "https"
onHostRule = true
  [acme.httpChallenge]
  entryPoint = "http"

[docker]
domain = "mhr.itb"
watch = true
network = "web"

```

I el certificat ssl ho guarda en el fitxer acme.json. Que és necessari assignar els següents permissos. 

```
chmod 600 acme.json
```
Finalment tenim el fitxer `.env` que em permet guardar les variables que utilitzo en el docker-compose.yml.
