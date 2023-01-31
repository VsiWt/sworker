#!/bin/bash

root_dir=`pwd`
gerrit_user=cn1208
github_user=GYZHANG2019
ma35_vsi_libs_branch=develop
ma35_ffmpeg_branch=develop
ma35_linux_kernel_branch=develop
ma35_osal_branch=develop
ma35_zsp_firmware_branch=develop
ma35_shelf_branch=develop
ma35_branch=develop
amd_gits_mirror=y
include_sdk=y

repos=(ma35_vsi_libs ma35_ffmpeg ma35_linux_kernel ma35 ma35_osal ma35_zsp_firmware ma35_shelf)

function create_folder(){
    folder=fork_`date "+%m%d%H%M"`
    mkdir $folder &&
    cd $folder &&
    ln -s ../$0 . &&
    echo $folder
}

function clone_amd_gits(){
    cd $root_dir;
    rm ma35* build -rf
    idx=1
    for repo in ${repos[@]}; do
        branch=$repo"_branch"
        branch=`eval echo '$'"$branch"`
        if [[ "$amd_gits_mirror" == "y" ]]; then
            git="ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/$repo"
        else
            git="git@github.com:$github_user/$repo.git"
        fi
        echo -e "\n$idx. clone $git...$branch"
        git clone "$git" -b $branch
        if (( $? != 0 )); then
            echo "git clone $git failed"
            exit 1
        fi
        idx=$((idx+1))
    done
    echo "clone_amd_gits done"
}

