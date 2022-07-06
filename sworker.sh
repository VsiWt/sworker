#!/bin/bash

root_dir=`pwd`
github_repo=GYZHANG2019
gerrit_user=cn1208

function create_folder(){
    folder=fork_`date "+%m%d%H%M"`
    mkdir $folder &&
    cd $folder &&
    ln -s ../$0 . &&
    echo $folder
}

function clone_amd_gits(){
    cd $root_dir;

    rm ma35_vsi_libs ma35_ffmpeg ma35_linux_kernel ma35 -rf
    echo "clone ma35_vsi_libs.git from github..." &&
    git clone git@github.com:$github_repo/ma35_vsi_libs.git -b prototype_production &&

    echo "clone ma35_ffmpeg.git from github..." &&
    git clone git@github.com:$github_repo/ma35_ffmpeg.git -b prototype_production &&

    echo "clone ma35_linux_kernel.git from github..." &&
    git clone git@github.com:$github_repo/ma35_linux_kernel.git -b prototype_verification &&

    echo "clone ma35.git from github..." &&
    git clone git@github.com:$github_repo/ma35.git &&

    echo -e "done"
}

function clone_vsi_gits(){

    echo "clone ffmpeg from VSI gerrit..."
    cd $root_dir;
    cd ma35_ffmpeg/ && rm src -rf &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/ffmpeg/ffmpeg" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/" &&
    echo -e "done" &&

    echo "clone drivers from VSI gerrit..." &&
    cd $root_dir &&
    cd ma35_linux_kernel/ && rm src -rf &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/drivers" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/" &&
    echo -e "done" &&

    cd $root_dir &&
    cd ma35_vsi_libs/src &&
    rm vpe common VC8000D VC8000E build VIP2D drivers -rf &&
    echo "clone vsi libs from VSI gerrit..." &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/common" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "common/.git/hooks/" &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000D" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000D/.git/hooks/" &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000E" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000E/.git/hooks/" &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/vpe" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "vpe/.git/hooks/" &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/transcoding" build -b master && scp -p -P $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "build/.git/hooks/" &&
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/GAL/driver" VIP2D -b spsd/SuperNova && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VIP2D/.git/hooks/" &&

    echo "Link ffmpeg from ma35_ffmpeg to ma35_vsi_libs/src/ffmpeg" &&
    cd $root_dir &&
    cd ma35_vsi_libs/src/ &&
    ln -s ../../ma35_ffmpeg/src/ ffmpeg &&

    echo "Link driver from ma35_linux_kernel to ma35_vsi_libs/src/drivers" &&
    ln -s ../../ma35_linux_kernel/src/ drivers
}

function build(){
    echo "Building full project with CMake..."
    cd $root_dir  &&
    rm build -rf && mkdir build && cd build &&
    cmake ../ma35 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DMA35_FORCE_NO_PRIVATE_REPOS=true -DREPO_USE_LOCAL_vsi_libs=true -DREPO_USE_LOCAL_linux_kernel=true -DREPO_USE_LOCAL_ffmpeg=true &&
    ninja ffmpeg_vsi sn_int &&
    echo -e "done"
}

function remove_rpath(){
    cd $root_dir/package;
    path=$(ldd libvpi.so | grep "x86_64_linux/libh2enc.so" |  awk '{print $1}')
    patchelf --remove-needed $path libvpi.so

    path=$(ldd libvpi.so | grep "x86_64_linux/libg2dec.so" |  awk '{print $1}')
    patchelf --remove-needed $path libvpi.so

    path=$(ldd libvpi.so | grep "x86_64_linux/libcommon.so" |  awk '{print $1}')
    patchelf --remove-needed $path libvpi.so

    patchelf --remove-rpath $path libvpi.so

    echo "rpath in libvpi.so had been removed"
}

function package(){
    cd $root_dir;
    rm package -rf && mkdir package
    cp build/_deps/ffmpeg-build/ffmpeg package/
    cp build/_deps/ffmpeg-build/ffprobe package/
    cp build/_deps/shelf-src/xav1sdk/libxav1sdk.so package/
    cp build/_deps/vsi_libs-build/src/vpe/src/libvpi.so package/
    cp ma35_vsi_libs/src/vpe/build/install.sh package/
    cp ma35_vsi_libs/src/vpe/prebuild/libs/x86_64_linux/* package/ -rf
    cp ma35_vsi_libs/src/vpe/tools/stest.sh package/ -rf

    remove_rpath
    echo "package was generated"
}

function help(){
    echo "this script will pull both AMD gits and/or VSI gits, and do compiling, finally generate test package"
    echo "$0 --github_repo=:  set the github repo name for AMD gits"
    echo "$0 --gerrit_user=:  set VSI gerrit user account"
    echo "$0 new_amd:         Pull AMD build environment, and fetch AMD gits， and build it."
    echo "$0 new_vsi:         Pull AMD build environment, and fetch VSI gits， and build it."
    echo "$0 clone_amd_gits:  clone AMD gits only."
    echo "$0 clone_vsi_gits:  clone VSI gits only"
    echo "$0 build:           do full build"
    echo "$0 package:         package all requied files"
}

for (( i=1; i <=$#; i++ )); do
    opt=${!i}
    optarg="${opt#*=}"
    next_opt=$((i+1))
    next_value=${!next_opt}
    case "$opt" in
    --github_repo=*)
        echo "github_repo=$optarg"
        github_repo=$optarg;;
    --gerrit_user=*)
        echo "gerrit_user=$optarg"
        gerrit_user=$optarg;;
    new_amd)
        echo "clone pure AMD gits and build"
        root_dir=$(realpath $(create_folder));
        clone_amd_gits && build && package;
        exit 1;;
    new_vsi)
        echo "clone AMD gits and VSI gits, and build"
        root_dir=$(realpath $(create_folder));
        clone_amd_gits && clone_vsi_gits && build && package;
        exit 1;;
    clone_amd_gits)
        echo "clone AMD gits"
        clone_amd_gits;;
    clone_vsi_gits)
        echo "clone VSI gits"
        clone_vsi_gits;;
    build)
        echo "Start build..."
        build;;
    package)
        package;;
    --help|help)
        help ;
        exit 1;;
    *)
        echo "invalid input $optarg";
        help;
        exit 1;
        ;;
	esac
done
