#!/bin/bash
set -e
input=$1
driver_version=$2
tag=$3

if [ -z "$1" -o -z "$2" -o -z "$3" ]; then
    echo 'Usage: automate_opera.sh <browser_version|package_file> <operadriver_version> <tag_version>'
    exit 1
fi
set -x

browser_version=$input
method="opera/blink/apt"
if [ -f "$input" ]; then
    cp "$input" opera/blink/local/opera-stable.deb
    filename=$(echo "$input" | awk -F '/' '{print $NF}')
    browser_version=$(echo $filename | awk -F '_' '{print $2}' | awk -F '+' '{print $1}')
    method="opera/blink/local"
fi

./build-dev.sh $method $browser_version true
if [ "$method" == "opera/blink/apt" ]; then
    ./build-dev.sh $method $browser_version false
fi
pushd opera/blink
../../build.sh operadriver $browser_version $driver_version selenoid/opera:$tag
popd

test_image(){
    docker rm -f selenium || true
    docker run -d --name selenium -p 4444:4444  $1:$2
    tests_dir=../../selenoid-container-tests/
    if [ -d "$tests_dir" ]; then
        pushd "$tests_dir"
        mvn clean test -Dgrid.connection.url="http://localhost:4444/" -Dgrid.browser.name=opera -Dgrid.browser.version=$2 || true
        popd
    else
        echo "Skipping tests as $tests_dir does not exist."
    fi
}

test_image "selenoid/opera" $tag
read -p "Create VNC?" vnc
if [ "$vnc" == "y" ]; then
    pushd vnc/opera/blink
    ../../../build-vnc.sh opera $tag 
    popd
    test_image "selenoid/vnc_opera" $tag
fi

read -p "Push?" yn
if [ "$yn" == "y" ]; then
	docker push "selenoid/dev_opera:"$browser_version
	if [ "$method" == "opera/blink/apt" ]; then
	    docker push "selenoid/dev_opera_full:"$browser_version
    fi
	docker push "selenoid/opera:$tag"
    docker tag "selenoid/opera:$tag" "selenoid/opera:latest"
    docker push "selenoid/opera:latest"
    if [ "$vnc" == "y" ]; then
        docker push "selenoid/vnc:opera_"$tag
        docker push "selenoid/vnc_opera:"$tag
    fi    
fi
