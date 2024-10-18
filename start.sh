#!/bin/bash

# Demander à l'utilisateur de choisir entre "dev" ou "build"
echo "Choisissez un mode: dev ou build ?"
read MODE

# Vérifier la réponse de l'utilisateur
if [ "$MODE" = "dev" ]; then
    echo "Mode développement sélectionné."
    
    # Demander l'adresse IP du serveur
    echo "Veuillez entrer l'adresse IP du serveur :"
    read SERVER_IP
    
    # Cloner le dépôt Git et se déplacer dans le répertoire springboard
    git clone https://github.com/entcore/springboard.git
    cd springboard || { echo "Le dossier springboard n'existe pas."; exit 1; }
    echo "Dépôt cloné et répertoire springboard ouvert."
    
    # Créer le fichier docker-compose.yaml
    echo "Création du fichier docker-compose.yaml..."
    cat <<EOL > docker-compose.yaml
version: '3'

services:
  vertx:
    image: opendigitaleducation/vertx-service-launcher:1.1-SNAPSHOT
    user: "1000:1000"
    ports:
      - "8090:8090"
      - "5000:5000"
    volumes:
      - ./assets:/srv/springboard/assets
      - ./mods:/srv/springboard/mods
      - ./ent-core.json:/srv/springboard/conf/vertx.conf
      - ./aaf-duplicates-test:/home/wse/aaf
      - ~/.m2:/home/vertx/.m2
    links:
      - neo4j
      - postgres
      - mongo
      - pdf
      - elasticsearch

  pdf:
    image: opendigitaleducation/node-pdf-generator:1.0.0
    ports:
      - "3000:3000"

  neo4j:
    image: neo4j:3.1
    volumes:
      - ./neo4j-conf:/conf

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch-oss:7.9.3
    environment:
      ES_JAVA_OPTS: "-Xms1g -Xmx1g"
      MEM_LIMIT: 1073741824
      discovery.type: single-node
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    cap_add:
      - IPC_LOCK
    ports:
      - "9200:9200"
      - "9300:9300"

  postgres:
    image: postgres:9.5
    environment:
      POSTGRES_PASSWORD: We_1234
      POSTGRES_USER: web-education
      POSTGRES_DB: ong

  mongo:
    image: mongo:3.6

  gradle:
    image: gradle:4.5-alpine
    working_dir: /home/gradle/project
    volumes:
      - ./:/home/gradle/project
      - ~/.m2:/home/gradle/.m2
      - ~/.gradle:/home/gradle/.gradle

  node:
    image: opendigitaleducation/node
    working_dir: /home/node/app
    volumes:
      - ./:/home/node/app
      - ~/.npm:/.npm
      - ../theme-open-ent:/home/node/theme-open-ent
      - ../panda:/home/node/panda
      - ../entcore-css-lib:/home/node/entcore-css-lib
      - ../generic-icons:/home/node/generic-icons
EOL
    echo "Fichier docker-compose.yaml créé."

    # Ajouter les déploiements dans build.gradle
    echo "Ajout des déploiements dans build.gradle..."
    cat <<EOL >> build.gradle

/* 
deployment "fr.openent:competences:\$competencesVersion:deployment"
deployment "fr.openent:presences:\$presencesVersion:deployment"
deployment "fr.cgi:edt:\$edtVersion:deployment"
deployment "fr.openent:incidents:\$incidentsVersion:deployment"
deployment "fr.openent:statistics-presences:\$statisticsPresencesVersion:deployment"
deployment "fr.openent:massmailing:\$massmailingVersion:deployment"
deployment "fr.openent:formulaire:\$formulaireVersion:deployment"
deployment "com.opendigitaleducation:explorer:\$explorerVersion:deployment"
deployment "fr.openent:diary:\$diaryVersion:deployment"
deployment "fr.openent:lool:\$loolVersion:deployment"
*/
EOL
    echo "Déploiements ajoutés dans build.gradle."

    # Modifier l'adresse IP dans conf.properties
    if [ -f "conf.properties" ]; then
        echo "Modification de l'IP dans conf.properties avec l'adresse IP fournie : $SERVER_IP"
        sed -i "s/192.168.99.100/$SERVER_IP/g" conf.properties
    else
        echo "Le fichier conf.properties n'a pas été trouvé."
    fi

    # Exécuter les commandes de build
    echo "Exécution des commandes de build..."
    ./build.sh init || { echo "Erreur lors de l'exécution de ./build.sh init"; exit 1; }
    ./build.sh generateConf || { echo "Erreur lors de l'exécution de ./build.sh generateConf"; exit 1; }
    ./build.sh buildFront || { echo "Erreur lors de l'exécution de ./build.sh buildFront"; exit 1; }
    ./build.sh run || { echo "Erreur lors de l'exécution de ./build.sh run"; exit 1; }

elif [ "$MODE" = "build" ]; then
    echo "Le build n'est pas encore prêt."

else
    echo "Option invalide. Veuillez choisir 'dev' ou 'build'."
fi