function sync_fork(){
    cd $root_dir;
    idx=1
    for repo in ${repos[@]}; do
        cd $repo
        if (( $? != 0 )); then
            echo "repo $repo is not exist"
            exit 1
        fi
        str=$(git remote -v | grep "fetch")
        str=${str##*:}
        user=${str%%/*}
        branch=$repo"_branch"
        branch=`eval echo '$'"$branch"`
        echo -e "\n$idx. sync AMD $repo..."
        if [[ "$(git remote -v | grep "gerrit")" == "" ]]; then
            gh repo sync -b $branch --force $user/$repo
            if (( $? != 0 )); then
                echo "gh repo sync failed"
                exit 1
            fi
            echo "$user/$repo had been synced"
        else
            echo "$repo is not a fork, skip"
        fi
        idx=$((idx+1))
        cd ..
    done
    echo "fetch_amd_gits done"
}

function fetch_amd_gits(){
    cd $root_dir;
    idx=1
    for repo in ${repos[@]}; do
        cd $repo
        branch=$repo"_branch"
        branch=`eval echo '$'"$branch"`
        echo -e "\n$idx. updating AMD $repo..."
        git config pull.rebase false
        git reset --hard && git pull origin $branch
        idx=$((idx+1))
        cd ..
    done
    echo "fetch_amd_gits done"
}

function fetch_vsi_gits(){
    cd $root_dir;
    idx=1

    local mirrow_repos=(ma35_vsi_libs ma35_ffmpeg ma35_linux_kernel ma35_osal)
    for repo in ${mirrow_repos[@]}; do
        cd $repo/src
        if (( $? != 0 )); then
            echo "folder $repo/src is not exist"
            exit 1
        fi
        branch=$repo"_branch"
        branch=`eval echo '$'"$branch"`
        echo -e "\n$idx. updating VSI $repo..."
        git config pull.rebase false
        git reset --hard
        git pull origin $branch
        idx=$((idx+1))
        cd -
    done

    echo "$idx. updating VSI ma35_zsp_firmware..."
    cd ../../ma35_zsp_firmware/firmware
    git config pull.rebase false
    git reset --hard
    git pull origin $ma35_zsp_firmware_branch
    cd -
    echo "fetch_vsi_gits done"
}

function push_to_amd_gits(){
    cd $root_dir;
    idx=1

    for repo in ${repos[@]}; do
        branch=$repo"_branch"
        branch=`eval echo '$'"$branch"`
        echo -e "\n$idx. pusing $repo..."
        cd $repo
        if [[ "$(git remote -v | grep "gerrit")" == "" ]]; then
            git add .
            git commit -m "integration $date"
            git push origin $branch -f
        else
            echo "Can't push anything to mirrow"
        fi
        idx=$((idx+1))
        cd -
    done
    echo "push_to_amd_gits done"
}

function clone_vsi_gits(){

    gits=($@)
    if [[ "$gits" == "" ]]; then
        gits=(ffmpeg vpe osal build common VC8000D VC8000E VIP2D drivers firmware)
    fi

    echo "Will clone VSI gits: ${gits[@]}"

    if [[ "${gits[@]}" =~ "ffmpeg" ]];then
        echo "clone ffmpeg from VSI gerrit..."
        cd $root_dir/ma35_ffmpeg/ && rm src -rf
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/ffmpeg/ffmpeg" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/"
    fi

    if [[ "${gits[@]}" =~ "drivers" ]];then
        echo "clone drivers from VSI gerrit..."
        cd $root_dir/ma35_linux_kernel/ && rm src -rf
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/drivers" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/"
    fi

    if [[ "${gits[@]}" =~ "osal" ]];then
        echo "clone osal from VSI gerrit..."
        cd $root_dir/ma35_osal/ && rm src -rf
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_osal" src -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "src/.git/hooks/"
    fi

    if [[ "${gits[@]}" =~ "firmware" ]];then
        echo "clone firmware from VSI gerrit..."
        cd $root_dir/ma35_zsp_firmware/ && rm firmware -rf
        git clone "ssh://cn1208@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/Firmware" firmware -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "firmware/.git/hooks/"
    fi

    if [[ "${gits[@]}" =~ "vpe" ]];then
        echo "clone vpe from VSI gerrit..."
        cd $root_dir/ma35_vsi_libs/src && rm vpe -rf
        echo "clone vsi libs from VSI gerrit..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/vpe" vpe -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "vpe/.git/hooks/"
    fi

    if [ "$include_sdk" == "y" ]; then
        cd $root_dir/ma35_vsi_libs/sdk
        if [[  "${gits[@]}" =~ "common" ]];then
            rm common -rf
            git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/common" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "common/.git/hooks/"
        fi

        if [[ "${gits[@]}" =~ "VC8000D" ]];then
            rm VC8000D -rf
            git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000D" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000D/.git/hooks/"
        fi

        if [[ "${gits[@]}" =~ "VC8000E" ]];then
            rm VC8000E -rf
            git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/VC8000E" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VC8000E/.git/hooks/"
        fi

        if [[ "${gits[@]}" =~ "build" ]];then
            rm build -rf
            git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/transcoding" build -b master && scp -p -P $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "build/.git/hooks/"
        fi

        if [[ "${gits[@]}" =~ "VIP2D" ]];then
            rm VIP2D -rf
            git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/GAL/driver" VIP2D -b spsd/SuperNova && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VIP2D/.git/hooks/"
        fi
    fi
    echo "clone_vsi_gits ${gits} done"
}

function gen_vsi_codebase(){

    rm vpe2 -rf
    mkdir vpe2 && cd vpe2

    gits=(ffmpeg/ffmpeg gitlab/Transcoder/drivers github/Xilinx-Projects/ma35_osal gitlab/Transcoder/Firmware VSI/SDK/vpe gitlab/Transcoder/common gitlab/Transcoder/VC8000D gitlab/Transcoder/VC8000E)

    for git in ${gits[@]}; do
        echo "clone $git..."
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/$git" -b spsd/master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "${git##*/}/.git/hooks/"
    done

    mv ma35_osal osal
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/GAL/driver" VIP2D -b spsd/SuperNova	&& scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "VIP2D/.git/hooks/"

    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/transcoding" build -b master && scp -p -P 29418 $gerrit_user@gerrit-spsd.verisilicon.com:hooks/commit-msg "build/.git/hooks/"

    cd build
    ./build_all.sh

    echo "gen_vsi_codebase done"
}

function build(){
    echo "Building full project with CMake..."
    cd $root_dir
    if [ ! -d build ]; then
        mkdir build
    fi
    cd build
    cmake ../ma35 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DMA35_FORCE_NO_PRIVATE_REPOS=true -DREPO_USE_LOCAL_shelf=true -DREPO_USE_LOCAL_vsi_libs=true -DREPO_USE_LOCAL_linux_kernel=true -DREPO_USE_LOCAL_osal=true -DREPO_USE_LOCAL_ffmpeg=true -DREPO_USE_LOCAL_zsp_firmware=true -DREPO_USE_LOCAL_shelf=true  -DMA35_BUILD_KERNEL_OSAL=false -DREPO_BUILD_TESTS_vsi_libs=true
    ninja ffmpeg_vsi sn_int 
    ninja zsp_firmware
    ninja srmtool
}

function remove_rpath(){
    cd $root_dir/build/out/$output_pkg_name;
    libs=(GAL OpenVX xabrsdk common VSC ArchModelSw NNArchPerf h2enc g2dec cache)
    for lib in ${libs[@]}; do
        patchelf --remove-needed _deps/vsi_libs-build/src/vpe/prebuild/lib$lib.so libvpi.so
        patchelf --remove-needed lib$lib.so libvpi.so
        patchelf --add-needed lib$lib.so ./ffmpeg
        patchelf --add-needed lib$lib.so ./ffprobe
    done
    cd -
}

function package(){
    cd $root_dir;
    version=$(grep -o '".*"' ma35_vsi_libs/src/vpe/inc/version.h | sed 's/"//g')
    output_pkg_name=cmake_vpe_package_x86_64_linux_$version
    outpath=out/$output_pkg_name
    cd build/

    rm $outpath -rf && mkdir -p $outpath
    mkdir $outpath/cmodel/
    mkdir $outpath/firmware/
    mkdir $outpath/JSON/asic/ -p
    mkdir $outpath/JSON/fpga/ -p

    ## copy libs
    cp ../ma35_vsi_libs/src/vpe/prebuild/libs/x86_64_linux/* $outpath/ -rf
    cp _deps/ffmpeg-build/ffmpeg $outpath/
    cp _deps/ffmpeg-build/ffprobe $outpath/
    cp _deps/vsi_libs-build/src/vpe/tools/srmtool $outpath/
    cp _deps/vsi_libs-build/sdk/xabr/libxabrsdk.so $outpath/
    cp _deps/vsi_libs-build/src/vpe/src/libvpi.so $outpath/
    cp _deps/sn_int_ext-build/lib/libsn_int.so $outpath/
    cp ../ma35_shelf/xav1sdk/libxav1sdk.so $outpath/

    ## copy firmware
    cp ../ma35_shelf/firmware_platform/* $outpath/firmware/
    cp _deps/zsp_firmware-build/zsp_firmware_packed.bin $outpath/firmware/supernova_zsp_fw_evb.bin -rf
    #cp ../ma35_vsi_libs/src/vpe/prebuild/firmware/supernova_zsp_fw_evb.bin $outpath/firmware/supernova_zsp_fw_evb.bin -rf

    ## copy cmodel related
    cp ../ma35_shelf/ma35_sn_int/libxabr_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libvc8000d_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libxav1_sim.so $outpath/cmodel/
    cp ../ma35_shelf/ma35_sn_int/libvc8000e_sim.so $outpath/cmodel/
    cp ../ma35_shelf/host_device_algo/libhost_device_algo.so $outpath/

    ## copy drivers
    mv ../ma35_linux_kernel/src ../ma35_linux_kernel/drivers
    mv ../ma35_linux_kernel/drivers/.git ../ma35_linux_kernel/drivers/vsi.git
    cd ../ma35_linux_kernel/ && tar -czf ../build/$outpath/drivers.tgz drivers && cd -
    mv ../ma35_linux_kernel/drivers/vsi.git ../ma35_linux_kernel/drivers/.git
    mv ../ma35_linux_kernel/drivers ../ma35_linux_kernel/src

    ## copy scripts
    cp ../ma35_vsi_libs/src/vpe/build/install.sh $outpath/
    cp ../ma35_vsi_libs/src/vpe/tools/*.sh $outpath/

    # copy model files
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/yolo_v2.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/mobilenet_v1.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/bodypix.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/resnet_50.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/cae_cc.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/asic_nbg/cae_cxc.nb" -P $outpath/JSON/asic/
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/yolo_v2.nb" -P $outpath/JSON/fpga
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/mobilenet_v1.nb" -P $outpath/JSON/fpga
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/bodypix.nb" -P $outpath/JSON/fpga
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/resnet_50.nb" -P $outpath/JSON/fpga
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/cae_cc.nb" -P $outpath/JSON/fpga
    wget "https://coding-app1.verisilicon.com/resource/Transcoding/stream/JSON/fpga_nbg/cae_cxc.nb" -P $outpath/JSON/fpga

    cd out
    remove_rpath
    tar -czf $output_pkg_name.tgz $output_pkg_name/
    echo "$output_pkg_name.tgz was generated at `pwd`"
}

function help(){
    echo "this script will pull both AMD gits and/or VSI gits, and do compiling, finally generate test package"
    echo "$0 --amd_gits_mirror=:            y/n, whether enable the gits mirror.[$amd_gits_mirror] "
    echo "$0 --gerrit_user=:                set the gerrit account wich contains VSI gits.[$gerrit_user]"
    echo "$0 --github_user=:                set the github account wich contains AMD gits.[$github_user]"
    echo "$0 --include_sdk=:                y/n: whether clone VSI SDK code.[$include_sdk]"
    echo "$0 --ma35_vsi_libs_branch=:       set the AMD gits vsi_lib branch name.[$ma35_vsi_libs_branch]"
    echo "$0 --ma35_ffmpeg_branch=:         set the AMD gits ffmpeg branch name.[$ma35_ffmpeg_branch]"
    echo "$0 --ma35_linux_kernel_branch=:   set the AMD gits drivers branch name.[$ma35_linux_kernel_branch]"
    echo "$0 --ma35_osal_branch=:           set the AMD gits drivers branch name.[$ma35_osal_branch]"
    echo "$0 --ma35_zsp_firmware_branch=:   set the AMD gits drivers branch name.[$ma35_zsp_firmware_branch]"
    echo "$0 --ma35_branch=:                set the AMD gits ma35 branch name.[$ma35_branch]"
    echo "$0 --ma35_shelf_branch=:          set the AMD gits shelf branch name.[$ma35_shelf_branch]"
    echo "$0 new_project:                   create one new rmpty project."
    echo "$0 sync_fork:                     sync forked gits to owner."
    echo "$0 clone_amd_gits:                remove orignal AMD git, clone a new AMD gits."
    echo "$0 clone_vsi_gits [git][git]...:  remove orignal VSI git, clone a new VSI gits. gits can be or more of [ffmpeg vpe osal build common VC8000D VC8000E VIP2D drivers firmware]"
    echo "$0 fetch_amd_gits:                reset all local changes, and fetch AMD fork"
    echo "$0 fetch_vsi_gits:                fetch all changes in VSI gits, and fetch VSI gits"
    echo "$0 push_to_amd_gits:              push to AMD gits"
    echo "$0 build:                         do full build"
    echo "$0 gen_merge_codebase:            generate merge codebase"
    echo "$0 gen_vsi_codebase:              generate VSI codebase"
    echo "$0 package:                       package all requied files"
}

function gen_merge_codebase()
{
    cd $root_dir;
    rm merge -rf
    mkdir merge && cd merge

    if [[ "$amd_gits_mirror" == "y" ]]; then
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_vsi_libs" -b $ma35_vsi_libs_branch
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_ffmpeg" -b $ma35_ffmpeg_branch
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_linux_kernel" -b $ma35_linux_kernel_branch
        git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/github/Xilinx-Projects/ma35_shelf" -b $ma35_shelf_branch
    else
        git clone git@github.com:$github_user/ma35_vsi_libs.git -b $ma35_vsi_libs_branch
        git clone git@github.com:$github_user/ma35_ffmpeg.git -b $ma35_ffmpeg_branch
        git clone git@github.com:$github_user/ma35_linux_kernel.git -b $ma35_linux_kernel_branch
        git clone git@github.com:$github_user/ma35_shelf.git -b $ma35_shelf_branch
    fi

    mkdir amd
    mv ma35_vsi_libs/src/vpe amd/vpe
    mv ma35_ffmpeg/src amd/ffmpeg
    mv ma35_linux_kernel/src amd/drivers
    rm ma35_vsi_libs ma35_ffmpeg ma35_linux_kernel -rf

    mkdir vsi && cd vsi
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/ffmpeg/ffmpeg" -b spsd/master
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/gitlab/Transcoder/drivers" -b spsd/master
    git clone "ssh://$gerrit_user@gerrit-spsd.verisilicon.com:29418/VSI/SDK/vpe" -b spsd/master
    cd ../

    cp ma35_shelf/host_device_algo/libhost_device_algo.so vsi/vpe/prebuild/libs/x86_64_linux/
    cp ma35_shelf/ma35_sn_int/lib*.so vsi/vpe/prebuild/libs/x86_64_linux/cmodel/
    cp ma35_shelf/xav1sdk/libxav1sdk.so vsi/vpe/prebuild/libs/x86_64_linux/
    rm ma35_shelf -rf
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
    --ma35_vsi_libs_branch=*)
        echo "ma35_vsi_libs_branch=$optarg"
        ma35_vsi_libs_branch=$optarg;;
    --ma35_ffmpeg_branch=*)
        echo "ma35_ffmpeg_branch=$optarg"
        ma35_ffmpeg_branch=$optarg;;
    --ma35_linux_kernel_branch=*)
        echo "ma35_linux_kernel_branch=$optarg"
        ma35_linux_kernel_branch=$optarg;;
    --ma35_osal_branch=*)
        echo "ma35_osal_branch=$optarg"
        ma35_osal_branch=$optarg;;
    --ma35_zsp_firmware_branch=*)
        echo "ma35_zsp_firmware_branch=$optarg"
        ma35_zsp_firmware_branch=$optarg;;
    --ma35_branch=*)
        echo "ma35_branch=$optarg"
        ma35_branch=$optarg;;
    --ma35_shelf_branch=*)
        echo "ma35_shelf_branch=$optarg"
        ma35_shelf_branch=$optarg;;
    --include_sdk=*)
        echo "include_sdk=$optarg"
        include_sdk=$optarg;;
    new_project)
        root_dir=$(realpath $(create_folder))
        echo "new project $root_dir had been created";;
    sync_fork)
        sync_fork $next_value;;
    clone_amd_gits)
        clone_amd_gits $next_value;;
    clone_vsi_gits)
        clone_vsi_gits $next_value;;
    fetch_amd_gits)
        fetch_amd_gits $next_value;;
    fetch_vsi_gits)
        fetch_vsi_gits $next_value;;
    push_to_amd_gits)
        push_to_amd_gits $next_value;;
    build)
        build;;
    package)
        package;;
    gen_merge_codebase)
        gen_merge_codebase;;
    gen_vsi_codebase)
        gen_vsi_codebase;;
    --help|help)
        help ;
        exit 0;;
    *)
        echo "invalid input $optarg";
        help;
        exit 1;
        ;;
    esac
done
