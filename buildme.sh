#!/bin/bash
#switches
USEAROMA=0;
USEPREBUILT=1;
USECHKS=1;
USEFTP=0;
#sourcedir
SOURCE_DIR="$(pwd)"
#crosscompile stuff
CROSSARCH="arm"
CROSSCC="$CROSSARCH-eabi-"
TOOLCHAIN_D="$(pwd)/toolch"
TOOLCHAIN="$(pwd)/toolch/android-toolchain-eabi/bin"
#our used directories
PREBUILT="$(pwd)/prebuilt"
OUT_DIR="$(pwd)/out"
#compile neccesities
USERCCDIR="$HOME/.ccache"
CODENAME="hammerhead"
DEFCONFIG="bricked_defconfig"
NRJOBS=$(( $(nproc) * 2 ))
#ftpstuff
RETRY="60s";
MAXCOUNT=30;
HOST="host.com"
USER="user"
PASS='pass'

#if we are not called with an argument, default to branch master
if [ -z "$1" ]; then
  BRANCH="master"
  echo "[BUILD]: WARNING: Not called with branchname, defaulting to $BRANCH!";
  echo "[BUILD]: If this is not what you want, call this script with the branchname.";
else
  BRANCH=$1;
fi

echo "[BUILD]: ####################################";
echo "[BUILD]: ####################################";
echo "[BUILD]: Building branch: $BRANCH";
echo "[BUILD]: ####################################";
echo "[BUILD]: ####################################";

#Checking out latest upstream changes
echo "[BUILD]: Checking out branch: $BRANCH...";
git clean -f -d
git checkout $BRANCH

OUT_ENABLED=1;
if [ ! -d "$OUT_DIR" ]; then
    echo "[BUILD]: Directory '$OUT_DIR' which is configure as output directory does not exist!";
    VALID=0;
    while [[ $VALID -eq 0 ]]
    do
        echo "[Y|y] Create it.";
        echo "[N|n] Don't create it, this will disable the output directory.";
        echo "Choose an option:";
        read DECISION;
        case "$DECISION" in
            y|Y)
            VALID=1;
            echo "Creating directory $OUT_DIR...";
            mkdir $OUT_DIR
            mkdir $OUT_DIR/kernel
            mkdir $OUT_DIR/modules
            ;;
            n|N)
            VALID=1;
            OUT_ENABLED=0;
            echo "Disabling output directory...";
            ;;
            *)
            echo "Error: Unknown input ($DECISION), try again.";
        esac
    done
else
    if [ ! -d "$OUT_DIR/kernel" ]; then
        echo "Creating directory $OUT_DIR/kernel...";
        mkdir $OUT_DIR/kernel
    fi
    if [ ! -d "$OUT_DIR/modules" ]; then
        echo "Creating directory $OUT_DIR/modules...";
        mkdir $OUT_DIR/modules
    fi
fi

###CCACHE CONFIGURATION STARTS HERE, DO NOT MESS WITH IT!!!
TOOLCHAIN_CCACHE="$TOOLCHAIN/../bin-ccache"
gototoolchain() {
  echo "[BUILD]: Changing directory to $TOOLCHAIN/../ ...";
  cd $TOOLCHAIN/../
}

gototoolchaind() {
  echo "[BUILD]: Changing directory to $TOOLCHAIN_D ...";
  cd $TOOLCHAIN_D
}

gotocctoolchain() {
  echo "[BUILD]: Changing directory to $TOOLCHAIN_CCACHE...";
  cd $TOOLCHAIN_CCACHE
}

if [ ! -d "$TOOLCHAIN_D" ]; then
    mkdir $TOOLCHAIN_D
fi
if [ ! -d "$TOOLCHAIN_D/android-toolchain-eabi" ]; then
    gototoolchaind
#    wget http://bricked.de/downloads/android-toolchain-eabi-4.8-2014.03-x86.tar.bz2
    wget http://bricked.de/downloads/android-toolchain-eabi.zip
    echo "[BUILD]: Extracting...";
    unzip android-toolchain-eabi.zip
    rm android-toolchain-eabi.zip
#    tar jxf android-toolchain-eabi-4.8-2014.03-x86.tar.bz2
#    rm -f android-toolchain-eabi-4.8-2014.03-x86.tar.bz2
fi

