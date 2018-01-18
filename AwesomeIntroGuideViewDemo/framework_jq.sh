#!/bin/sh

function cloneRepo() {
    if [[ -n $1 ]]; then
        if [[ -n $2 ]]; then
            git clone $1 --branch $2
        else
            git clone $1 --master   
        fi
    fi
    cd $WORKSPACE/$repoName
    ls|egrep "\w+-\d+"|xargs rm -rf
}

function changeTag() {
    cd $WORKSPACE/$repoName
    find ./ -type d|grep 'Pods'|xargs rm -rf
    jsonpodspec=`find ./ -type f|grep ".podspec.json" |tail -n 1| awk  -F './/'  '{print $2}'`
    
    if [[ ! -f $jsonpodspec ]]
    then
        jsonpodspec=`find ./ -type f|grep ".podspec" |tail -n 1| awk  -F './/'  '{print $2}'`
        if [[ ! -f $jsonpodspec ]]
        then
        exit 0
        fi
        pod ipc spec $jsonpodspec >> $jsonpodspec.json
        rm -rf $jsonpodspec
        jsonpodspec=$jsonpodspec.json
    fi
    
    json=`jq 'delpaths([["source","commit"]])' $jsonpodspec`
    echo $json > $jsonpodspec

    json=`jq 'delpaths([["source","tag"]])' $jsonpodspec`
    echo $json > $jsonpodspec

    ttag=$2
    commit=`git rev-parse --short HEAD`

    json=`jq -r --arg repo "$repo"  'setpath(["source","git"];$repo)' $jsonpodspec`
    echo $json > $jsonpodspec
    json=`jq -r --arg commit "$commit"  'setpath(["source","commit"];$commit)' $jsonpodspec`
    echo $json > $jsonpodspec
    json=`jq -r --arg ttag "$ttag"  'setpath(["version"];$ttag)' $jsonpodspec`
    echo $json > $jsonpodspec
}

function framework() {
    if [[ -d $WORKSPACE ]]; then
        cd $WORKSPACE/$repoName
        find ./ -type d|grep ".framework"|xargs rm  -rf
    fi
    
    podspecjson=`find ./ -type f|grep ".podspec.json" |head -n 1| awk  -F './/'  '{print $2}'`
    if [[ -f $podspecjson ]]
    then
        if [[ $1 == "dynamic" ]]
        then
        pod package *.podspec.json --force --dynamic --spec-sources=https://git.oschina.net/ambitious/SLBSource.git,https://github.com/CocoaPods/Specs.git
        else
        pod package *.podspec.json --force --no-mangle  --spec-sources=https://git.oschina.net/ambitious/SLBSource.git,https://github.com/CocoaPods/Specs.git
        fi
        if [ $? -ne 0 ]
        then
            exit 1
        fi
        framework=`find ./ -type d|grep $2".framework" |head -n 1`
        cp -r $framework $2".framework"
        ls|egrep "\w+-\d+"|xargs rm -rf 
        changeTag $repoName $version".1" $3 $repo
        json=`jq 'del(.source_files)' $podspecjson`
        echo $json > $podspecjson
        json=`jq 'setpath(["ios","vendored_frameworks"];"*.framework")' $podspecjson`
        echo $json > $jsonpodspec
        # jq 'setpath(["ios","vendored_frameworks"];"*.framework")' *.podspec.json
        handlesubspec
        handlezip
        json=`jq 'delpaths([["source","commit"]])' $podspecjson`
        echo $json > $podspecjson
        json=`jq 'delpaths([["source","git"]])' $podspecjson`
        echo $json > $podspecjson
        http="https://gitee.com/ambitious/Frameworks/raw/master/""$repoName""/""$version"".1""/""$repoName.framework.zip"
        json=`jq -r --arg http "$http"  'setpath(["source","http"];$http)' $podspecjson`
        echo $json > $podspecjson
        json=`jq 'del(.subspecs)' $podspecjson`
        echo $json > $podspecjson
        json=`jq 'del(.default_subspecs)' $podspecjson`
        echo $json > $podspecjson
    fi
}

function handlesubspec(){
    #目前先不考虑subsec
    jq 'del(.subspecs)' *.podspec.json
}

function handlezip(){
    zip -r $repoName.framework.zip *.framework
    dir=`pwd`
    cd $frameworksdir
    if [[ -d $repoName ]]; then
        cd $repoName
        if [[ -d $version".1" ]]; then
            cd $version".1"
        else
            mkdir $version".1" 
            cd $version".1"   
        fi
    else 
        mkdir $repoName
        cd $repoName
        if [[ -d $version".1" ]]; then
            cd $version".1"
        else
            mkdir $version".1"  
            cd $version".1"  
        fi
    fi
    mv $dir/$repoName.framework.zip ./
    git add .
    git commit -m "update"" $repoName"" version:""$version"".1"
    git push origin $3
    if [ $? -ne 0 ]
    then
    exit 1
    fi
    cd $dir

}

function push() {
    cd $WORKSPACE/$repoName
    podspec=`find ./ -type f|grep ".podspec.json" |tail -n 1| awk  -F './/'  '{print $2}'`
    # echo $podspec
    pods="oschina-ambitious-slbsource"
    pod repo push $pods $podspec --allow-warnings --use-libraries --sources=https://git.oschina.net/ambitious/SLBSource.git,master --verbose
}

repo="https://github.com/Bupterambition/AwesomeIntroGuideView.git"
version="1.0.10"
branch="master"
tp="static"
WORKSPACE=`pwd`
repoName="AwesomeIntroGuideView"
frameworksdir="/Users/soulkiller/Documents/Frameworks"
rm -rf $repoName

cloneRepo $repo $branch

changeTag $repoName $version $branch $repo

framework $tp $repoName $branch

push
