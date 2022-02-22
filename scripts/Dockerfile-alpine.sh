#!/bin/bash

function pause(){
   echo 'Press [Enter] key to continue... '
   read -p "Pause Time 5 seconds...  " -t 5
   read -p "Continuing in 5 Seconds...  " -t 5
   echo "Continuing...  "
}

function cleanup(){
   stopping
   echo "removing..."
   docker ps -a | grep -v CONTAINER |cut -d ' ' -f 1 | xargs docker rm
   while [ ! $(docker images --filter 'dangling=true' -q --no-trunc | grep -c '^') -eq 0 ]
   do
      docker rmi -f $(docker images --filter 'dangling=true' -q --no-trunc)
   done
}

function stopping(){
   echo "stopping..."
   docker ps -a | grep -v CONTAINER |cut -d ' ' -f 1 | xargs docker stop
}

TMP=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
NAME='current'
IMAGENAME="baseimages/alpine/$NAME"
VERSION='latest'

echo "Building container:"
echo "$IMAGENAME:$VERSION"

cleanup

pause

docker build --file "./Dockerfile-alpine" -t="$IMAGENAME:$VERSION" .

docker images | grep $IMAGENAME

#docker run -d -P --name $TMP $IMAGENAME:$VERSION

#docker port $TMP

#docker exec -it $TMP /bin/sh

#docker logs -t $TMP
echo "-----------"
docker run  --rm --entrypoint "" $IMAGENAME:$VERSION /bin/sh -c "cat /etc/os-release;"
echo "-----------"
pause

#for i in nonprodregistry.azurecr.io wagdigital.azurecr.io wagdigitaldotcomprod.azurecr.io
for i in digitalnonprodregistry.azurecr.io
do
   echo "$i"
   docker tag $IMAGENAME:$VERSION $i/$IMAGENAME:$VERSION
   echo "$i/$IMAGENAME:$VERSION"
   docker push $i/$IMAGENAME:$VERSION

   ALPINE_VER=$(docker run  --rm --entrypoint "" $i/$IMAGENAME:$VERSION cat /etc/alpine-release);
   ALPINE_VER="$ALPINE_VER-$(date '+%Y.%m.%d')";

   docker tag $i/$IMAGENAME:$VERSION $i/$IMAGENAME:$ALPINE_VER
   echo "$i/$IMAGENAME:$ALPINE_VER"
   docker push $i/$IMAGENAME:$ALPINE_VER
done;

stopping