#check ccache configuration
#if not configured, do that now.
if [ ! -d "$TOOLCHAIN_CCACHE" ]; then
    echo "[BUILD]: CCACHE: not configured! Doing it now...";
    gototoolchain
    mkdir bin-ccache
    gotocctoolchain
    ln -s $(which ccache) "$CROSSCC""gcc"
    ln -s $(which ccache) "$CROSSCC""g++"
    ln -s $(which ccache) "$CROSSCC""cpp"
    ln -s $(which ccache) "$CROSSCC""c++"
    gototoolchain
    chmod -R 777 bin-ccache
    echo "[BUILD]: CCACHE: Done...";
fi
export CCACHE_DIR=$USERCCDIR
###CCACHE CONFIGURATION ENDS HERE, DO NOT MESS WITH IT!!!

echo "[BUILD]: Setting cross compile env vars...";
SAVEDPATH=$PATH;
SAVEDCROSS_COMPILE=$CROSS_COMPILE;
SAVEDARCH=$ARCH;
export ARCH=$CROSSARCH
export CROSS_COMPILE=$CROSSCC
export PATH=$TOOLCHAIN_CCACHE:${PATH}:$TOOLCHAIN

gotoprebuilt() {
  if [ ! -d "$PREBUILT" ]; then
    mkdir $PREBUILT
  fi
  echo "[BUILD]: Changing directory to $PREBUILT...";
  cd $PREBUILT
}

gotosource() {
  echo "[BUILD]: Changing directory to $SOURCE_DIR...";
  cd $SOURCE_DIR
}

gotoout() {
    if [[ ! $OUT_ENABLED -eq 0 ]]; then
        echo "[BUILD]: Changing directory to $OUT_DIR...";
        cd $OUT_DIR;
    fi
}

if [ ! $USEPREBUILT -eq 0 ]; then
    if [ ! -d "$PREBUILT" ]; then
        gotoprebuilt
        wget http://bricked.de/downloads/prebuilts/${CODENAME}_prebuilt.zip
        unzip ${CODENAME}_prebuilt.zip
        rm ${CODENAME}_prebuilt.zip
    fi
fi

gotosource

#saving new rev
REV=$(git log --pretty=format:'%h' -n 1)
echo "[BUILD]: Saved current hash as revision: $REV...";
#date of build
DATE=$(date +%Y%m%d_%H%M%S)
echo "[BUILD]: Start of build: $DATE...";

#build the kernel
echo "[BUILD]: Cleaning kernel (make mrproper)...";
make mrproper
echo "[BUILD]: Using defconfig: $DEFCONFIG...";
make $DEFCONFIG
echo "[BUILD]: Changing CONFIG_LOCALVERSION to: -bricked-"$CODENAME"-"$BRANCH" ...";
sed -i "/CONFIG_LOCALVERSION=\"/c\CONFIG_LOCALVERSION=\"-bricked-"$CODENAME"-"$BRANCH"\"" .config

#kcontrol necessities
if [ $(cat .config | grep 'CONFIG_ARCH_MSM=y' | tail -n1) == "CONFIG_ARCH_MSM=y" ]; then
    DEVARCH="msm";
elif [ $(cat .config | grep 'CONFIG_ARCH_TEGRA=y' | tail -n1) == "CONFIG_ARCH_TEGRA=y" ]; then
    DEVARCH="tegra";
fi
gotokcontrol() {
  echo "[BUILD]: Changing directory to $SOURCE_DIR/kcontrol...";
  cd $SOURCE_DIR/kcontrol
}

gotokcontrolgpu() {
  echo "[BUILD]: Changing directory to $SOURCE_DIR/kcontrol/kcontrol_gpu_$DEVARCH...";
  cd $SOURCE_DIR/kcontrol/kcontrol_gpu_$DEVARCH
}
#end kcontrol necessities

echo "[BUILD]: Bulding the kernel...";
time make -j$NRJOBS || { return 1; }
echo "[BUILD]: Done with kernel!...";

# BUILD KCONTROL
#done building, lets build kcontrol modulesa
echo "[BUILD]: Initializing directories for KControl modules...";
rm -rf kcontrol
mkdir kcontrol
gotokcontrol
#gpu
echo "[BUILD]: Cloning KControl msm gpu module source...";
if [ $DEVARCH == "msm" ]; then
    git clone https://git.bricked.de/kcontrol/kcontrol_gpu_msm.git
elif  [ $DEVARCH == "tegra" ]; then
    git clone https://git.bricked.de/kcontrol/kcontrol_gpu_tegra.git
fi
gotokcontrolgpu
echo "[BUILD]: Updating KERNEL_BUILD inside the Makefile...";
sed -i '/KERNEL_BUILD := /c\KERNEL_BUILD := ../../' Makefile
echo "[BUILD]: Building KControl $DEVARCH gpu module...";
make || { return 1; }
echo "[BUILD]: Done with kcontrol's $DEVARCH gpu module!...";
# END BUILD KCONTROL

