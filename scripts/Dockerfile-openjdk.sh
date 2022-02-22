#!/bin/bash

function pause(){
#   read -p "$*"
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

# A string with command options
options=$@
# An array with all the arguments
arguments=($options)
# Loop index
index=0

for argument in $options
do
# Incrementing index
index=`expr $index + 1`

	# The conditions
	case $argument in
	-majorversion)
		echo "$argument value ${arguments[index]}"
		MAJORVERSION=${arguments[index]}
		;;
	-tag)
		echo "$argument value ${arguments[index]}"
		TAG=${arguments[index]}
		;;
	esac
done

if [ -z $MAJORVERSION ] || [ -z $TAG ];
	then
		#echo "var is unset";
		echo "usage example: ./Dockerfile-openjdk.sh -majorversion 14 -tag jre"
		echo "               ./Dockerfile-openjdk.sh -majorversion 14 -tag jdk"
		exit;
	else
		:
fi

TMP=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1)
NAME=$TAG$MAJORVERSION
IMAGENAME="baseimages/alpine/$NAME"
VERSION='latest'

echo "Building container:"
echo "$IMAGENAME:$VERSION"

cleanup

pause

docker build --file "./Dockerfile-$NAME" -t="$IMAGENAME:$VERSION" .

docker images | grep $IMAGENAME

echo "-----------"
docker run  --rm --entrypoint "" $IMAGENAME:$VERSION /bin/sh -c "cat /etc/os-release; java -version 2>&1; apk info glibc 2> /dev/null;"
echo "-----------"
pause

for i in digitalnonprodregistry.azurecr.io
do

	echo "$i"
	docker tag $IMAGENAME:$VERSION $i/$IMAGENAME:$VERSION
	echo "$i/$IMAGENAME:$VERSION"
	docker push $i/$IMAGENAME:$VERSION

	#VER=$(docker run  --rm --entrypoint "" $i/$IMAGENAME:$VERSION java -version 2>&1 | head -2 | tail -1 | sed 's/[^1234567890\.\+]*//g' | sed 's/\+/_/g');
	VER=$(docker run  --rm --entrypoint "" $i/$IMAGENAME:$VERSION java -version 2>&1 | tail -1 | sed 's/^.*build //g' | sed 's/[^1234567890\.\+]*//g' | sed 's/+/_/g');
	VER="${VER/v}";

	docker tag $i/$IMAGENAME:$VERSION $i/$IMAGENAME:$VER
	echo "$i/$IMAGENAME:$VER"
	docker push $i/$IMAGENAME:$VER

done;

stopping
