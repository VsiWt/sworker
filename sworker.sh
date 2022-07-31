#!/bin/bash

root_dir=`pwd`
gerrit_user=cn1208
github_user=Xilinx-Projects
amd_vsi_lib_branch=develop
amd_ffmpeg_branch=develop
amd_drivers_branch=develop
amd_shelf_branch=develop
amd_ma35_branch=develop
amd_gits_mirror=y
include_sdk=n

set -o pipefail
function create_folder(){
    folder=fork_`date "+%m%d%H%M"`
    mkdir $folder &&
    cd $folder &&
    ln -s ../$0 . &&
    echo $folder
}

function clone_amd_gits(){
    cd $root_dir;

    rm ma35_* -rf

    if [[ "$amd_gits_mirror" == "y" ]]; then
        echo "clone ma35_vsi_libs.git from mirror github..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_vsi_libs" -b $amd_vsi_lib_branch

        echo "clone ma35_ffmpeg.git from mirror github..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_ffmpeg" -b $amd_ffmpeg_branch

        echo "clone ma35_linux_kernel.git from mirror github..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_linux_kernel" -b $amd_drivers_branch

        echo "clone ma35.git from mirror github..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35" -b $amd_ma35_branch

        echo "clone shelf.git from mirror github..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_shelf" -b $amd_shelf_branch
    else
        echo "clone ma35_vsi_libs.git from github..."
        git clone git@github.com:$github_user/ma35_vsi_libs.git -b $amd_vsi_lib_branch

        echo "clone ma35_ffmpeg.git from github..."
        git clone git@github.com:$github_user/ma35_ffmpeg.git -b $amd_ffmpeg_branch

        echo "clone ma35_linux_kernel.git from github..."
        git clone git@github.com:$github_user/ma35_linux_kernel.git -b $amd_drivers_branch

        echo "clone ma35.git from github..."
        git clone git@github.com:$github_user/ma35.git -b $amd_ma35_branch

        echo "clone shelf.git from github..."
        git clone git@github.com:$github_user/ma35_shelf.git -b $amd_shelf_branch
    fi

    echo -e "done"
}

function clone_vsi_gits(){

    echo "clone ffmpeg from VSI gerrit..."
    cd $root_dir;
    cd ma35_ffmpeg/ && rm src -rf
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/ffmpeg/ffmpeg" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/"
    echo -e "done"

    echo "clone drivers from VSI gerrit..."
    cd $root_dir
    cd ma35_linux_kernel/ && rm src -rf
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/drivers" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/"
    echo -e "done"

    cd $root_dir
    cd ma35_vsi_libs/src
    rm vpe common VC8000D VC8000E build VIP2D drivers -rf
    echo "clone vsi libs from VSI gerrit..."
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/vpe" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "vpe/.git/hooks/"
    if [ "$include_sdk" == "y" ]; then
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/common" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "common/.git/hooks/"
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000D" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000D/.git/hooks/"
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000E" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000E/.git/hooks/"
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/transcoding" build -b master && scp -p -P $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "build/.git/hooks/"
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/GAL/driver" VIP2D -b spsd/SuperNova && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VIP2D/.git/hooks/"
    fi
    echo "Link ffmpeg from ma35_ffmpeg to ma35_vsi_libs/src/ffmpeg"
    cd $root_dir
    cd ma35_vsi_libs/src/
    ln -s ../../ma35_ffmpeg/src/ ffmpeg

    echo "Link driver from ma35_linux_kernel to ma35_vsi_libs/src/drivers"
    ln -s ../../ma35_linux_kernel/src/ drivers
}

function build(){
    echo "Building full project with CMake..."
    cd $root_dir
    if [ ! -d build ]; then
        mkdir build
    fi
    cd build
    cmake ../ma35 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DMA35_FORCE_NO_PRIVATE_REPOS=true -DREPO_USE_LOCAL_shelf=true -DREPO_USE_LOCAL_vsi_libs=true -DREPO_USE_LOCAL_linux_kernel=true -DREPO_USE_LOCAL_ffmpeg=true
    ninja ffmpeg_vsi sn_int
    echo -e "done"
}

function remove_rpath(){
    cd $root_dir/build/out/$output_pkg_name;
    libs=(GAL OpenVX xabrsdk common VSC ArchModelSw NNArchPerf h2enc g2dec common.so cache)
    for lib in libs; do
        patchelf --remove-needed lib$lib.so libvpi.so
    done
    cd -
    echo "rpath in libvpi.so had been removed"
}

