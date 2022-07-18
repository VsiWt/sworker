#!/bin/bash

root_dir=`pwd`
github_user=GYZHANG2019
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
    git clone git@github.com:$github_user/ma35_vsi_libs.git -b prototype_production &&

    echo "clone ma35_ffmpeg.git from github..." &&
    git clone git@github.com:$github_user/ma35_ffmpeg.git -b prototype_production &&

    echo "clone ma35_linux_kernel.git from github..." &&
    git clone git@github.com:$github_user/ma35_linux_kernel.git -b prototype_verification &&

    echo "clone ma35.git from github..." &&
    git clone git@github.com:$github_user/ma35.git &&

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
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/common" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "common/.git/hooks/"
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000D" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000D/.git/hooks/"
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000E" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000E/.git/hooks/"
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/vpe" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "vpe/.git/hooks/"
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/transcoding" build -b master && scp -p -P $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "build/.git/hooks/"
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/GAL/driver" VIP2D -b spsd/SuperNova && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VIP2D/.git/hooks/"

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
    cd $root_dir/build/out/$output_pkg_name;
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
    version=$(grep -o '".*"' ma35_vsi_libs/src/vpe/inc/version.h | sed 's/"//g')
    output_pkg_name=cmake_vpe_package_x86_64_linux_$version
    outpath=out/$output_pkg_name
    cd build/

    rm $outpath -rf && mkdir -p $outpath
    cp _deps/ffmpeg-build/ffmpeg $outpath/
    cp _deps/ffmpeg-build/ffprobe $outpath/
    cp _deps/shelf-src/xav1sdk/libxav1sdk.so $outpath/
    cp _deps/vsi_libs-build/src/vpe/src/libvpi.so $outpath/
    cp ../ma35_vsi_libs/src/vpe/build/install.sh $outpath/
    cp ../ma35_vsi_libs/src/vpe/prebuild/libs/x86_64_linux/* $outpath/ -rf
    cp ../ma35_vsi_libs/src/vpe/tools/stest.sh $outpath/ -rf

    cd out
    tar -czf $output_pkg_name.tgz $output_pkg_name/
    remove_rpath
    echo "$output_pkg_name.tgz was generated at `pwd`"
}

function help(){
    echo "this script will pull both AMD gits and/or VSI gits, and do compiling, finally generate test package"
    echo "$0 --github_user=:  set the github account wich contains AMD gits"
    echo "$0 --gerrit_user=:  set the gerrit account wich contains VSI gits"
    echo "$0 new_project:     create one new rmpty project."
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
    --github_user=*)
        echo "github_user=$optarg"
        github_user=$optarg;;
    --gerrit_user=*)
        echo "gerrit_user=$optarg"
        gerrit_user=$optarg;;
    new_project)
        root_dir=$(realpath $(create_folder))
        echo "new project $root_dir had been created";;
    clone_amd_gits)
        clone_amd_gits;;
    clone_vsi_gits)
        clone_vsi_gits;;
    build)
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