if [[ ! $OUT_ENABLED -eq 0 ]]; then
    gotoout
    #prepare our zip structure
    echo "[BUILD]: Cleaning out directory...";
    find $OUT_DIR/* -maxdepth 0 ! -name '*.zip' ! -name '*.md5' ! -name '*.sha1' ! -name kernel ! -name modules ! -name out -exec rm -rf '{}' ';'
    if [ ! $USEPREBUILT -eq 0 ]; then
        if [ -d "$PREBUILT" ]; then
            echo "[BUILD]: Copying prebuilts to out directory...";
            cp -R $PREBUILT/* $OUT_DIR/
        fi
    fi
    if [ ! $USEAROMA -eq 0 ]; then
        echo "[BUILD]: Changing aroma version/data/device to: $BRANCH-$REV/$DATE/$CODENAME...";
        sed -i "/ini_set(\"rom_version\",/c\ini_set(\"rom_version\", \""$BRANCH-$REV"\");" $OUT_DIR/META-INF/com/google/android/aroma-config
        sed -i "/ini_set(\"rom_date\",/c\ini_set(\"rom_date\", \""$DATE"\");" $OUT_DIR/META-INF/com/google/android/aroma-config
        sed -i "/ini_set(\"rom_device\",/c\ini_set(\"rom_device\", \""$CODENAME"\");" $OUT_DIR/META-INF/com/google/android/aroma-config
    fi
    gotosource

    #copy stuff for our zip
    echo "[BUILD]: Copying kernel (zImage) to $OUT_DIR/kernel/...";
    cp arch/arm/boot/zImage-dtb $OUT_DIR/kernel/zImage
    echo "[BUILD]: Copying modules (*.ko) to $OUT_DIR/modules/...";
    find $SOURCE_DIR/ -name \*.ko -exec cp '{}' $OUT_DIR/modules/ ';'
    echo "[BUILD]: Done!...";

    gotoout

    #create zip and clean folder
    echo "[BUILD]: Creating zip: bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip ...";
    zip -r bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip . -x "*.zip" "*.sha1" "*.md5"
    echo "[BUILD]: Cleaning out directory...";
    find $OUT_DIR/* -maxdepth 0 ! -name '*.zip' ! -name '*.md5' ! -name '*.sha1' ! -name out -exec rm -rf '{}' ';'
    echo "[BUILD]: Done!...";

    if [ ! $USECHKS -eq 0 ]; then
        echo "[BUILD]: Creating sha1 & md5 sums...";
        md5sum bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip > bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip.md5
        sha1sum bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip > bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip.sha1
    fi

    if [ ! $USEFTP -eq 0 ]; then
        echo "[BUILD]: Testing connection to $HOST...";
        SUCCESS=0;
        ZERO=0;
        COUNT=0;
        while [ $SUCCESS -eq $ZERO ]
        do
            COUNT=$(($COUNT + 1));
            if [ $COUNT -eq $MAXCOUNT ]; then
                return 1;
            fi
            ping -c1 $HOST
            case "$?" in
                0)
                echo "[BUILD]: $HOST is online, continuing...";
                SUCCESS=1 ;;
                1)
                echo "[BUILD]: Packet Loss while pinging $HOST. Retrying in $RETRY!";
                sleep $RETRY ;;
                2)
                echo "[BUILD]: $HOST is unknown (offline). Retrying in $RETRY!";
                sleep $RETRY ;;
                *)
                echo "[BUILD]: Some unknown error occured while trying to connect to $HOST. Retrying in $RETRY seconds!";
                sleep $RETRY ;;
            esac
        done

echo "[BUILD]: Uploading files to $HOST...";
# Uses the ftp command with the -inv switches.
#  -i turns off interactive prompting
#  -n Restrains FTP from attempting the auto-login feature
#  -v enables verbose and progress
ftp -inv $HOST << End-Of-Session
user $USER $PASS
cd /$CODENAME/$BRANCH/
put bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip
put bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip.md5
put bricked_"$CODENAME"_"$DATE"_"$BRANCH"-"$REV".zip.sha1
bye
End-Of-Session
    fi
fi

echo "[BUILD]: All done!...";
gotosource
export PATH=$SAVEDPATH
export CROSS_COMPILE=$SAVEDCROSS_COMPILE;
export ARCH=$SAVEDARCH;