function package(){
    cd $root_dir;
    version=$(grep -o '".*"' ma35_vsi_libs/src/vpe/inc/version.h | sed 's/"//g')
    output_pkg_name=cmake_vpe_package_x86_64_linux_$version
    outpath=out/$output_pkg_name
    cd build/

    rm $outpath -rf && mkdir -p $outpath
    ## copy libs
    cp ../ma35_vsi_libs/src/vpe/prebuild/libs/x86_64_linux/* $outpath/ -rf
    cp _deps/ffmpeg-build/ffmpeg $outpath/
    cp _deps/ffmpeg-build/ffprobe $outpath/
    cp _deps/vsi_libs-build/sdk/xabr/libxabrsdk.so $outpath/
    cp _deps/vsi_libs-build/src/vpe/src/libvpi.so $outpath/
    cp _deps/sn_int_ext-build/lib/libsn_int.so $outpath/
    cp ../ma35_shelf/xav1sdk/libxav1sdk.so $outpath/
    if [ ! -d "$outpath/cmodel/" ]; then
        mkdir $outpath/cmodel/
    fi

    ## copy cmodel related
    cp ../ma35_shelf/ma35_sn_int/libxabr_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libvc8000d_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libxav1_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libvc8000e_sim.so $outpath/cmodel/
    cp ../ma35_shelf/host_device_algo/libhost_device_algo.so $outpath/

    ## copy drivers
    mv ../ma35_linux_kernel/src ../ma35_linux_kernel/drivers
    mv ../ma35_linux_kernel/drivers/.git ../ma35_linux_kernel/vsi.git
    cd ../ma35_linux_kernel/ && tar -czf ../build/$outpath/drivers.tgz drivers && cd -
    mv ../ma35_linux_kernel/vsi.git ../ma35_linux_kernel/drivers/.git
    mv ../ma35_linux_kernel/drivers ../ma35_linux_kernel/src

    ## copy scripts
    cp ../ma35_vsi_libs/src/vpe/build/install.sh $outpath/
    cp ../ma35_vsi_libs/src/vpe/tools/stest.sh $outpath/

    cd out
    remove_rpath
    tar -czf $output_pkg_name.tgz $output_pkg_name/
    echo "$output_pkg_name.tgz was generated at `pwd`"
}

function help(){
    echo "this script will pull both AMD gits and/or VSI gits, and do compiling, finally generate test package"
    echo "$0 --amd_gits_mirror=:        y/n, whether enable the gits mirror.[$amd_gits_mirror] "
    echo "$0 --gerrit_user=:            set the gerrit account wich contains VSI gits.[$gerrit_user]"
    echo "$0 --github_user=:            set the github account wich contains AMD gits.[$github_user]"
    echo "$0 --amd_vsi_lib_branch=:     set the AMD gits vsi_lib branch name.[$amd_vsi_lib_branch]"
    echo "$0 --amd_ffmpeg_branch=:      set the AMD gits ffmpeg branch name.[$amd_ffmpeg_branch]"
    echo "$0 --amd_drivers_branch=:     set the AMD gits drivers branch name.[$amd_drivers_branch]"
    echo "$0 --amd_ma35_branch=:        set the AMD gits ma35 branch name.[$amd_ma35_branch]"
    echo "$0 --amd_shelf_branch=:       set the AMD gits shelf branch name.[$amd_shelf_branch]"
    echo "$0 --include_sdk=:            y/n: whether clone VSI SDK code.[$include_sdk]"
    echo "$0 new_project:               create one new rmpty project."
    echo "$0 clone_amd_gits:            clone AMD gits only."
    echo "$0 clone_vsi_gits:            clone VSI gits only"
    echo "$0 build:                     do full build"
    echo "$0 package:                   package all requied files"
}

for (( i=1; i <=$#; i++ )); do
    opt=${!i}
    optarg="${opt#*=}"
    next_opt=$((i+1))
    next_value=${!next_opt}
    case "$opt" in
    --amd_gits_mirror=*)
        echo "amd_gits_mirror=$optarg"
        amd_gits_mirror=$optarg;;
    --gerrit_user=*)
        echo "gerrit_user=$optarg"
        gerrit_user=$optarg;;
    --github_user=*)
        echo "github_user=$optarg"
        github_user=$optarg;;
    --amd_vsi_lib_branch=*)
        echo "amd_vsi_lib_branch=$optarg"
        amd_vsi_lib_branch=$optarg;;
    --amd_ffmpeg_branch=*)
        echo "amd_ffmpeg_branch=$optarg"
        amd_ffmpeg_branch=$optarg;;
    --amd_drivers_branch=*)
        echo "amd_drivers_branch=$optarg"
        amd_drivers_branch=$optarg;;
    --amd_ma35_branch=*)
        echo "amd_ma35_branch=$optarg"
        amd_ma35_branch=$optarg;;
    --amd_shelf_branch=*)
        echo "amd_shelf_branch=$optarg"
        amd_shelf_branch=$optarg;;
    --include_sdk=*)
        echo "include_sdk=$optarg"
        include_sdk=$optarg;;
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
